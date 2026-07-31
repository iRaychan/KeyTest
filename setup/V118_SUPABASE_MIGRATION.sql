-- KeySuite V1.18
-- Multi-currency CHC/GWS price lists, product-specific category rules,
-- GWS Tank models, and owner-only protected save functions.
-- Run after the V1.16 migration. Safe to run more than once.

begin;

-- ---------------------------------------------------------------------------
-- Shared Price List currency rates
-- ---------------------------------------------------------------------------
alter table public.ks_app_settings
  add column if not exists usd_multiplier numeric not null default 5.8000;
alter table public.ks_app_settings
  add column if not exists rmb_multiplier numeric not null default 0.6500;

update public.ks_app_settings
set usd_multiplier=case when usd_multiplier is null or usd_multiplier<=0 then 5.8000 else usd_multiplier end,
    rmb_multiplier=case when rmb_multiplier is null or rmb_multiplier<=0 then 0.6500 else rmb_multiplier end
where id='default';

alter table public.ks_app_settings drop constraint if exists ks_app_settings_usd_multiplier_check;
alter table public.ks_app_settings add constraint ks_app_settings_usd_multiplier_check check (usd_multiplier>0);
alter table public.ks_app_settings drop constraint if exists ks_app_settings_rmb_multiplier_check;
alter table public.ks_app_settings add constraint ks_app_settings_rmb_multiplier_check check (rmb_multiplier>0);

-- CHC keeps independent prices for USD, RMB and MYR.
alter table public.ks_products_chc add column if not exists chc_rmb numeric;
alter table public.ks_products_chc add column if not exists chcs_rmb numeric;
alter table public.ks_products_chc add column if not exists chcn_rmb numeric;
alter table public.ks_products_chc add column if not exists chc_myr numeric;
alter table public.ks_products_chc add column if not exists chcs_myr numeric;
alter table public.ks_products_chc add column if not exists chcn_myr numeric;

-- ---------------------------------------------------------------------------
-- GWS Tank master and independent currency price lists
-- ---------------------------------------------------------------------------
create table if not exists public.ks_products_gws (
  id text primary key,
  product_category text not null default 'GWS Tank',
  model text not null unique,
  price_10_usd numeric,
  price_16_usd numeric,
  price_25_usd numeric,
  price_10_rmb numeric,
  price_16_rmb numeric,
  price_25_rmb numeric,
  price_10_myr numeric,
  price_16_myr numeric,
  price_25_myr numeric,
  source_row integer not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.ks_products_gws(id,model,source_row)
values
 ('GWS-8LX','8LX',1),('GWS-12LX','12LX',2),('GWS-18LX','18LX',3),
 ('GWS-24LX','24LX',4),('GWS-35LX','35LX',5),('GWS-60LV','60LV',6),
 ('GWS-80LV','80LV',7),('GWS-100LV','100LV',8),('GWS-130LV','130LV',9),
 ('GWS-150LV','150LV',10),('GWS-200LV','200LV',11),('GWS-300LV','300LV',12)
on conflict (model) do update set source_row=excluded.source_row,status='active';

alter table public.ks_products_gws enable row level security;
drop policy if exists "Approved users can read GWS products" on public.ks_products_gws;
create policy "Approved users can read GWS products"
on public.ks_products_gws for select to authenticated
using (public.keysuite_has_access());

revoke all on table public.ks_products_gws from anon;
revoke insert,update,delete on table public.ks_products_gws from authenticated;
grant select on table public.ks_products_gws to authenticated;

-- ---------------------------------------------------------------------------
-- Per-product category pricing rules
-- ---------------------------------------------------------------------------
alter table public.ks_pricing_categories
  add column if not exists product_rules jsonb not null default '{}'::jsonb;

update public.ks_pricing_categories pc
set product_rules =
  case when coalesce(pc.product_rules,'{}'::jsonb) ? 'CHC'
       then coalesce(pc.product_rules,'{}'::jsonb)
       else coalesce(pc.product_rules,'{}'::jsonb) || jsonb_build_object(
         'CHC',jsonb_build_object(
           'margin',coalesce(pc.chc_margin,pc.chc_factor,0.38),
           'transport',coalesce(pc.transport,30),
           'commission',coalesce(pc.commission,0.03),
           'set_discount',coalesce(pc.set_discount,0.068),
           'final_discount',coalesce(pc.final_discount,0.08),
           'include_commission',true,
           'include_set_discount',true,
           'include_final_discount',true,
           'include_fuel_charge',true
         )
       ) end;

update public.ks_pricing_categories pc
set product_rules =
  case when coalesce(pc.product_rules,'{}'::jsonb) ? 'GWS'
       then coalesce(pc.product_rules,'{}'::jsonb)
       else coalesce(pc.product_rules,'{}'::jsonb) || jsonb_build_object(
         'GWS',jsonb_build_object(
           'margin',coalesce(pc.chc_margin,pc.chc_factor,0.38),
           'transport',coalesce(pc.transport,30),
           'commission',coalesce(pc.commission,0.03),
           'set_discount',coalesce(pc.set_discount,0.068),
           'final_discount',coalesce(pc.final_discount,0.08),
           'include_commission',true,
           'include_set_discount',true,
           'include_final_discount',true,
           'include_fuel_charge',true
         )
       ) end;

-- ---------------------------------------------------------------------------
-- Save a shared USD or RMB rate. MYR is always 1.00 and needs no save.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_save_pricelist_multiplier(text,numeric);
create function public.keysuite_save_pricelist_multiplier(
  p_currency text,
  p_multiplier numeric
)
returns table (usd_multiplier numeric,rmb_multiplier numeric)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_currency,'')));
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can maintain Price List settings.';
  end if;
  if v_currency not in ('USD','RMB') then raise exception 'Currency must be USD or RMB.'; end if;
  if p_multiplier is null or p_multiplier<=0 then raise exception 'Currency rate must be greater than zero.'; end if;

  update public.ks_app_settings s
  set usd_multiplier=case when v_currency='USD' then p_multiplier else s.usd_multiplier end,
      rmb_multiplier=case when v_currency='RMB' then p_multiplier else s.rmb_multiplier end
  where s.id='default';
  if not found then raise exception 'KeySuite application settings were not found.'; end if;

  return query select s.usd_multiplier,s.rmb_multiplier from public.ks_app_settings s where s.id='default';
end;
$$;
revoke all on function public.keysuite_save_pricelist_multiplier(text,numeric) from public;
grant execute on function public.keysuite_save_pricelist_multiplier(text,numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Save CHC/CHCS/CHCN prices into the selected currency list.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_save_chc_product_price_v118(text,text,numeric,numeric,numeric);
create function public.keysuite_save_chc_product_price_v118(
  p_product_id text,
  p_currency text,
  p_chc_price numeric,
  p_chcs_price numeric,
  p_chcn_price numeric
)
returns table (product_id text,currency text,chc_price numeric,chcs_price numeric,chcn_price numeric)
language plpgsql
security definer
set search_path=public
as $$
declare v_currency text:=upper(trim(coalesce(p_currency,'')));
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can maintain product prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_chc_price is not null and p_chc_price<0 then raise exception 'CHC Price cannot be negative.'; end if;
  if p_chcs_price is not null and p_chcs_price<0 then raise exception 'CHCS Price cannot be negative.'; end if;
  if p_chcn_price is not null and p_chcn_price<0 then raise exception 'CHCN Price cannot be negative.'; end if;

  update public.ks_products_chc p set
    chc_usd =case when v_currency='USD' then p_chc_price  else p.chc_usd  end,
    chcs_usd=case when v_currency='USD' then p_chcs_price else p.chcs_usd end,
    chcn_usd=case when v_currency='USD' then p_chcn_price else p.chcn_usd end,
    chc_rmb =case when v_currency='RMB' then p_chc_price  else p.chc_rmb  end,
    chcs_rmb=case when v_currency='RMB' then p_chcs_price else p.chcs_rmb end,
    chcn_rmb=case when v_currency='RMB' then p_chcn_price else p.chcn_rmb end,
    chc_myr =case when v_currency='MYR' then p_chc_price  else p.chc_myr  end,
    chcs_myr=case when v_currency='MYR' then p_chcs_price else p.chcs_myr end,
    chcn_myr=case when v_currency='MYR' then p_chcn_price else p.chcn_myr end
  where p.id=p_product_id;
  if not found then raise exception 'CHC model was not found.'; end if;

  return query
  select p.id,v_currency,
    case v_currency when 'USD' then p.chc_usd when 'RMB' then p.chc_rmb else p.chc_myr end,
    case v_currency when 'USD' then p.chcs_usd when 'RMB' then p.chcs_rmb else p.chcs_myr end,
    case v_currency when 'USD' then p.chcn_usd when 'RMB' then p.chcn_rmb else p.chcn_myr end
  from public.ks_products_chc p where p.id=p_product_id;
end;
$$;
revoke all on function public.keysuite_save_chc_product_price_v118(text,text,numeric,numeric,numeric) from public;
grant execute on function public.keysuite_save_chc_product_price_v118(text,text,numeric,numeric,numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Save GWS 10/16/25 Bar prices into the selected currency list.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_save_gws_product_price_v118(text,text,numeric,numeric,numeric);
create function public.keysuite_save_gws_product_price_v118(
  p_product_id text,
  p_currency text,
  p_price_10 numeric,
  p_price_16 numeric,
  p_price_25 numeric
)
returns table (product_id text,currency text,price_10 numeric,price_16 numeric,price_25 numeric)
language plpgsql
security definer
set search_path=public
as $$
declare v_currency text:=upper(trim(coalesce(p_currency,'')));
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can maintain product prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_price_10 is not null and p_price_10<0 then raise exception '10 Bar Price cannot be negative.'; end if;
  if p_price_16 is not null and p_price_16<0 then raise exception '16 Bar Price cannot be negative.'; end if;
  if p_price_25 is not null and p_price_25<0 then raise exception '25 Bar Price cannot be negative.'; end if;

  update public.ks_products_gws p set
    price_10_usd=case when v_currency='USD' then p_price_10 else p.price_10_usd end,
    price_16_usd=case when v_currency='USD' then p_price_16 else p.price_16_usd end,
    price_25_usd=case when v_currency='USD' then p_price_25 else p.price_25_usd end,
    price_10_rmb=case when v_currency='RMB' then p_price_10 else p.price_10_rmb end,
    price_16_rmb=case when v_currency='RMB' then p_price_16 else p.price_16_rmb end,
    price_25_rmb=case when v_currency='RMB' then p_price_25 else p.price_25_rmb end,
    price_10_myr=case when v_currency='MYR' then p_price_10 else p.price_10_myr end,
    price_16_myr=case when v_currency='MYR' then p_price_16 else p.price_16_myr end,
    price_25_myr=case when v_currency='MYR' then p_price_25 else p.price_25_myr end,
    updated_at=now()
  where p.id=p_product_id;
  if not found then raise exception 'GWS Tank model was not found.'; end if;

  return query
  select p.id,v_currency,
    case v_currency when 'USD' then p.price_10_usd when 'RMB' then p.price_10_rmb else p.price_10_myr end,
    case v_currency when 'USD' then p.price_16_usd when 'RMB' then p.price_16_rmb else p.price_16_myr end,
    case v_currency when 'USD' then p.price_25_usd when 'RMB' then p.price_25_rmb else p.price_25_myr end
  from public.ks_products_gws p where p.id=p_product_id;
end;
$$;
revoke all on function public.keysuite_save_gws_product_price_v118(text,text,numeric,numeric,numeric) from public;
grant execute on function public.keysuite_save_gws_product_price_v118(text,text,numeric,numeric,numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Save one product-family rule at a time inside a customer pricing category.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_manage_pricing_category_v118(text,text,text,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean);
create function public.keysuite_manage_pricing_category_v118(
  p_category_id text,
  p_category_name text,
  p_product_code text,
  p_margin numeric,
  p_transport numeric,
  p_commission numeric,
  p_set_discount numeric,
  p_final_discount numeric,
  p_include_commission boolean,
  p_include_set_discount boolean,
  p_include_final_discount boolean,
  p_include_fuel_charge boolean
)
returns table (category_id text,category_name text,product_rules jsonb)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id text:=trim(coalesce(p_category_id,''));
  v_name text:=trim(coalesce(p_category_name,''));
  v_product text:=upper(trim(coalesce(p_product_code,'')));
  v_rule jsonb;
  v_defaults jsonb;
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can manage pricing categories.'; end if;
  if v_name='' then raise exception 'Category Name is required.'; end if;
  if v_product not in ('CHC','GWS') then raise exception 'Product must be CHC or GWS.'; end if;
  if p_margin is null or p_margin<0 or p_margin>=1 then raise exception 'Margin must be from 0%% to below 100%%.'; end if;
  if p_transport is null or p_transport<0 then raise exception 'Transport must be zero or more.'; end if;
  if p_commission is null or p_commission<0 or p_commission>=1 then raise exception 'Commission must be from 0%% to below 100%%.'; end if;
  if p_set_discount is null or p_set_discount<0 or p_set_discount>=1 then raise exception 'Set Discount must be from 0%% to below 100%%.'; end if;
  if p_final_discount is null or p_final_discount<0 or p_final_discount>=1 then raise exception 'Final Discount must be from 0%% to below 100%%.'; end if;

  if exists(select 1 from public.ks_pricing_categories pc where lower(pc.category_name)=lower(v_name) and (v_id='' or pc.id<>v_id)) then
    raise exception 'A pricing category with this name already exists.';
  end if;

  v_rule:=jsonb_build_object(
    'margin',p_margin,'transport',p_transport,'commission',p_commission,
    'set_discount',p_set_discount,'final_discount',p_final_discount,
    'include_commission',coalesce(p_include_commission,false),
    'include_set_discount',coalesce(p_include_set_discount,false),
    'include_final_discount',coalesce(p_include_final_discount,false),
    'include_fuel_charge',coalesce(p_include_fuel_charge,false)
  );
  v_defaults:=jsonb_build_object(
    'margin',0.38,'transport',30,'commission',0.03,'set_discount',0.068,'final_discount',0.08,
    'include_commission',true,'include_set_discount',true,'include_final_discount',true,'include_fuel_charge',true
  );

  if v_id='' then
    v_id:='CCID'||upper(substr(md5(clock_timestamp()::text||random()::text||v_name),1,12));
    insert into public.ks_pricing_categories(
      id,category_name,final_discount,set_discount,commission,chc_factor,transport,chc_margin,product_rules
    ) values (
      v_id,v_name,
      case when v_product='CHC' then p_final_discount else 0.08 end,
      case when v_product='CHC' then p_set_discount else 0.068 end,
      case when v_product='CHC' then p_commission else 0.03 end,
      case when v_product='CHC' then p_margin else 0.38 end,
      case when v_product='CHC' then p_transport else 30 end,
      case when v_product='CHC' then p_margin else 0.38 end,
      jsonb_build_object('CHC',case when v_product='CHC' then v_rule else v_defaults end,'GWS',case when v_product='GWS' then v_rule else v_defaults end)
    );
  else
    update public.ks_pricing_categories pc set
      category_name=v_name,
      product_rules=jsonb_set(coalesce(pc.product_rules,'{}'::jsonb),array[v_product],v_rule,true),
      final_discount=case when v_product='CHC' then p_final_discount else pc.final_discount end,
      set_discount=case when v_product='CHC' then p_set_discount else pc.set_discount end,
      commission=case when v_product='CHC' then p_commission else pc.commission end,
      chc_factor=case when v_product='CHC' then p_margin else pc.chc_factor end,
      chc_margin=case when v_product='CHC' then p_margin else pc.chc_margin end,
      transport=case when v_product='CHC' then p_transport else pc.transport end
    where pc.id=v_id;
    if not found then raise exception 'Pricing category was not found.'; end if;
  end if;

  return query select pc.id,pc.category_name,pc.product_rules from public.ks_pricing_categories pc where pc.id=v_id;
end;
$$;
revoke all on function public.keysuite_manage_pricing_category_v118(text,text,text,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
grant execute on function public.keysuite_manage_pricing_category_v118(text,text,text,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

-- Verification after running:
-- select id,usd_multiplier,rmb_multiplier from public.ks_app_settings where id='default';
-- select model,price_10_usd,price_16_usd,price_25_usd from public.ks_products_gws order by source_row;
-- select category_name,product_rules from public.ks_pricing_categories order by category_name;

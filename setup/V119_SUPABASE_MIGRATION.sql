-- KeySuite V1.19
-- Product-specific USD/RMB multipliers, Common/Many/Rare price rarity,
-- and Normal/Rare category pricing adjustments.
-- Run after the V1.18 migration. Safe to run more than once.

begin;

-- ---------------------------------------------------------------------------
-- Product-family-specific currency multipliers
-- ---------------------------------------------------------------------------
alter table public.ks_app_settings
  add column if not exists chc_usd_multiplier numeric;
alter table public.ks_app_settings
  add column if not exists chc_rmb_multiplier numeric;
alter table public.ks_app_settings
  add column if not exists gws_usd_multiplier numeric;
alter table public.ks_app_settings
  add column if not exists gws_rmb_multiplier numeric;

update public.ks_app_settings s
set chc_usd_multiplier=coalesce(nullif(s.chc_usd_multiplier,0),nullif(s.usd_multiplier,0),5.8000),
    chc_rmb_multiplier=coalesce(nullif(s.chc_rmb_multiplier,0),nullif(s.rmb_multiplier,0),0.6500),
    gws_usd_multiplier=coalesce(nullif(s.gws_usd_multiplier,0),nullif(s.usd_multiplier,0),5.8000),
    gws_rmb_multiplier=coalesce(nullif(s.gws_rmb_multiplier,0),nullif(s.rmb_multiplier,0),0.6500)
;

alter table public.ks_app_settings alter column chc_usd_multiplier set default 5.8000;
alter table public.ks_app_settings alter column chc_rmb_multiplier set default 0.6500;
alter table public.ks_app_settings alter column gws_usd_multiplier set default 5.8000;
alter table public.ks_app_settings alter column gws_rmb_multiplier set default 0.6500;
alter table public.ks_app_settings alter column chc_usd_multiplier set not null;
alter table public.ks_app_settings alter column chc_rmb_multiplier set not null;
alter table public.ks_app_settings alter column gws_usd_multiplier set not null;
alter table public.ks_app_settings alter column gws_rmb_multiplier set not null;

alter table public.ks_app_settings drop constraint if exists ks_app_settings_chc_usd_multiplier_check;
alter table public.ks_app_settings add constraint ks_app_settings_chc_usd_multiplier_check check (chc_usd_multiplier>0);
alter table public.ks_app_settings drop constraint if exists ks_app_settings_chc_rmb_multiplier_check;
alter table public.ks_app_settings add constraint ks_app_settings_chc_rmb_multiplier_check check (chc_rmb_multiplier>0);
alter table public.ks_app_settings drop constraint if exists ks_app_settings_gws_usd_multiplier_check;
alter table public.ks_app_settings add constraint ks_app_settings_gws_usd_multiplier_check check (gws_usd_multiplier>0);
alter table public.ks_app_settings drop constraint if exists ks_app_settings_gws_rmb_multiplier_check;
alter table public.ks_app_settings add constraint ks_app_settings_gws_rmb_multiplier_check check (gws_rmb_multiplier>0);

-- ---------------------------------------------------------------------------
-- Rarity is shared across all currency price lists for the same variant.
-- Existing products default to MANY, preserving the V1.18 calculation.
-- ---------------------------------------------------------------------------
alter table public.ks_products_chc add column if not exists chc_rarity text not null default 'many';
alter table public.ks_products_chc add column if not exists chcs_rarity text not null default 'many';
alter table public.ks_products_chc add column if not exists chcn_rarity text not null default 'many';

update public.ks_products_chc set
  chc_rarity=case when lower(coalesce(chc_rarity,'')) in ('common','many','rare') then lower(chc_rarity) else 'many' end,
  chcs_rarity=case when lower(coalesce(chcs_rarity,'')) in ('common','many','rare') then lower(chcs_rarity) else 'many' end,
  chcn_rarity=case when lower(coalesce(chcn_rarity,'')) in ('common','many','rare') then lower(chcn_rarity) else 'many' end;

alter table public.ks_products_chc drop constraint if exists ks_products_chc_chc_rarity_check;
alter table public.ks_products_chc add constraint ks_products_chc_chc_rarity_check check (chc_rarity in ('common','many','rare'));
alter table public.ks_products_chc drop constraint if exists ks_products_chc_chcs_rarity_check;
alter table public.ks_products_chc add constraint ks_products_chc_chcs_rarity_check check (chcs_rarity in ('common','many','rare'));
alter table public.ks_products_chc drop constraint if exists ks_products_chc_chcn_rarity_check;
alter table public.ks_products_chc add constraint ks_products_chc_chcn_rarity_check check (chcn_rarity in ('common','many','rare'));

alter table public.ks_products_gws add column if not exists rarity_10 text not null default 'many';
alter table public.ks_products_gws add column if not exists rarity_16 text not null default 'many';
alter table public.ks_products_gws add column if not exists rarity_25 text not null default 'many';

update public.ks_products_gws set
  rarity_10=case when lower(coalesce(rarity_10,'')) in ('common','many','rare') then lower(rarity_10) else 'many' end,
  rarity_16=case when lower(coalesce(rarity_16,'')) in ('common','many','rare') then lower(rarity_16) else 'many' end,
  rarity_25=case when lower(coalesce(rarity_25,'')) in ('common','many','rare') then lower(rarity_25) else 'many' end;

alter table public.ks_products_gws drop constraint if exists ks_products_gws_rarity_10_check;
alter table public.ks_products_gws add constraint ks_products_gws_rarity_10_check check (rarity_10 in ('common','many','rare'));
alter table public.ks_products_gws drop constraint if exists ks_products_gws_rarity_16_check;
alter table public.ks_products_gws add constraint ks_products_gws_rarity_16_check check (rarity_16 in ('common','many','rare'));
alter table public.ks_products_gws drop constraint if exists ks_products_gws_rarity_25_check;
alter table public.ks_products_gws add constraint ks_products_gws_rarity_25_check check (rarity_25 in ('common','many','rare'));

-- ---------------------------------------------------------------------------
-- Add Normal and Rare adjustments to every CHC and GWS category rule.
-- Zero defaults preserve existing prices until the Owner enters a value.
-- ---------------------------------------------------------------------------
update public.ks_pricing_categories pc
set product_rules=jsonb_set(
  jsonb_set(
    coalesce(pc.product_rules,'{}'::jsonb),
    '{CHC,normal}',
    to_jsonb(coalesce((pc.product_rules->'CHC'->>'normal')::numeric,0)),
    true
  ),
  '{CHC,rare}',
  to_jsonb(coalesce((pc.product_rules->'CHC'->>'rare')::numeric,0)),
  true
);

update public.ks_pricing_categories pc
set product_rules=jsonb_set(
  jsonb_set(
    coalesce(pc.product_rules,'{}'::jsonb),
    '{GWS,normal}',
    to_jsonb(coalesce((pc.product_rules->'GWS'->>'normal')::numeric,0)),
    true
  ),
  '{GWS,rare}',
  to_jsonb(coalesce((pc.product_rules->'GWS'->>'rare')::numeric,0)),
  true
);

-- ---------------------------------------------------------------------------
-- Save one currency multiplier for one product family.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric);
create function public.keysuite_save_product_pricelist_multiplier_v119(
  p_product_code text,
  p_currency text,
  p_multiplier numeric
)
returns table (product_code text,usd_multiplier numeric,rmb_multiplier numeric)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_product text:=upper(trim(coalesce(p_product_code,'')));
  v_currency text:=upper(trim(coalesce(p_currency,'')));
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can maintain Price List settings.';
  end if;
  if v_product not in ('CHC','GWS') then raise exception 'Product must be CHC or GWS.'; end if;
  if v_currency not in ('USD','RMB') then raise exception 'Currency must be USD or RMB.'; end if;
  if p_multiplier is null or p_multiplier<=0 then raise exception 'Currency rate must be greater than zero.'; end if;

  update public.ks_app_settings s set
    chc_usd_multiplier=case when v_product='CHC' and v_currency='USD' then p_multiplier else s.chc_usd_multiplier end,
    chc_rmb_multiplier=case when v_product='CHC' and v_currency='RMB' then p_multiplier else s.chc_rmb_multiplier end,
    gws_usd_multiplier=case when v_product='GWS' and v_currency='USD' then p_multiplier else s.gws_usd_multiplier end,
    gws_rmb_multiplier=case when v_product='GWS' and v_currency='RMB' then p_multiplier else s.gws_rmb_multiplier end
  where s.id='default';
  if not found then raise exception 'KeySuite application settings were not found.'; end if;

  return query
  select v_product,
         case when v_product='CHC' then s.chc_usd_multiplier else s.gws_usd_multiplier end,
         case when v_product='CHC' then s.chc_rmb_multiplier else s.gws_rmb_multiplier end
  from public.ks_app_settings s where s.id='default';
end;
$$;
revoke all on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) from public;
grant execute on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Save CHC prices and rarity.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_save_chc_product_price_v119(text,text,numeric,numeric,numeric,text,text,text);
create function public.keysuite_save_chc_product_price_v119(
  p_product_id text,
  p_currency text,
  p_chc_price numeric,
  p_chcs_price numeric,
  p_chcn_price numeric,
  p_chc_rarity text,
  p_chcs_rarity text,
  p_chcn_rarity text
)
returns table (product_id text,currency text,chc_price numeric,chcs_price numeric,chcn_price numeric,chc_rarity text,chcs_rarity text,chcn_rarity text)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_currency,'')));
  v_chc_rarity text:=lower(trim(coalesce(p_chc_rarity,'many')));
  v_chcs_rarity text:=lower(trim(coalesce(p_chcs_rarity,'many')));
  v_chcn_rarity text:=lower(trim(coalesce(p_chcn_rarity,'many')));
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can maintain product prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_chc_price is not null and p_chc_price<0 then raise exception 'CHC Price cannot be negative.'; end if;
  if p_chcs_price is not null and p_chcs_price<0 then raise exception 'CHCS Price cannot be negative.'; end if;
  if p_chcn_price is not null and p_chcn_price<0 then raise exception 'CHCN Price cannot be negative.'; end if;
  if v_chc_rarity not in ('common','many','rare') then raise exception 'CHC rarity is invalid.'; end if;
  if v_chcs_rarity not in ('common','many','rare') then raise exception 'CHCS rarity is invalid.'; end if;
  if v_chcn_rarity not in ('common','many','rare') then raise exception 'CHCN rarity is invalid.'; end if;

  update public.ks_products_chc p set
    chc_usd =case when v_currency='USD' then p_chc_price  else p.chc_usd  end,
    chcs_usd=case when v_currency='USD' then p_chcs_price else p.chcs_usd end,
    chcn_usd=case when v_currency='USD' then p_chcn_price else p.chcn_usd end,
    chc_rmb =case when v_currency='RMB' then p_chc_price  else p.chc_rmb  end,
    chcs_rmb=case when v_currency='RMB' then p_chcs_price else p.chcs_rmb end,
    chcn_rmb=case when v_currency='RMB' then p_chcn_price else p.chcn_rmb end,
    chc_myr =case when v_currency='MYR' then p_chc_price  else p.chc_myr  end,
    chcs_myr=case when v_currency='MYR' then p_chcs_price else p.chcs_myr end,
    chcn_myr=case when v_currency='MYR' then p_chcn_price else p.chcn_myr end,
    chc_rarity=v_chc_rarity,
    chcs_rarity=v_chcs_rarity,
    chcn_rarity=v_chcn_rarity
  where p.id=p_product_id;
  if not found then raise exception 'CHC model was not found.'; end if;

  return query
  select p.id,v_currency,
    case v_currency when 'USD' then p.chc_usd when 'RMB' then p.chc_rmb else p.chc_myr end,
    case v_currency when 'USD' then p.chcs_usd when 'RMB' then p.chcs_rmb else p.chcs_myr end,
    case v_currency when 'USD' then p.chcn_usd when 'RMB' then p.chcn_rmb else p.chcn_myr end,
    p.chc_rarity,p.chcs_rarity,p.chcn_rarity
  from public.ks_products_chc p where p.id=p_product_id;
end;
$$;
revoke all on function public.keysuite_save_chc_product_price_v119(text,text,numeric,numeric,numeric,text,text,text) from public;
grant execute on function public.keysuite_save_chc_product_price_v119(text,text,numeric,numeric,numeric,text,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- Save GWS prices and rarity.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_save_gws_product_price_v119(text,text,numeric,numeric,numeric,text,text,text);
create function public.keysuite_save_gws_product_price_v119(
  p_product_id text,
  p_currency text,
  p_price_10 numeric,
  p_price_16 numeric,
  p_price_25 numeric,
  p_rarity_10 text,
  p_rarity_16 text,
  p_rarity_25 text
)
returns table (product_id text,currency text,price_10 numeric,price_16 numeric,price_25 numeric,rarity_10 text,rarity_16 text,rarity_25 text)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_currency,'')));
  v_rarity_10 text:=lower(trim(coalesce(p_rarity_10,'many')));
  v_rarity_16 text:=lower(trim(coalesce(p_rarity_16,'many')));
  v_rarity_25 text:=lower(trim(coalesce(p_rarity_25,'many')));
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can maintain product prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_price_10 is not null and p_price_10<0 then raise exception '10 Bar Price cannot be negative.'; end if;
  if p_price_16 is not null and p_price_16<0 then raise exception '16 Bar Price cannot be negative.'; end if;
  if p_price_25 is not null and p_price_25<0 then raise exception '25 Bar Price cannot be negative.'; end if;
  if v_rarity_10 not in ('common','many','rare') then raise exception '10 Bar rarity is invalid.'; end if;
  if v_rarity_16 not in ('common','many','rare') then raise exception '16 Bar rarity is invalid.'; end if;
  if v_rarity_25 not in ('common','many','rare') then raise exception '25 Bar rarity is invalid.'; end if;

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
    rarity_10=v_rarity_10,
    rarity_16=v_rarity_16,
    rarity_25=v_rarity_25,
    updated_at=now()
  where p.id=p_product_id;
  if not found then raise exception 'GWS Tank model was not found.'; end if;

  return query
  select p.id,v_currency,
    case v_currency when 'USD' then p.price_10_usd when 'RMB' then p.price_10_rmb else p.price_10_myr end,
    case v_currency when 'USD' then p.price_16_usd when 'RMB' then p.price_16_rmb else p.price_16_myr end,
    case v_currency when 'USD' then p.price_25_usd when 'RMB' then p.price_25_rmb else p.price_25_myr end,
    p.rarity_10,p.rarity_16,p.rarity_25
  from public.ks_products_gws p where p.id=p_product_id;
end;
$$;
revoke all on function public.keysuite_save_gws_product_price_v119(text,text,numeric,numeric,numeric,text,text,text) from public;
grant execute on function public.keysuite_save_gws_product_price_v119(text,text,numeric,numeric,numeric,text,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- Save one product-family category rule, including Normal and Rare.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean);
create function public.keysuite_manage_pricing_category_v119(
  p_category_id text,
  p_category_name text,
  p_product_code text,
  p_margin numeric,
  p_normal numeric,
  p_rare numeric,
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
  if p_normal is null or p_normal<0 or p_normal>=1 then raise exception 'Normal must be from 0%% to below 100%%.'; end if;
  if p_rare is null or p_rare<0 or p_rare>=1 then raise exception 'Rare must be from 0%% to below 100%%.'; end if;
  if p_transport is null or p_transport<0 then raise exception 'Transport must be zero or more.'; end if;
  if p_commission is null or p_commission<0 or p_commission>=1 then raise exception 'Commission must be from 0%% to below 100%%.'; end if;
  if p_set_discount is null or p_set_discount<0 or p_set_discount>=1 then raise exception 'Set Discount must be from 0%% to below 100%%.'; end if;
  if p_final_discount is null or p_final_discount<0 or p_final_discount>=1 then raise exception 'Final Discount must be from 0%% to below 100%%.'; end if;

  if exists(select 1 from public.ks_pricing_categories pc where lower(pc.category_name)=lower(v_name) and (v_id='' or pc.id<>v_id)) then
    raise exception 'A pricing category with this name already exists.';
  end if;

  v_rule:=jsonb_build_object(
    'margin',p_margin,'normal',p_normal,'rare',p_rare,'transport',p_transport,
    'commission',p_commission,'set_discount',p_set_discount,'final_discount',p_final_discount,
    'include_commission',coalesce(p_include_commission,false),
    'include_set_discount',coalesce(p_include_set_discount,false),
    'include_final_discount',coalesce(p_include_final_discount,false),
    'include_fuel_charge',coalesce(p_include_fuel_charge,false)
  );
  v_defaults:=jsonb_build_object(
    'margin',0.38,'normal',0,'rare',0,'transport',30,'commission',0.03,'set_discount',0.068,'final_discount',0.08,
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
revoke all on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
grant execute on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

-- Verification examples:
-- select chc_usd_multiplier,chc_rmb_multiplier,gws_usd_multiplier,gws_rmb_multiplier from public.ks_app_settings where id='default';
-- select model,chc_rarity,chcs_rarity,chcn_rarity from public.ks_products_chc order by source_row limit 10;
-- select model,rarity_10,rarity_16,rarity_25 from public.ks_products_gws order by source_row;
-- select category_name,product_rules from public.ks_pricing_categories order by category_name;

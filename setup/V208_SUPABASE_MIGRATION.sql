-- KeySuite V2.08
-- KeyPLC Panel Price List, Product, Category and pricing integration.
-- Also supports the V2.08 web build. Run after V205_SUPABASE_MIGRATION.sql.

begin;

-- ---------------------------------------------------------------------------
-- KeyPLC panel products and currency settings.
-- Supplied workbook values are seeded as MYR prices.
-- ---------------------------------------------------------------------------
create table if not exists public.ks_products_keyplc (
  id text primary key,
  model text not null unique,
  motor_kw numeric not null,
  source_row integer not null,
  rarity text not null default 'common',
  variants jsonb not null default '[]'::jsonb,
  status text not null default 'active',
  updated_at timestamptz not null default now()
);

alter table public.ks_products_keyplc drop constraint if exists ks_products_keyplc_rarity_check;
alter table public.ks_products_keyplc add constraint ks_products_keyplc_rarity_check check (rarity in ('common','many','rare'));

alter table public.ks_app_settings
  add column if not exists keyplc_usd_multiplier numeric not null default 5.8,
  add column if not exists keyplc_rmb_multiplier numeric not null default 0.65;

insert into public.ks_products_keyplc(id,model,motor_kw,source_row,rarity,variants,status) values
  ('KEYPLC-0001','0.75kW',0.75,1,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":200},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":300},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":400},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":500},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":600}]'::jsonb,'active'),
  ('KEYPLC-0002','1.5kW',1.5,2,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":200},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":300},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":400},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":500},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":600}]'::jsonb,'active'),
  ('KEYPLC-0003','2.2kW',2.2,3,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":200},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":300},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":400},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":500},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":600}]'::jsonb,'active'),
  ('KEYPLC-0004','4kW',4,4,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":200},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":300},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":400},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":500},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":600}]'::jsonb,'active'),
  ('KEYPLC-0005','5.5kW',5.5,5,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0006','7.5kW',7.5,6,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0007','11kW',11,7,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0008','15kW',15,8,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0009','18.5kW',18.5,9,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0010','22kW',22,10,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0011','30kW',30,11,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0012','45kW',45,12,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0013','55kW',55,13,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0014','75kW',75,14,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0015','90kW',90,15,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('KEYPLC-0016','110kW',110,16,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":5,"label":"5 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0},{"pumpQty":6,"label":"6 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active')
on conflict (model) do nothing;

-- ---------------------------------------------------------------------------
-- Security: approved KeySuite users can read. Price-list writes use RPC only.
-- ---------------------------------------------------------------------------
alter table public.ks_products_keyplc enable row level security;
drop policy if exists ks_products_keyplc_select on public.ks_products_keyplc;
create policy ks_products_keyplc_select on public.ks_products_keyplc
for select to authenticated using (public.keysuite_has_access());

grant usage on schema public to authenticated;
grant select on table public.ks_products_keyplc to authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.ks_products_keyplc from authenticated,anon;

-- ---------------------------------------------------------------------------
-- Product-family multiplier save now supports KEYPLC.
-- ---------------------------------------------------------------------------
create or replace function public.keysuite_save_product_pricelist_multiplier_v119(
  p_product_code text,p_currency text,p_multiplier numeric
)
returns table (product_code text,usd_multiplier numeric,rmb_multiplier numeric)
language plpgsql security definer set search_path=public
as $$
declare
  v_product text:=upper(trim(coalesce(p_product_code,'')));
  v_currency text:=upper(trim(coalesce(p_currency,'')));
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then
    raise exception 'Your role is not allowed to maintain Price List settings.';
  end if;
  if v_product not in ('CHC','ES','GWS','KEYPLC') then
    raise exception 'Product must be CHC, ES, GWS or KEYPLC.';
  end if;
  if v_currency not in ('USD','RMB') then raise exception 'Currency must be USD or RMB.'; end if;
  if p_multiplier is null or p_multiplier<=0 then raise exception 'Currency rate must be greater than zero.'; end if;

  update public.ks_app_settings s set
    chc_usd_multiplier=case when v_product='CHC' and v_currency='USD' then p_multiplier else s.chc_usd_multiplier end,
    chc_rmb_multiplier=case when v_product='CHC' and v_currency='RMB' then p_multiplier else s.chc_rmb_multiplier end,
    es_usd_multiplier=case when v_product='ES' and v_currency='USD' then p_multiplier else s.es_usd_multiplier end,
    es_rmb_multiplier=case when v_product='ES' and v_currency='RMB' then p_multiplier else s.es_rmb_multiplier end,
    gws_usd_multiplier=case when v_product='GWS' and v_currency='USD' then p_multiplier else s.gws_usd_multiplier end,
    gws_rmb_multiplier=case when v_product='GWS' and v_currency='RMB' then p_multiplier else s.gws_rmb_multiplier end,
    keyplc_usd_multiplier=case when v_product='KEYPLC' and v_currency='USD' then p_multiplier else s.keyplc_usd_multiplier end,
    keyplc_rmb_multiplier=case when v_product='KEYPLC' and v_currency='RMB' then p_multiplier else s.keyplc_rmb_multiplier end
  where s.id='default';
  if not found then raise exception 'KeySuite application settings were not found.'; end if;

  return query select v_product,
    case v_product when 'CHC' then s.chc_usd_multiplier when 'ES' then s.es_usd_multiplier when 'GWS' then s.gws_usd_multiplier else s.keyplc_usd_multiplier end,
    case v_product when 'CHC' then s.chc_rmb_multiplier when 'ES' then s.es_rmb_multiplier when 'GWS' then s.gws_rmb_multiplier else s.keyplc_rmb_multiplier end
  from public.ks_app_settings s where s.id='default';
end;
$$;

-- ---------------------------------------------------------------------------
-- Save all six pump-count prices for one KeyPLC motor rating.
-- Blank entries are stored as JSON null; zero remains a valid placeholder.
-- ---------------------------------------------------------------------------
create or replace function public.keysuite_save_keyplc_product_price_v208(
  p_product_id text,p_currency text,p_prices jsonb,p_rarity text
)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_currency,'')));
  v_rarity text:=lower(trim(coalesce(p_rarity,'common')));
  v_field text;
  v_variants jsonb;
  v_result jsonb:='[]'::jsonb;
  v_item jsonb;
  v_value jsonb;
  v_qty integer;
  v_pair record;
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then raise exception 'Your role is not allowed to maintain KeyPLC prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if v_rarity not in ('common','many','rare') then raise exception 'Rarity is invalid.'; end if;
  if jsonb_typeof(coalesce(p_prices,'{}'::jsonb))<>'object' then raise exception 'KeyPLC prices must be supplied as an object.'; end if;

  for v_pair in select key,value from jsonb_each(coalesce(p_prices,'{}'::jsonb)) loop
    if v_pair.key not in ('1','2','3','4','5','6') then raise exception 'Pump quantity must be from 1 to 6.'; end if;
    if v_pair.value<>'null'::jsonb and (jsonb_typeof(v_pair.value)<>'number' or (v_pair.value#>>'{}')::numeric<0) then
      raise exception 'Each KeyPLC price must be blank or zero and above.';
    end if;
  end loop;

  v_field:=case v_currency when 'USD' then 'priceUsd' when 'RMB' then 'priceRmb' else 'priceMyr' end;
  select variants into v_variants from public.ks_products_keyplc where id=p_product_id for update;
  if not found then raise exception 'KeyPLC product was not found.'; end if;

  for v_qty in 1..6 loop
    select x into v_item from jsonb_array_elements(coalesce(v_variants,'[]'::jsonb)) x
      where case when coalesce(x->>'pumpQty','') ~ '^[1-6]$' then (x->>'pumpQty')::integer else 0 end=v_qty limit 1;
    if v_item is null then
      v_item:=jsonb_build_object('pumpQty',v_qty,'label',case when v_qty=1 then '1 Pump' else v_qty||' Pumps' end,'priceUsd',null,'priceRmb',null,'priceMyr',null);
    end if;
    if coalesce(p_prices,'{}'::jsonb) ? v_qty::text then
      v_value:=coalesce(p_prices->(v_qty::text),'null'::jsonb);
      v_item:=jsonb_set(v_item,array[v_field],v_value,true);
    end if;
    v_result:=v_result||jsonb_build_array(v_item);
    v_item:=null;
  end loop;

  update public.ks_products_keyplc set variants=v_result,rarity=v_rarity,updated_at=now() where id=p_product_id;
  return jsonb_build_object('product_id',p_product_id,'currency',v_currency,'rarity',v_rarity,'variants',v_result);
end;
$$;

-- ---------------------------------------------------------------------------
-- Pricing Category editor now accepts KEYPLC.
-- ---------------------------------------------------------------------------
create or replace function public.keysuite_manage_pricing_category_v119(
  p_category_id text,p_category_name text,p_product_code text,p_margin numeric,p_normal numeric,p_rare numeric,
  p_transport numeric,p_commission numeric,p_set_discount numeric,p_final_discount numeric,
  p_include_commission boolean,p_include_set_discount boolean,p_include_final_discount boolean,p_include_fuel_charge boolean
)
returns table (category_id text,category_name text,product_rules jsonb)
language plpgsql security definer set search_path=public
as $$
declare
  v_id text:=trim(coalesce(p_category_id,''));v_name text:=trim(coalesce(p_category_name,''));
  v_product text:=upper(trim(coalesce(p_product_code,'')));v_rule jsonb;v_defaults jsonb;
begin
  if public.keysuite_permission_level('manage_categories')<>'full' then raise exception 'Your role is not allowed to manage pricing categories.'; end if;
  if v_name='' then raise exception 'Category Name is required.'; end if;
  if v_product not in ('CHC','ES','GWS','KEYPLC') then raise exception 'Product must be CHC, ES, GWS or KEYPLC.'; end if;
  if p_margin is null or p_margin<0 or p_margin>=1 then raise exception 'Margin must be from 0%% to below 100%%.'; end if;
  if p_normal is null or p_normal<0 or p_normal>=1 then raise exception 'Normal must be from 0%% to below 100%%.'; end if;
  if p_rare is null or p_rare<0 or p_rare>=1 then raise exception 'Rare must be from 0%% to below 100%%.'; end if;
  if p_transport is null or p_transport<0 then raise exception 'Transport must be zero or more.'; end if;
  if p_commission is null or p_commission<0 or p_commission>=1 then raise exception 'Commission must be from 0%% to below 100%%.'; end if;
  if p_set_discount is null or p_set_discount<0 or p_set_discount>=1 then raise exception 'Set Discount must be from 0%% to below 100%%.'; end if;
  if p_final_discount is null or p_final_discount<0 or p_final_discount>=1 then raise exception 'Final Discount must be from 0%% to below 100%%.'; end if;
  if exists(select 1 from public.ks_pricing_categories pc where lower(pc.category_name)=lower(v_name) and (v_id='' or pc.id<>v_id)) then raise exception 'A pricing category with this name already exists.'; end if;

  v_rule:=jsonb_build_object('margin',p_margin,'normal',p_normal,'rare',p_rare,'transport',p_transport,'commission',p_commission,'set_discount',p_set_discount,'final_discount',p_final_discount,'include_commission',coalesce(p_include_commission,false),'include_set_discount',coalesce(p_include_set_discount,false),'include_final_discount',coalesce(p_include_final_discount,false),'include_fuel_charge',coalesce(p_include_fuel_charge,false));
  v_defaults:=jsonb_build_object('margin',0,'normal',0,'rare',0,'transport',0,'commission',0,'set_discount',0,'final_discount',0,'include_commission',false,'include_set_discount',false,'include_final_discount',false,'include_fuel_charge',false);

  if v_id='' then
    v_id:='CCID'||upper(substr(md5(clock_timestamp()::text||random()::text||v_name),1,12));
    insert into public.ks_pricing_categories(id,category_name,final_discount,set_discount,commission,chc_factor,transport,chc_margin,product_rules)
    values(
      v_id,v_name,
      case when v_product='CHC' then p_final_discount else 0.08 end,
      case when v_product='CHC' then p_set_discount else 0.068 end,
      case when v_product='CHC' then p_commission else 0.03 end,
      case when v_product='CHC' then p_margin else 0.38 end,
      case when v_product='CHC' then p_transport else 30 end,
      case when v_product='CHC' then p_margin else 0.38 end,
      jsonb_build_object(
        'CHC',case when v_product='CHC' then v_rule else v_defaults end,
        'ES',case when v_product='ES' then v_rule else v_defaults end,
        'GWS',case when v_product='GWS' then v_rule else v_defaults end,
        'KEYPLC',case when v_product='KEYPLC' then v_rule else v_defaults end
      )
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



update public.ks_pricing_categories
set product_rules=jsonb_set(
  coalesce(product_rules,'{}'::jsonb),
  '{KEYPLC}',
  coalesce(product_rules->'KEYPLC',jsonb_build_object(
    'margin',0,'normal',0,'rare',0,'transport',0,'commission',0,
    'set_discount',0,'final_discount',0,'include_commission',false,
    'include_set_discount',false,'include_final_discount',false,'include_fuel_charge',false
  )),true
);

revoke all on function public.keysuite_save_keyplc_product_price_v208(text,text,jsonb,text) from public;
revoke all on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) from public;
revoke all on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
grant execute on function public.keysuite_save_keyplc_product_price_v208(text,text,jsonb,text) to authenticated;
grant execute on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) to authenticated;
grant execute on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

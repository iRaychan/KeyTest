-- KeySuite V2.05
-- ES Price List completion, multi-currency ES pricing, model-level rarity,
-- ES Category Pricing Rule, and ES save repair.
-- Run after the existing V2.04 migration.

begin;

-- ---------------------------------------------------------------------------
-- ES settings and model-level rarity.
-- ---------------------------------------------------------------------------
alter table public.ks_app_settings
  add column if not exists es_usd_multiplier numeric not null default 5.8,
  add column if not exists es_rmb_multiplier numeric not null default 0.65;

alter table public.ks_products_es
  add column if not exists rarity text not null default 'common';

update public.ks_products_es
set rarity=case when lower(coalesce(rarity,'')) in ('common','many','rare')
                then lower(rarity) else 'common' end;

alter table public.ks_products_es
  drop constraint if exists ks_products_es_rarity_check;
alter table public.ks_products_es
  add constraint ks_products_es_rarity_check
  check (rarity in ('common','many','rare'));

-- Make the approved six ES constructions available on every model. Existing
-- variants and prices are preserved; the two BR constructions are removed from
-- the V2.05 user interface but are not destructively deleted from the database.
update public.ks_products_es p
set variants=coalesce(p.variants,'[]'::jsonb)||coalesce((
  select jsonb_agg(jsonb_build_object(
    'material',m.material,
    'priceUsd',null,
    'priceRmb',null,
    'priceMyr',null
  ) order by m.ord)
  from unnest(array[
    'CI / SS / SS / MS',
    'CI / CI / SS / MS',
    'CI / SS / SS / GP',
    'CI / CI / SS / GP',
    'SS304',
    'SS316'
  ]::text[]) with ordinality as m(material,ord)
  where not exists (
    select 1
    from jsonb_array_elements(coalesce(p.variants,'[]'::jsonb)) elem
    where regexp_replace(upper(coalesce(elem->>'material','')),'[^A-Z0-9]+','','g')
          =regexp_replace(upper(m.material),'[^A-Z0-9]+','','g')
  )
),'[]'::jsonb),updated_at=now();

-- ---------------------------------------------------------------------------
-- Product-family multiplier save now supports ES.
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
  if v_product not in ('CHC','ES','GWS') then
    raise exception 'Product must be CHC, ES or GWS.';
  end if;
  if v_currency not in ('USD','RMB') then
    raise exception 'Currency must be USD or RMB.';
  end if;
  if p_multiplier is null or p_multiplier<=0 then
    raise exception 'Currency rate must be greater than zero.';
  end if;

  update public.ks_app_settings s set
    chc_usd_multiplier=case when v_product='CHC' and v_currency='USD' then p_multiplier else s.chc_usd_multiplier end,
    chc_rmb_multiplier=case when v_product='CHC' and v_currency='RMB' then p_multiplier else s.chc_rmb_multiplier end,
    es_usd_multiplier=case when v_product='ES' and v_currency='USD' then p_multiplier else s.es_usd_multiplier end,
    es_rmb_multiplier=case when v_product='ES' and v_currency='RMB' then p_multiplier else s.es_rmb_multiplier end,
    gws_usd_multiplier=case when v_product='GWS' and v_currency='USD' then p_multiplier else s.gws_usd_multiplier end,
    gws_rmb_multiplier=case when v_product='GWS' and v_currency='RMB' then p_multiplier else s.gws_rmb_multiplier end
  where s.id='default';

  if not found then raise exception 'KeySuite application settings were not found.'; end if;

  return query
  select v_product,
    case v_product when 'CHC' then s.chc_usd_multiplier when 'ES' then s.es_usd_multiplier else s.gws_usd_multiplier end,
    case v_product when 'CHC' then s.chc_rmb_multiplier when 'ES' then s.es_rmb_multiplier else s.gws_rmb_multiplier end
  from public.ks_app_settings s where s.id='default';
end;
$$;

-- ---------------------------------------------------------------------------
-- Save all six material prices for one ES model in the selected currency.
-- A blank input is stored as JSON null. Rarity applies to the whole model.
-- ---------------------------------------------------------------------------
create or replace function public.keysuite_save_es_product_price_v205(
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
  v_result jsonb;
  v_pair record;
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then
    raise exception 'Your role is not allowed to maintain ES prices.';
  end if;
  if v_currency not in ('USD','RMB','MYR') then
    raise exception 'Currency must be USD, RMB or MYR.';
  end if;
  if v_rarity not in ('common','many','rare') then
    raise exception 'Rarity is invalid.';
  end if;
  if jsonb_typeof(coalesce(p_prices,'{}'::jsonb))<>'object' then
    raise exception 'ES prices must be supplied as an object.';
  end if;

  for v_pair in select key,value from jsonb_each(coalesce(p_prices,'{}'::jsonb)) loop
    if v_pair.value<>'null'::jsonb then
      if jsonb_typeof(v_pair.value)<>'number' or (v_pair.value#>>'{}')::numeric<0 then
        raise exception 'Each ES price must be blank or zero and above.';
      end if;
    end if;
  end loop;

  v_field:=case v_currency when 'USD' then 'priceUsd' when 'RMB' then 'priceRmb' else 'priceMyr' end;

  select variants into v_variants
  from public.ks_products_es
  where id=p_product_id
  for update;

  if not found then raise exception 'ES product was not found.'; end if;

  select jsonb_agg(
    case when coalesce(p_prices,'{}'::jsonb) ? (x->>'material')
      then jsonb_set(x,array[v_field],coalesce(p_prices->(x->>'material'),'null'::jsonb),true)
      else x end
    order by ord
  ) into v_result
  from jsonb_array_elements(coalesce(v_variants,'[]'::jsonb)) with ordinality as item(x,ord);

  update public.ks_products_es
  set variants=coalesce(v_result,'[]'::jsonb),rarity=v_rarity,updated_at=now()
  where id=p_product_id;

  return jsonb_build_object('product_id',p_product_id,'currency',v_currency,'rarity',v_rarity,'variants',coalesce(v_result,'[]'::jsonb));
end;
$$;

-- Keep the older V2.03 single-cell RPC usable, but allow missing variants to be
-- added instead of failing. This is retained for compatibility only.
create or replace function public.keysuite_save_es_price_v203(
  p_product_id text,p_material text,p_price_usd numeric
)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare v_variants jsonb;v_result jsonb;
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then
    raise exception 'Your role is not allowed to maintain ES prices.';
  end if;
  if p_price_usd is null or p_price_usd<0 then raise exception 'Price cannot be negative.'; end if;
  select variants into v_variants from public.ks_products_es where id=p_product_id for update;
  if not found then raise exception 'ES product was not found.'; end if;
  select jsonb_agg(case when x->>'material'=p_material then jsonb_set(x,'{priceUsd}',to_jsonb(p_price_usd),true) else x end order by ord)
  into v_result from jsonb_array_elements(coalesce(v_variants,'[]'::jsonb)) with ordinality as item(x,ord);
  if not exists(select 1 from jsonb_array_elements(coalesce(v_variants,'[]'::jsonb)) x where x->>'material'=p_material) then
    v_result:=coalesce(v_result,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('material',p_material,'priceUsd',p_price_usd,'priceRmb',null,'priceMyr',null));
  end if;
  update public.ks_products_es set variants=v_result,updated_at=now() where id=p_product_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Category management now accepts ES and stores an ES rule beside CHC/GWS.
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
  if v_product not in ('CHC','ES','GWS') then raise exception 'Product must be CHC, ES or GWS.'; end if;
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
        'GWS',case when v_product='GWS' then v_rule else v_defaults end
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

-- Ensure old categories expose an ES rule immediately.
update public.ks_pricing_categories
set product_rules=jsonb_set(
  coalesce(product_rules,'{}'::jsonb),
  '{ES}',
  coalesce(product_rules->'ES',jsonb_build_object(
    'margin',0,'normal',0,'rare',0,'transport',0,'commission',0,
    'set_discount',0,'final_discount',0,'include_commission',false,
    'include_set_discount',false,'include_final_discount',false,'include_fuel_charge',false
  )),true
);

-- Security and API access.
grant usage on schema public to authenticated;
grant select on table public.ks_products_es to authenticated;
revoke all on function public.keysuite_save_es_product_price_v205(text,text,jsonb,text) from public;
revoke all on function public.keysuite_save_es_price_v203(text,text,numeric) from public;
revoke all on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) from public;
revoke all on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
grant execute on function public.keysuite_save_es_product_price_v205(text,text,jsonb,text) to authenticated;
grant execute on function public.keysuite_save_es_price_v203(text,text,numeric) to authenticated;
grant execute on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) to authenticated;
grant execute on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

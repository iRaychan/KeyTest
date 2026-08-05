-- KeySuite V2.28 Coupling Product and Price List
-- Upgrade path: V2.27 -> V2.28
begin;

alter table public.ks_app_settings
  add column if not exists coupling_usd_multiplier numeric not null default 1,
  add column if not exists coupling_rmb_multiplier numeric not null default 1;

update public.ks_app_settings s
set coupling_usd_multiplier=case when s.coupling_usd_multiplier=1 then coalesce(s.motor_usd_multiplier,s.chc_usd_multiplier,s.usd_multiplier,5.8) else s.coupling_usd_multiplier end,
    coupling_rmb_multiplier=case when s.coupling_rmb_multiplier=1 then coalesce(s.motor_rmb_multiplier,s.chc_rmb_multiplier,s.rmb_multiplier,.65) else s.coupling_rmb_multiplier end
where s.id='default';

create table if not exists public.ks_products_coupling (
  id text primary key,
  component_type text not null check (component_type in ('pin_bush','tyre','bush')),
  model text not null,
  torque_nm numeric not null default 0 check (torque_nm>=0),
  max_speed_rpm numeric not null default 0 check (max_speed_rpm>=0),
  max_shaft_mm numeric not null default 0 check (max_shaft_mm>=0),
  d1_mm numeric not null default 0 check (d1_mm>=0),
  pump_bush text not null default '',
  motor_bush text not null default '',
  source_sheet text,
  source_row integer,
  price_usd numeric not null default 0 check (price_usd>=0),
  price_rmb numeric not null default 0 check (price_rmb>=0),
  price_myr numeric not null default 0 check (price_myr>=0),
  rarity text not null default 'common' check (rarity in ('common','many','rare')),
  active boolean not null default true,
  updated_at timestamptz not null default now(),
  unique(component_type,model)
);

alter table public.ks_products_coupling enable row level security;
revoke all on table public.ks_products_coupling from public,anon,authenticated;
drop policy if exists ks_products_coupling_select on public.ks_products_coupling;
create policy ks_products_coupling_select on public.ks_products_coupling
for select to authenticated using (public.keysuite_has_access());
grant select on table public.ks_products_coupling to authenticated;

insert into public.ks_products_coupling(
  id,component_type,model,torque_nm,max_speed_rpm,max_shaft_mm,d1_mm,pump_bush,motor_bush,
  source_sheet,source_row,price_usd,price_rmb,price_myr,rarity,active
) values
('coupling-pin-bush-fcl-90','pin_bush','FCL 90',4.0,4000.0,25.0,35.5,'','','Pricelist',4,0,0.0,0,'common',true),
('coupling-pin-bush-fcl-100','pin_bush','FCL 100',10.0,4000.0,28.0,40.0,'','','Pricelist',5,0,37.37,0,'common',true),
('coupling-pin-bush-fcl-112','pin_bush','FCL 112',16.0,4000.0,32.0,45.0,'','','Pricelist',6,0,53.46,0,'common',true),
('coupling-pin-bush-fcl-125','pin_bush','FCL 125',25.0,4000.0,35.0,50.0,'','','Pricelist',7,0,66.33,0,'common',true),
('coupling-pin-bush-fcl-140','pin_bush','FCL 140',50.0,4000.0,44.0,63.0,'','','Pricelist',8,0,85.14,0,'common',true),
('coupling-pin-bush-fcl-160','pin_bush','FCL 160',110.0,4000.0,56.0,80.0,'','','Pricelist',9,0,112.86,0,'common',true),
('coupling-pin-bush-fcl-180','pin_bush','FCL 180',157.0,3500.0,63.0,90.0,'','','Pricelist',10,0,142.56,0,'common',true),
('coupling-pin-bush-fcl-200','pin_bush','FCL 200',245.0,3200.0,70.0,100.0,'','','Pricelist',11,0,221.76,0,'common',true),
('coupling-pin-bush-fcl-224','pin_bush','FCL 224',392.0,2850.0,78.0,112.0,'','','Pricelist',12,0,272.25,0,'common',true),
('coupling-pin-bush-fcl-250','pin_bush','FCL 250',618.0,2550.0,88.0,125.0,'','','Pricelist',13,0,417.78,0,'common',true),
('coupling-pin-bush-fcl-280','pin_bush','FCL 280',980.0,2300.0,98.0,140.0,'','','Pricelist',14,0,0.0,0,'common',true),
('coupling-pin-bush-fcl-315','pin_bush','FCL 315',1568.0,2050.0,112.0,160.0,'','','Pricelist',15,0,0.0,0,'common',true),
('coupling-pin-bush-fcl-355','pin_bush','FCL 355',2450.0,1800.0,126.0,180.0,'','','Pricelist',16,0,0.0,0,'common',true),
('coupling-pin-bush-fcl-400','pin_bush','FCL 400',3920.0,1600.0,140.0,200.0,'','','Pricelist',17,0,0.0,0,'common',true),
('coupling-pin-bush-fcl-450','pin_bush','FCL 450',6174.0,1400.0,157.0,224.0,'','','Pricelist',18,0,0.0,0,'common',true),
('coupling-pin-bush-fcl-560','pin_bush','FCL 560',9800.0,1150.0,175.0,250.0,'','','Pricelist',19,0,0.0,0,'common',true),
('coupling-pin-bush-fcl-630','pin_bush','FCL 630',15680.0,1000.0,196.0,280.0,'','','Pricelist',20,0,0.0,0,'common',true),
('coupling-tyre-f40','tyre','F40',24.0,4500.0,0,0,'1008','1008','Pricelist',4,0,0.0,0,'common',true),
('coupling-tyre-f50','tyre','F50',66.0,4500.0,0,0,'1210','1210','Pricelist',5,0,133.72,0,'common',true),
('coupling-tyre-f60','tyre','F60',127.0,4000.0,0,0,'1610','1610','Pricelist',6,0,185.0,0,'common',true),
('coupling-tyre-f70','tyre','F70',250.0,3600.0,0,0,'2012','1610','Pricelist',7,0,264.9,0,'common',true),
('coupling-tyre-f80','tyre','F80',375.0,3100.0,0,0,'2517','2012','Pricelist',8,0,355.91,0,'common',true),
('coupling-tyre-f90','tyre','F90',500.0,3000.0,0,0,'2517','2517','Pricelist',9,0,458.62,0,'common',true),
('coupling-tyre-f100','tyre','F100',675.0,2600.0,0,0,'3020','2517','Pricelist',10,0,597.49,0,'common',true),
('coupling-tyre-f110','tyre','F110',875.0,2300.0,0,0,'3020','3020','Pricelist',11,0,0.0,0,'common',true),
('coupling-tyre-f120','tyre','F120',1330.0,2050.0,0,0,'3525','3020','Pricelist',12,0,849.69,0,'common',true),
('coupling-tyre-f140','tyre','F140',2325.0,1800.0,0,0,'3525','3525','Pricelist',13,0,0.0,0,'common',true),
('coupling-tyre-f160','tyre','F160',3730.0,1600.0,0,0,'4030','4030','Pricelist',14,0,0.0,0,'common',true),
('coupling-tyre-f180','tyre','F180',6270.0,1500.0,0,0,'4535','4535','Pricelist',15,0,0.0,0,'common',true),
('coupling-tyre-f200','tyre','F200',9325.0,1300.0,0,0,'4535','4535','Pricelist',16,0,0.0,0,'common',true),
('coupling-tyre-f220','tyre','F220',11600.0,1100.0,0,0,'5040','5040','Pricelist',17,0,0.0,0,'common',true),
('coupling-tyre-f250','tyre','F250',14675.0,1000.0,0,0,'-','-','Pricelist',18,0,0.0,0,'common',true),
('coupling-bush-1008','bush','1008',0,0,24.0,0,'','','Pricelist',4,0,0.0,0,'common',true),
('coupling-bush-1210','bush','1210',0,0,32.0,0,'','','Pricelist',5,0,12.84,0,'common',true),
('coupling-bush-1610','bush','1610',0,0,42.0,0,'','','Pricelist',6,0,15.17,0,'common',true),
('coupling-bush-2012','bush','2012',0,0,50.0,0,'','','Pricelist',7,0,19.84,0,'common',true),
('coupling-bush-2517','bush','2517',0,0,65.0,0,'','','Pricelist',8,0,29.18,0,'common',true),
('coupling-bush-3020','bush','3020',0,0,75.0,0,'','','Pricelist',9,0,51.35,0,'common',true),
('coupling-bush-3525','bush','3525',0,0,90.0,0,'','','Pricelist',10,0,79.71,0,'common',true),
('coupling-bush-4030','bush','4030',0,0,100.0,0,'','','Pricelist',11,0,0.0,0,'common',true),
('coupling-bush-4535','bush','4535',0,0,110.0,0,'','','Pricelist',12,0,0.0,0,'common',true),
('coupling-bush-5040','bush','5040',0,0,125.0,0,'','','Pricelist',13,0,0.0,0,'common',true)
on conflict(id) do update set
  component_type=excluded.component_type,
  model=excluded.model,
  torque_nm=excluded.torque_nm,
  max_speed_rpm=excluded.max_speed_rpm,
  max_shaft_mm=excluded.max_shaft_mm,
  d1_mm=excluded.d1_mm,
  pump_bush=excluded.pump_bush,
  motor_bush=excluded.motor_bush,
  source_sheet=excluded.source_sheet,
  source_row=excluded.source_row,
  active=true,
  updated_at=now();

update public.ks_pricing_categories pc
set product_rules=jsonb_set(
  coalesce(pc.product_rules,'{}'::jsonb),
  '{COUPLING}',
  coalesce(pc.product_rules->'COUPLING',
    jsonb_build_object('margin',0,'normal',0,'rare',0,'transport',0,'use_commission',false,'use_set_discount',false,'use_final_discount',false,'use_fuel_charge',false)
  ),
  true
);

create or replace function public.keysuite_save_coupling_price_v228(
  p_product_id text,p_currency text,p_price numeric,p_rarity text
)
returns table(product_id text,currency text,price numeric,rarity text)
language plpgsql security definer set search_path=public
as $$
declare v_currency text:=upper(trim(coalesce(p_currency,'')));v_rarity text:=lower(trim(coalesce(p_rarity,'common')));
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then raise exception 'Your role is not allowed to maintain Coupling prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if p_price is null or p_price<0 then raise exception 'Coupling price must be zero or more.'; end if;
  if v_rarity not in ('common','many','rare') then raise exception 'Rarity must be Common, Many or Rare.'; end if;

  update public.ks_products_coupling c set
    price_usd=case when v_currency='USD' then p_price else c.price_usd end,
    price_rmb=case when v_currency='RMB' then p_price else c.price_rmb end,
    price_myr=case when v_currency='MYR' then p_price else c.price_myr end,
    rarity=v_rarity,updated_at=now()
  where c.id=p_product_id;
  if not found then raise exception 'Coupling item was not found.'; end if;

  return query select c.id,v_currency,
    case v_currency when 'USD' then c.price_usd when 'RMB' then c.price_rmb else c.price_myr end,
    c.rarity
  from public.ks_products_coupling c where c.id=p_product_id;
end;
$$;

create or replace function public.keysuite_save_coupling_multiplier_v228(
  p_currency text,p_multiplier numeric
)
returns table(currency text,multiplier numeric)
language plpgsql security definer set search_path=public
as $$
declare v_currency text:=upper(trim(coalesce(p_currency,'')));
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then raise exception 'Your role is not allowed to maintain Coupling currency rates.'; end if;
  if v_currency not in ('USD','RMB') then raise exception 'Currency must be USD or RMB.'; end if;
  if p_multiplier is null or p_multiplier<=0 then raise exception 'Currency rate must be greater than zero.'; end if;

  update public.ks_app_settings s set
    coupling_usd_multiplier=case when v_currency='USD' then p_multiplier else s.coupling_usd_multiplier end,
    coupling_rmb_multiplier=case when v_currency='RMB' then p_multiplier else s.coupling_rmb_multiplier end
  where s.id='default';
  if not found then raise exception 'KeySuite application settings were not found.'; end if;
  return query select v_currency,p_multiplier;
end;
$$;


create or replace function public.keysuite_manage_pricing_category_v221(
  p_category_id text,p_category_name text,p_product_code text,
  p_margin numeric,p_normal numeric,p_rare numeric,p_transport numeric,
  p_use_commission boolean,p_use_set_discount boolean,p_use_final_discount boolean,p_use_fuel_charge boolean
)
returns table (category_id text,category_name text,product_rules jsonb)
language plpgsql security definer set search_path=public
as $$
declare
  v_id text:=trim(coalesce(p_category_id,''));v_name text:=trim(coalesce(p_category_name,''));
  v_product text:=upper(trim(coalesce(p_product_code,'')));v_rule jsonb;v_defaults jsonb;
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can manage pricing categories.'; end if;
  if v_name='' then raise exception 'Category Name is required.'; end if;
  if v_product not in ('CHC','ES','GWS','KEYPLC','MANIFOLD','MOTOR','COUPLING') then raise exception 'Invalid product family.'; end if;
  if p_margin is null or p_margin<0 or p_margin>=1 or p_normal is null or p_normal<0 or p_normal>=1 or p_rare is null or p_rare<0 or p_rare>=1 then raise exception 'Percentages must be from 0%% to below 100%%.'; end if;
  if p_transport is null or p_transport<0 then raise exception 'Transport must be zero or more.'; end if;
  if exists(select 1 from public.ks_pricing_categories pc where lower(pc.category_name)=lower(v_name) and (v_id='' or pc.id<>v_id)) then raise exception 'A pricing category with this name already exists.'; end if;

  v_rule:=jsonb_build_object(
    'margin',p_margin,'normal',p_normal,'rare',p_rare,'transport',p_transport,
    'use_commission',coalesce(p_use_commission,false),
    'use_set_discount',coalesce(p_use_set_discount,false),
    'use_final_discount',coalesce(p_use_final_discount,false),
    'use_fuel_charge',coalesce(p_use_fuel_charge,false)
  );
  v_defaults:=jsonb_build_object(
    'margin',0,'normal',0,'rare',0,'transport',0,
    'use_commission',false,'use_set_discount',false,'use_final_discount',false,'use_fuel_charge',false
  );

  if v_id='' then
    v_id:='CCID'||upper(substr(md5(clock_timestamp()::text||random()::text||v_name),1,12));
    insert into public.ks_pricing_categories(id,category_name,final_discount,set_discount,commission,chc_factor,transport,chc_margin,product_rules)
    values(v_id,v_name,0,0,0,case when v_product='CHC' then p_margin else 0 end,case when v_product='CHC' then p_transport else 0 end,case when v_product='CHC' then p_margin else 0 end,
      jsonb_build_object(
        'CHC',case when v_product='CHC' then v_rule else v_defaults end,
        'ES',case when v_product='ES' then v_rule else v_defaults end,
        'GWS',case when v_product='GWS' then v_rule else v_defaults end,
        'KEYPLC',case when v_product='KEYPLC' then v_rule else v_defaults end,
        'MANIFOLD',case when v_product='MANIFOLD' then v_rule else v_defaults end,
        'MOTOR',case when v_product='MOTOR' then v_rule else v_defaults end,
        'COUPLING',case when v_product='COUPLING' then v_rule else v_defaults end
      ));
  else
    update public.ks_pricing_categories pc set
      category_name=v_name,
      product_rules=jsonb_set(coalesce(pc.product_rules,'{}'::jsonb),array[v_product],v_rule,true),
      chc_factor=case when v_product='CHC' then p_margin else pc.chc_factor end,
      chc_margin=case when v_product='CHC' then p_margin else pc.chc_margin end,
      transport=case when v_product='CHC' then p_transport else pc.transport end
    where pc.id=v_id;
    if not found then raise exception 'Pricing category was not found.'; end if;
  end if;

  return query select pc.id,pc.category_name,pc.product_rules from public.ks_pricing_categories pc where pc.id=v_id;
end;
$$;


revoke all on function public.keysuite_save_coupling_price_v228(text,text,numeric,text) from public;
revoke all on function public.keysuite_save_coupling_multiplier_v228(text,numeric) from public;
revoke all on function public.keysuite_manage_pricing_category_v221(text,text,text,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
grant execute on function public.keysuite_save_coupling_price_v228(text,text,numeric,text) to authenticated;
grant execute on function public.keysuite_save_coupling_multiplier_v228(text,numeric) to authenticated;
grant execute on function public.keysuite_manage_pricing_category_v221(text,text,text,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

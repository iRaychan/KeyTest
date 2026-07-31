-- KeySuite V1.20
-- Per-currency rarity, actual GWS tank SKUs, and save functions for the revised Price List.
-- Run after the V1.19 migration. Safe to run more than once.

begin;

alter table public.ks_app_settings add column if not exists v120_rarity_initialized boolean not null default false;
alter table public.ks_products_chc add column if not exists updated_at timestamptz not null default now();
alter table public.ks_products_gws add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- CHC rarity is stored per currency and per material variant.
-- All existing/new records start as COMMON as requested.
-- ---------------------------------------------------------------------------
alter table public.ks_products_chc add column if not exists chc_rarity_usd text not null default 'common';
alter table public.ks_products_chc add column if not exists chcs_rarity_usd text not null default 'common';
alter table public.ks_products_chc add column if not exists chcn_rarity_usd text not null default 'common';
alter table public.ks_products_chc add column if not exists chc_rarity_rmb text not null default 'common';
alter table public.ks_products_chc add column if not exists chcs_rarity_rmb text not null default 'common';
alter table public.ks_products_chc add column if not exists chcn_rarity_rmb text not null default 'common';
alter table public.ks_products_chc add column if not exists chc_rarity_myr text not null default 'common';
alter table public.ks_products_chc add column if not exists chcs_rarity_myr text not null default 'common';
alter table public.ks_products_chc add column if not exists chcn_rarity_myr text not null default 'common';

update public.ks_products_chc set
  chc_rarity_usd='common',chcs_rarity_usd='common',chcn_rarity_usd='common',
  chc_rarity_rmb='common',chcs_rarity_rmb='common',chcn_rarity_rmb='common',
  chc_rarity_myr='common',chcs_rarity_myr='common',chcn_rarity_myr='common',
  chc_rarity='common',chcs_rarity='common',chcn_rarity='common'
where exists (select 1 from public.ks_app_settings s where s.id='default' and not coalesce(s.v120_rarity_initialized,false));

do $$
declare c text;
begin
  foreach c in array array[
    'chc_rarity_usd','chcs_rarity_usd','chcn_rarity_usd',
    'chc_rarity_rmb','chcs_rarity_rmb','chcn_rarity_rmb',
    'chc_rarity_myr','chcs_rarity_myr','chcn_rarity_myr'
  ] loop
    execute format('alter table public.ks_products_chc drop constraint if exists %I','ks_products_chc_'||c||'_check');
    execute format('alter table public.ks_products_chc add constraint %I check (%I in (''common'',''many'',''rare''))','ks_products_chc_'||c||'_check',c);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- GWS actual sellable SKU structure.
-- Legacy size rows remain for data migration only and are marked legacy.
-- ---------------------------------------------------------------------------
alter table public.ks_products_gws add column if not exists series_code text;
alter table public.ks_products_gws add column if not exists series_name text;
alter table public.ks_products_gws add column if not exists size_code text;
alter table public.ks_products_gws add column if not exists size_litres integer;
alter table public.ks_products_gws add column if not exists pressure_bar integer;
alter table public.ks_products_gws add column if not exists system_connection text;
alter table public.ks_products_gws add column if not exists precharge_text text;
alter table public.ks_products_gws add column if not exists max_working_pressure_text text;
alter table public.ks_products_gws add column if not exists max_working_temperature_text text;
alter table public.ks_products_gws add column if not exists price_usd numeric;
alter table public.ks_products_gws add column if not exists price_rmb numeric;
alter table public.ks_products_gws add column if not exists price_myr numeric;
alter table public.ks_products_gws add column if not exists rarity_usd text not null default 'common';
alter table public.ks_products_gws add column if not exists rarity_rmb text not null default 'common';
alter table public.ks_products_gws add column if not exists rarity_myr text not null default 'common';

alter table public.ks_products_gws drop constraint if exists ks_products_gws_rarity_usd_check;
alter table public.ks_products_gws add constraint ks_products_gws_rarity_usd_check check (rarity_usd in ('common','many','rare'));
alter table public.ks_products_gws drop constraint if exists ks_products_gws_rarity_rmb_check;
alter table public.ks_products_gws add constraint ks_products_gws_rarity_rmb_check check (rarity_rmb in ('common','many','rare'));
alter table public.ks_products_gws drop constraint if exists ks_products_gws_rarity_myr_check;
alter table public.ks_products_gws add constraint ks_products_gws_rarity_myr_check check (rarity_myr in ('common','many','rare'));

-- E-Wave, 10 Bar. Only PEB 24LX is available.
insert into public.ks_products_gws
(id,model,series_code,series_name,size_code,size_litres,pressure_bar,system_connection,precharge_text,max_working_pressure_text,max_working_temperature_text,source_row,status)
values
('GWS-PEB-24LX','PEB 24LX','PEB','E-Wave Series','24LX',24,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',4,'active')
on conflict (model) do update set series_code=excluded.series_code,series_name=excluded.series_name,size_code=excluded.size_code,size_litres=excluded.size_litres,pressure_bar=excluded.pressure_bar,system_connection=excluded.system_connection,precharge_text=excluded.precharge_text,max_working_pressure_text=excluded.max_working_pressure_text,max_working_temperature_text=excluded.max_working_temperature_text,source_row=excluded.source_row,status='active';

update public.ks_products_gws set status='inactive',updated_at=now()
where series_code='PEB' and model in ('PEB 8LX','PEB 12LX','PEB 18LX','PEB 35LX');

-- Pressure Wave, 10 Bar, up to 150L.
insert into public.ks_products_gws
(id,model,series_code,series_name,size_code,size_litres,pressure_bar,system_connection,precharge_text,max_working_pressure_text,max_working_temperature_text,source_row,status)
values
('GWS-PWB-8LX','PWB 8LX','PWB','Pressure Wave Series','8LX',8,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',11,'active'),
('GWS-PWB-12LX','PWB 12LX','PWB','Pressure Wave Series','12LX',12,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',12,'active'),
('GWS-PWB-18LX','PWB 18LX','PWB','Pressure Wave Series','18LX',18,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',13,'active'),
('GWS-PWB-24LX','PWB 24LX','PWB','Pressure Wave Series','24LX',24,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',14,'active'),
('GWS-PWB-35LX','PWB 35LX','PWB','Pressure Wave Series','35LX',35,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',15,'active'),
('GWS-PWB-60LV','PWB 60LV','PWB','Pressure Wave Series','60LV',60,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',16,'active'),
('GWS-PWB-80LV','PWB 80LV','PWB','Pressure Wave Series','80LV',80,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',17,'active'),
('GWS-PWB-100LV','PWB 100LV','PWB','Pressure Wave Series','100LV',100,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',18,'active'),
('GWS-PWB-130LV','PWB 130LV','PWB','Pressure Wave Series','130LV',130,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',19,'active'),
('GWS-PWB-150LV','PWB 150LV','PWB','Pressure Wave Series','150LV',150,10,'1"','1.9 bar / 28 psi','10 bar / 150 psi','90°C / 194°F',20,'active')
on conflict (model) do update set series_code=excluded.series_code,series_name=excluded.series_name,size_code=excluded.size_code,size_litres=excluded.size_litres,pressure_bar=excluded.pressure_bar,system_connection=excluded.system_connection,precharge_text=excluded.precharge_text,max_working_pressure_text=excluded.max_working_pressure_text,max_working_temperature_text=excluded.max_working_temperature_text,source_row=excluded.source_row,status='active';

-- Max Series, 16 Bar, up to 100L.
insert into public.ks_products_gws
(id,model,series_code,series_name,size_code,size_litres,pressure_bar,system_connection,precharge_text,max_working_pressure_text,max_working_temperature_text,source_row,status)
values
('GWS-MXB-8LX','MXB 8LX','MXB','Max Series','8LX',8,16,'1"','4.0 bar / 58 psi','16 bar / 232 psi','90°C / 194°F',31,'active'),
('GWS-MXB-12LX','MXB 12LX','MXB','Max Series','12LX',12,16,'1"','4.0 bar / 58 psi','16 bar / 232 psi','90°C / 194°F',32,'active'),
('GWS-MXB-18LX','MXB 18LX','MXB','Max Series','18LX',18,16,'1"','4.0 bar / 58 psi','16 bar / 232 psi','90°C / 194°F',33,'active'),
('GWS-MXB-24LX','MXB 24LX','MXB','Max Series','24LX',24,16,'1"','4.0 bar / 58 psi','16 bar / 232 psi','90°C / 194°F',34,'active'),
('GWS-MXB-35LX','MXB 35LX','MXB','Max Series','35LX',35,16,'1"','4.0 bar / 58 psi','16 bar / 232 psi','90°C / 194°F',35,'active'),
('GWS-MXB-60LV','MXB 60LV','MXB','Max Series','60LV',60,16,'1"','4.0 bar / 58 psi','16 bar / 232 psi','90°C / 194°F',36,'active'),
('GWS-MXB-80LV','MXB 80LV','MXB','Max Series','80LV',80,16,'1"','4.0 bar / 58 psi','16 bar / 232 psi','90°C / 194°F',37,'active'),
('GWS-MXB-100LV','MXB 100LV','MXB','Max Series','100LV',100,16,'1"','4.0 bar / 58 psi','16 bar / 232 psi','90°C / 194°F',38,'active')
on conflict (model) do update set series_code=excluded.series_code,series_name=excluded.series_name,size_code=excluded.size_code,size_litres=excluded.size_litres,pressure_bar=excluded.pressure_bar,system_connection=excluded.system_connection,precharge_text=excluded.precharge_text,max_working_pressure_text=excluded.max_working_pressure_text,max_working_temperature_text=excluded.max_working_temperature_text,source_row=excluded.source_row,status='active';

-- Ultra Max, 25 Bar, only 8LX, 24LX and 100LV.
insert into public.ks_products_gws
(id,model,series_code,series_name,size_code,size_litres,pressure_bar,system_connection,precharge_text,max_working_pressure_text,max_working_temperature_text,source_row,status)
values
('GWS-UMB-8LX','UMB 8LX','UMB','Ultra Max Series','8LX',8,25,'1"','4.0 bar / 58 psi','25 bar / 362 psi','90°C / 194°F',41,'active'),
('GWS-UMB-24LX','UMB 24LX','UMB','Ultra Max Series','24LX',24,25,'1"','4.0 bar / 58 psi','25 bar / 362 psi','90°C / 194°F',42,'active'),
('GWS-UMB-100LV','UMB 100LV','UMB','Ultra Max Series','100LV',100,25,'1"','4.0 bar / 58 psi','25 bar / 362 psi','90°C / 194°F',43,'active')
on conflict (model) do update set series_code=excluded.series_code,series_name=excluded.series_name,size_code=excluded.size_code,size_litres=excluded.size_litres,pressure_bar=excluded.pressure_bar,system_connection=excluded.system_connection,precharge_text=excluded.precharge_text,max_working_pressure_text=excluded.max_working_pressure_text,max_working_temperature_text=excluded.max_working_temperature_text,source_row=excluded.source_row,status='active';

-- Challenger. Quotation selection is 10 Bar; tank maximum working pressure remains 16 Bar.
insert into public.ks_products_gws
(id,model,series_code,series_name,size_code,size_litres,pressure_bar,system_connection,precharge_text,max_working_pressure_text,max_working_temperature_text,source_row,status)
values
('GWS-GCB-200LV','GCB 200LV','GCB','Challenger Series','200LV',200,10,'1 1/4” BSP stainless steel elbow','Refer tank packaging','16 bar / 232 psi','90°C / 194°F',51,'active'),
('GWS-GCB-300LV','GCB 300LV','GCB','Challenger Series','300LV',300,10,'1 1/4” BSP stainless steel elbow','Refer tank packaging','16 bar / 232 psi','90°C / 194°F',52,'active')
on conflict (model) do update set series_code=excluded.series_code,series_name=excluded.series_name,size_code=excluded.size_code,size_litres=excluded.size_litres,pressure_bar=excluded.pressure_bar,system_connection=excluded.system_connection,precharge_text=excluded.precharge_text,max_working_pressure_text=excluded.max_working_pressure_text,max_working_temperature_text=excluded.max_working_temperature_text,source_row=excluded.source_row,status='active';

-- Superflow 1000L.
insert into public.ks_products_gws
(id,model,series_code,series_name,size_code,size_litres,pressure_bar,system_connection,precharge_text,max_working_pressure_text,max_working_temperature_text,source_row,status)
values
('GWS-SFB-1000LV','SFB 1000LV','SFB','Superflow Series','1000LV',1000,10,null,null,null,null,61,'active'),
('GWS-SMB-1000LV','SMB 1000LV','SMB','Superflow Series','1000LV',1000,16,null,null,null,null,62,'active'),
('GWS-SUB-1000LV','SUB 1000LV','SUB','Superflow Series','1000LV',1000,25,null,null,null,null,63,'active')
on conflict (model) do update set series_code=excluded.series_code,series_name=excluded.series_name,size_code=excluded.size_code,size_litres=excluded.size_litres,pressure_bar=excluded.pressure_bar,system_connection=excluded.system_connection,precharge_text=excluded.precharge_text,max_working_pressure_text=excluded.max_working_pressure_text,max_working_temperature_text=excluded.max_working_temperature_text,source_row=excluded.source_row,status='active';

-- Preserve existing generic price data in the closest actual SKU.
update public.ks_products_gws t set
  price_usd=coalesce(t.price_usd,s.price_10_usd),price_rmb=coalesce(t.price_rmb,s.price_10_rmb),price_myr=coalesce(t.price_myr,s.price_10_myr)
from public.ks_products_gws s
where t.series_code='PWB' and s.model=t.size_code and s.series_code is null;

update public.ks_products_gws t set
  price_usd=coalesce(t.price_usd,s.price_16_usd),price_rmb=coalesce(t.price_rmb,s.price_16_rmb),price_myr=coalesce(t.price_myr,s.price_16_myr)
from public.ks_products_gws s
where t.series_code='MXB' and s.model=t.size_code and s.series_code is null;

update public.ks_products_gws t set
  price_usd=coalesce(t.price_usd,s.price_25_usd),price_rmb=coalesce(t.price_rmb,s.price_25_rmb),price_myr=coalesce(t.price_myr,s.price_25_myr)
from public.ks_products_gws s
where t.series_code='UMB' and s.model=t.size_code and s.series_code is null;

update public.ks_products_gws t set
  price_usd=coalesce(t.price_usd,s.price_10_usd),price_rmb=coalesce(t.price_rmb,s.price_10_rmb),price_myr=coalesce(t.price_myr,s.price_10_myr)
from public.ks_products_gws s
where t.series_code='GCB' and s.model=t.size_code and s.series_code is null;

update public.ks_products_gws set rarity_usd='common',rarity_rmb='common',rarity_myr='common'
where series_code is not null
  and exists (select 1 from public.ks_app_settings s where s.id='default' and not coalesce(s.v120_rarity_initialized,false));
update public.ks_products_gws set status='legacy' where series_code is null;
update public.ks_app_settings set v120_rarity_initialized=true where id='default';

-- ---------------------------------------------------------------------------
-- Save CHC prices and per-currency rarity.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_save_chc_product_price_v120(text,text,numeric,numeric,numeric,text,text,text);
create function public.keysuite_save_chc_product_price_v120(
  p_product_id text,p_currency text,
  p_chc_price numeric,p_chcs_price numeric,p_chcn_price numeric,
  p_chc_rarity text,p_chcs_rarity text,p_chcn_rarity text
)
returns table (product_id text,currency text,chc_price numeric,chcs_price numeric,chcn_price numeric,chc_rarity text,chcs_rarity text,chcn_rarity text)
language plpgsql security definer set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_currency,'')));
  v_chc_rarity text:=lower(trim(coalesce(p_chc_rarity,'common')));
  v_chcs_rarity text:=lower(trim(coalesce(p_chcs_rarity,'common')));
  v_chcn_rarity text:=lower(trim(coalesce(p_chcn_rarity,'common')));
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can maintain product prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_chc_price is not null and p_chc_price<0 then raise exception 'CHC Price cannot be negative.'; end if;
  if p_chcs_price is not null and p_chcs_price<0 then raise exception 'CHCS Price cannot be negative.'; end if;
  if p_chcn_price is not null and p_chcn_price<0 then raise exception 'CHCN Price cannot be negative.'; end if;
  if v_chc_rarity not in ('common','many','rare') or v_chcs_rarity not in ('common','many','rare') or v_chcn_rarity not in ('common','many','rare') then raise exception 'Rarity is invalid.'; end if;

  update public.ks_products_chc p set
    chc_usd=case when v_currency='USD' then p_chc_price else p.chc_usd end,
    chcs_usd=case when v_currency='USD' then p_chcs_price else p.chcs_usd end,
    chcn_usd=case when v_currency='USD' then p_chcn_price else p.chcn_usd end,
    chc_rmb=case when v_currency='RMB' then p_chc_price else p.chc_rmb end,
    chcs_rmb=case when v_currency='RMB' then p_chcs_price else p.chcs_rmb end,
    chcn_rmb=case when v_currency='RMB' then p_chcn_price else p.chcn_rmb end,
    chc_myr=case when v_currency='MYR' then p_chc_price else p.chc_myr end,
    chcs_myr=case when v_currency='MYR' then p_chcs_price else p.chcs_myr end,
    chcn_myr=case when v_currency='MYR' then p_chcn_price else p.chcn_myr end,
    chc_rarity_usd=case when v_currency='USD' then v_chc_rarity else p.chc_rarity_usd end,
    chcs_rarity_usd=case when v_currency='USD' then v_chcs_rarity else p.chcs_rarity_usd end,
    chcn_rarity_usd=case when v_currency='USD' then v_chcn_rarity else p.chcn_rarity_usd end,
    chc_rarity_rmb=case when v_currency='RMB' then v_chc_rarity else p.chc_rarity_rmb end,
    chcs_rarity_rmb=case when v_currency='RMB' then v_chcs_rarity else p.chcs_rarity_rmb end,
    chcn_rarity_rmb=case when v_currency='RMB' then v_chcn_rarity else p.chcn_rarity_rmb end,
    chc_rarity_myr=case when v_currency='MYR' then v_chc_rarity else p.chc_rarity_myr end,
    chcs_rarity_myr=case when v_currency='MYR' then v_chcs_rarity else p.chcs_rarity_myr end,
    chcn_rarity_myr=case when v_currency='MYR' then v_chcn_rarity else p.chcn_rarity_myr end,
    updated_at=now()
  where p.id=p_product_id;
  if not found then raise exception 'CHC model was not found.'; end if;

  return query select p.id,v_currency,
    case v_currency when 'USD' then p.chc_usd when 'RMB' then p.chc_rmb else p.chc_myr end,
    case v_currency when 'USD' then p.chcs_usd when 'RMB' then p.chcs_rmb else p.chcs_myr end,
    case v_currency when 'USD' then p.chcn_usd when 'RMB' then p.chcn_rmb else p.chcn_myr end,
    case v_currency when 'USD' then p.chc_rarity_usd when 'RMB' then p.chc_rarity_rmb else p.chc_rarity_myr end,
    case v_currency when 'USD' then p.chcs_rarity_usd when 'RMB' then p.chcs_rarity_rmb else p.chcs_rarity_myr end,
    case v_currency when 'USD' then p.chcn_rarity_usd when 'RMB' then p.chcn_rarity_rmb else p.chcn_rarity_myr end
  from public.ks_products_chc p where p.id=p_product_id;
end;
$$;
revoke all on function public.keysuite_save_chc_product_price_v120(text,text,numeric,numeric,numeric,text,text,text) from public;
grant execute on function public.keysuite_save_chc_product_price_v120(text,text,numeric,numeric,numeric,text,text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- Save one actual GWS SKU price and per-currency rarity.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_save_gws_sku_price_v120(text,text,numeric,text);
create function public.keysuite_save_gws_sku_price_v120(
  p_product_id text,p_currency text,p_price numeric,p_rarity text
)
returns table (product_id text,currency text,price numeric,rarity text)
language plpgsql security definer set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_currency,'')));
  v_rarity text:=lower(trim(coalesce(p_rarity,'common')));
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can maintain product prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_price is not null and p_price<0 then raise exception 'Price cannot be negative.'; end if;
  if v_rarity not in ('common','many','rare') then raise exception 'Rarity is invalid.'; end if;

  update public.ks_products_gws p set
    price_usd=case when v_currency='USD' then p_price else p.price_usd end,
    price_rmb=case when v_currency='RMB' then p_price else p.price_rmb end,
    price_myr=case when v_currency='MYR' then p_price else p.price_myr end,
    rarity_usd=case when v_currency='USD' then v_rarity else p.rarity_usd end,
    rarity_rmb=case when v_currency='RMB' then v_rarity else p.rarity_rmb end,
    rarity_myr=case when v_currency='MYR' then v_rarity else p.rarity_myr end,
    updated_at=now()
  where p.id=p_product_id and p.status='active';
  if not found then raise exception 'GWS Tank SKU was not found.'; end if;

  return query select p.id,v_currency,
    case v_currency when 'USD' then p.price_usd when 'RMB' then p.price_rmb else p.price_myr end,
    case v_currency when 'USD' then p.rarity_usd when 'RMB' then p.rarity_rmb else p.rarity_myr end
  from public.ks_products_gws p where p.id=p_product_id;
end;
$$;
revoke all on function public.keysuite_save_gws_sku_price_v120(text,text,numeric,text) from public;
grant execute on function public.keysuite_save_gws_sku_price_v120(text,text,numeric,text) to authenticated;

notify pgrst,'reload schema';
commit;

-- Verification:
-- select model,series_name,size_code,pressure_bar,price_usd,rarity_usd from public.ks_products_gws where status='active' order by source_row;
-- select model,chc_rarity_usd,chc_rarity_rmb,chc_rarity_myr from public.ks_products_chc order by source_row limit 10;

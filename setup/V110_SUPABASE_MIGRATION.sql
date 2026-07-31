-- KeySuite V1.10
-- Customer distance, persistent fuel-price setting, and corrected margin-based pricing.
-- Run once in Supabase SQL Editor before uploading/testing V1.10.

-- 1) Customer distance -------------------------------------------------------
alter table public.ks_customers
  add column if not exists distance_km numeric not null default 0;

update public.ks_customers
set distance_km = 0
where distance_km is null or distance_km < 0;

alter table public.ks_customers
  drop constraint if exists ks_customers_distance_km_check;

alter table public.ks_customers
  add constraint ks_customers_distance_km_check check (distance_km >= 0);

-- Only Owner/Admin may change Distance. Normal users can still edit their
-- assigned customer records, but this trigger preserves the saved distance.
create or replace function public.keysuite_protect_customer_distance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.keysuite_is_admin() then
    if tg_op = 'INSERT' then
      new.distance_km := 0;
    elsif new.distance_km is distinct from old.distance_km then
      raise exception 'Only Owner or Admin can change customer distance.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.keysuite_protect_customer_distance() from public;

drop trigger if exists keysuite_customer_distance_guard on public.ks_customers;
create trigger keysuite_customer_distance_guard
before insert or update of distance_km on public.ks_customers
for each row execute function public.keysuite_protect_customer_distance();

-- 2) Correct pricing terminology --------------------------------------------
-- Keep the old chc_factor column for compatibility, but copy its value into
-- the correctly named margin field. V1.10 treats 0.38 as a 38% margin.
alter table public.ks_pricing_categories
  add column if not exists chc_margin numeric;

update public.ks_pricing_categories
set chc_margin = coalesce(chc_margin, chc_factor, 0);

alter table public.ks_pricing_categories
  drop constraint if exists ks_pricing_categories_chc_margin_check;

alter table public.ks_pricing_categories
  add constraint ks_pricing_categories_chc_margin_check
  check (chc_margin >= 0 and chc_margin < 1);

-- 3) Persistent fuel setting -------------------------------------------------
alter table public.ks_app_settings
  add column if not exists fuel_price numeric not null default 2.00;

alter table public.ks_app_settings
  add column if not exists fuel_base_price numeric not null default 2.00;

insert into public.ks_app_settings
  (id, currency, source_currency, currency_multiplier, fuel_price, fuel_base_price)
values
  ('default', 'MYR', 'USD', 5.80, 2.00, 2.00)
on conflict (id) do nothing;

update public.ks_app_settings
set fuel_price = coalesce(fuel_price, 2.00),
    fuel_base_price = 2.00
where id = 'default';

alter table public.ks_app_settings
  drop constraint if exists ks_app_settings_fuel_price_check;
alter table public.ks_app_settings
  add constraint ks_app_settings_fuel_price_check check (fuel_price >= 0);

alter table public.ks_app_settings
  drop constraint if exists ks_app_settings_fuel_base_price_check;
alter table public.ks_app_settings
  add constraint ks_app_settings_fuel_base_price_check check (fuel_base_price >= 0);

-- Authenticated users may continue reading settings. Only Owner/Admin can
-- update the current Fuel Price.
drop policy if exists keysuite_settings_admin_update on public.ks_app_settings;
create policy keysuite_settings_admin_update
on public.ks_app_settings for update
to authenticated
using (
  public.keysuite_has_access()
  and public.keysuite_is_admin()
)
with check (
  public.keysuite_has_access()
  and public.keysuite_is_admin()
);

grant update (fuel_price) on table public.ks_app_settings to authenticated;

-- Refresh Supabase/PostgREST schema cache.
notify pgrst, 'reload schema';

select
  (select count(*) from public.ks_customers) as customer_records,
  (select fuel_price from public.ks_app_settings where id='default') as fuel_price,
  (select fuel_base_price from public.ks_app_settings where id='default') as fuel_base_price,
  (select chc_margin from public.ks_pricing_categories order by id limit 1) as chc_margin;

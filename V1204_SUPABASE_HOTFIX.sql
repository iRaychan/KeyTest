-- KeySuite V1.20.4 hotfix
-- Fixes CHC/GWS price and rarity saving and corrects the E-Wave SKU list.
-- Safe to run more than once.

begin;

-- V1.20 save functions update updated_at. Older CHC tables did not contain it.
alter table if exists public.ks_products_chc
  add column if not exists updated_at timestamptz not null default now();

-- Defensive: GWS normally already has this column from V1.18.
alter table if exists public.ks_products_gws
  add column if not exists updated_at timestamptz not null default now();

-- E-Wave has only PEB 24LX. Keep unsupported legacy entries out of Product and Price List.
update public.ks_products_gws
set status='inactive', updated_at=now()
where series_code='PEB'
  and model in ('PEB 8LX','PEB 12LX','PEB 18LX','PEB 35LX');

update public.ks_products_gws
set status='active', updated_at=now()
where series_code='PEB' and model='PEB 24LX';

notify pgrst,'reload schema';
commit;

-- Verification:
-- select column_name from information_schema.columns
-- where table_schema='public' and table_name='ks_products_chc' and column_name='updated_at';
-- select model,status from public.ks_products_gws where series_code='PEB' order by source_row;

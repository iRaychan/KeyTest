-- KeySuite V2.13
-- Manifold workbook integration, including Price List tables, Product selection,
-- Pricing Category rules and Company Pricing support.
-- Run once after the existing KeySuite migrations, before deploying the V2.13 web files.

begin;

-- ---------------------------------------------------------------------------
-- Manifold workbook tables.
-- Source workbook: 010 - Manifold (Pricelist) - 260801 - V1.0.xlsx
-- Sections: Branch, Manifold Sizing, Header and Tank Fitting.
-- ---------------------------------------------------------------------------
create table if not exists public.ks_products_manifold (
  id text primary key,
  section text not null,
  model text not null,
  source_row integer not null,
  rarity text not null default 'common',
  variants jsonb not null default '[]'::jsonb,
  status text not null default 'active',
  updated_at timestamptz not null default now(),
  unique(section,model)
);

alter table public.ks_products_manifold drop constraint if exists ks_products_manifold_section_check;
alter table public.ks_products_manifold add constraint ks_products_manifold_section_check
  check (section in ('branch','sizing','header','tank_fitting'));
alter table public.ks_products_manifold drop constraint if exists ks_products_manifold_rarity_check;
alter table public.ks_products_manifold add constraint ks_products_manifold_rarity_check
  check (rarity in ('common','many','rare'));
alter table public.ks_products_manifold drop constraint if exists ks_products_manifold_variants_check;
alter table public.ks_products_manifold add constraint ks_products_manifold_variants_check
  check (jsonb_typeof(variants)='array');

alter table public.ks_app_settings
  add column if not exists manifold_usd_multiplier numeric not null default 5.8,
  add column if not exists manifold_rmb_multiplier numeric not null default 0.65;

insert into public.ks_products_manifold(id,section,model,source_row,rarity,variants,status) values
  ('MANIFOLD-BRANCH-DN25','branch','DN25',1,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":0},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":0},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":0},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":0},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":0},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":0}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN32','branch','DN32',2,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN40','branch','DN40',3,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN50','branch','DN50',4,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN65','branch','DN65',5,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN80','branch','DN80',6,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN100','branch','DN100',7,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN125','branch','DN125',8,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN150','branch','DN150',9,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-BRANCH-DN200','branch','DN200',10,'common','[{"code":"GI_THREAD_10","label":"GI Thread @ 10 Bar","material":"GI","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_THREAD_10","label":"SS Thread @ 10 Bar","material":"SS","connection":"THREAD","pressureBar":10,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_16","label":"GI Flange @ 16 Bar","material":"GI","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_16","label":"SS Flange @ 16 Bar","material":"SS","connection":"FLANGE","pressureBar":16,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"GI_FLANGE_25","label":"GI Flange @ 25 Bar","material":"GI","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100},{"code":"SS_FLANGE_25","label":"SS Flange @ 25 Bar","material":"SS","connection":"FLANGE","pressureBar":25,"priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN25','sizing','DN25',1,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN25"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN40"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN50"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN65"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN80"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN100"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN32','sizing','DN32',2,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN32"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN50"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN65"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN80"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN100"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN100"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN40','sizing','DN40',3,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN40"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN65"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN80"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN100"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN100"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN150"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN50','sizing','DN50',4,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN50"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN80"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN100"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN100"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN150"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN200"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN65','sizing','DN65',5,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN65"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN100"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN100"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN150"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN200"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN250"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN80','sizing','DN80',6,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN80"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN100"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN150"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN200"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN250"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN300"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN100','sizing','DN100',7,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN100"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN150"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN200"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN250"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN300"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN350"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN125','sizing','DN125',8,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN125"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN200"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN250"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN300"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN350"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN400"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN150','sizing','DN150',9,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN150"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN200"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN250"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN350"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN400"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN450"}]'::jsonb,'active'),
  ('MANIFOLD-SIZING-DN200','sizing','DN200',10,'common','[{"pumpQty":1,"label":"1 Pump","resultDn":"DN200"},{"pumpQty":2,"label":"2 Pumps","resultDn":"DN300"},{"pumpQty":3,"label":"3 Pumps","resultDn":"DN300"},{"pumpQty":4,"label":"4 Pumps","resultDn":"DN400"},{"pumpQty":5,"label":"5 Pumps","resultDn":"DN450"},{"pumpQty":6,"label":"6 Pumps","resultDn":"DN500"}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN40','header','GI DN40',1,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN50','header','GI DN50',2,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN65','header','GI DN65',3,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN80','header','GI DN80',4,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN100','header','GI DN100',5,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN150','header','GI DN150',6,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN200','header','GI DN200',7,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN250','header','GI DN250',8,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN300','header','GI DN300',9,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-GI-DN350','header','GI DN350',10,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":100}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN40','header','SS DN40',11,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN50','header','SS DN50',12,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN65','header','SS DN65',13,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN80','header','SS DN80',14,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN100','header','SS DN100',15,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN150','header','SS DN150',16,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN200','header','SS DN200',17,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN250','header','SS DN250',18,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN300','header','SS DN300',19,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-HEADER-SS-DN350','header','SS DN350',20,'common','[{"pumpQty":1,"label":"1 Pump","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":2,"label":"2 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":3,"label":"3 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000},{"pumpQty":4,"label":"4 Pumps","priceUsd":null,"priceRmb":null,"priceMyr":1000}]'::jsonb,'active'),
  ('MANIFOLD-TANK-2L','tank_fitting','2L',1,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"2L","priceUsd":null,"priceRmb":null,"priceMyr":20}]'::jsonb,'active'),
  ('MANIFOLD-TANK-8L','tank_fitting','8L',2,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"8L","priceUsd":null,"priceRmb":null,"priceMyr":20}]'::jsonb,'active'),
  ('MANIFOLD-TANK-12L','tank_fitting','12L',3,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"12L","priceUsd":null,"priceRmb":null,"priceMyr":20}]'::jsonb,'active'),
  ('MANIFOLD-TANK-18L','tank_fitting','18L',4,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"18L","priceUsd":null,"priceRmb":null,"priceMyr":20}]'::jsonb,'active'),
  ('MANIFOLD-TANK-24L','tank_fitting','24L',5,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"24L","priceUsd":null,"priceRmb":null,"priceMyr":20}]'::jsonb,'active'),
  ('MANIFOLD-TANK-35L','tank_fitting','35L',6,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"35L","priceUsd":null,"priceRmb":null,"priceMyr":20}]'::jsonb,'active'),
  ('MANIFOLD-TANK-60L','tank_fitting','60L',7,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"60L","priceUsd":null,"priceRmb":null,"priceMyr":530}]'::jsonb,'active'),
  ('MANIFOLD-TANK-100L','tank_fitting','100L',8,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"100L","priceUsd":null,"priceRmb":null,"priceMyr":530}]'::jsonb,'active'),
  ('MANIFOLD-TANK-130L','tank_fitting','130L',9,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"130L","priceUsd":null,"priceRmb":null,"priceMyr":530}]'::jsonb,'active'),
  ('MANIFOLD-TANK-150L','tank_fitting','150L',10,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"150L","priceUsd":null,"priceRmb":null,"priceMyr":530}]'::jsonb,'active'),
  ('MANIFOLD-TANK-200L','tank_fitting','200L',11,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"200L","priceUsd":null,"priceRmb":null,"priceMyr":530}]'::jsonb,'active'),
  ('MANIFOLD-TANK-300L','tank_fitting','300L',12,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"300L","priceUsd":null,"priceRmb":null,"priceMyr":530}]'::jsonb,'active'),
  ('MANIFOLD-TANK-500L','tank_fitting','500L',13,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"500L","priceUsd":null,"priceRmb":null,"priceMyr":530}]'::jsonb,'active'),
  ('MANIFOLD-TANK-1000L','tank_fitting','1000L',14,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"1000L","priceUsd":null,"priceRmb":null,"priceMyr":880}]'::jsonb,'active'),
  ('MANIFOLD-TANK-2000L','tank_fitting','2000L',15,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"2000L","priceUsd":null,"priceRmb":null,"priceMyr":1080}]'::jsonb,'active'),
  ('MANIFOLD-TANK-3000L','tank_fitting','3000L',16,'common','[{"code":"FITTING","label":"Tank Fitting","tankSize":"3000L","priceUsd":null,"priceRmb":null,"priceMyr":1280}]'::jsonb,'active')
on conflict (section,model) do nothing;

-- ---------------------------------------------------------------------------
-- Security. Approved KeySuite users can read. Writes are performed by RPC.
-- ---------------------------------------------------------------------------
alter table public.ks_products_manifold enable row level security;
drop policy if exists ks_products_manifold_select on public.ks_products_manifold;
create policy ks_products_manifold_select on public.ks_products_manifold
for select to authenticated using (public.keysuite_has_access());

grant usage on schema public to authenticated;
grant select on table public.ks_products_manifold to authenticated;
revoke insert,update,delete,truncate,references,trigger on table public.ks_products_manifold from authenticated,anon;

-- ---------------------------------------------------------------------------
-- Product-family currency-rate save now supports MANIFOLD.
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
  if v_product not in ('CHC','ES','GWS','KEYPLC','MANIFOLD') then
    raise exception 'Product must be CHC, ES, GWS, KEYPLC or MANIFOLD.';
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
    keyplc_rmb_multiplier=case when v_product='KEYPLC' and v_currency='RMB' then p_multiplier else s.keyplc_rmb_multiplier end,
    manifold_usd_multiplier=case when v_product='MANIFOLD' and v_currency='USD' then p_multiplier else s.manifold_usd_multiplier end,
    manifold_rmb_multiplier=case when v_product='MANIFOLD' and v_currency='RMB' then p_multiplier else s.manifold_rmb_multiplier end
  where s.id='default';
  if not found then raise exception 'KeySuite application settings were not found.'; end if;

  return query select v_product,
    case v_product when 'CHC' then s.chc_usd_multiplier when 'ES' then s.es_usd_multiplier when 'GWS' then s.gws_usd_multiplier when 'KEYPLC' then s.keyplc_usd_multiplier else s.manifold_usd_multiplier end,
    case v_product when 'CHC' then s.chc_rmb_multiplier when 'ES' then s.es_rmb_multiplier when 'GWS' then s.gws_rmb_multiplier when 'KEYPLC' then s.keyplc_rmb_multiplier else s.manifold_rmb_multiplier end
  from public.ks_app_settings s where s.id='default';
end;
$$;

-- ---------------------------------------------------------------------------
-- Save a complete Manifold table row. Blank prices remain JSON null and zero
-- remains a valid workbook value. Sizing rows are saved through the same RPC.
-- ---------------------------------------------------------------------------
create or replace function public.keysuite_save_manifold_product_v213(
  p_product_id text,p_variants jsonb,p_rarity text
)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_rarity text:=lower(trim(coalesce(p_rarity,'common')));
  v_section text;
  v_item jsonb;
  v_field text;
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then
    raise exception 'Your role is not allowed to maintain Manifold prices.';
  end if;
  if v_rarity not in ('common','many','rare') then raise exception 'Rarity is invalid.'; end if;
  if jsonb_typeof(coalesce(p_variants,'null'::jsonb))<>'array' then
    raise exception 'Manifold variants must be supplied as an array.';
  end if;

  select section into v_section from public.ks_products_manifold where id=p_product_id for update;
  if not found then raise exception 'Manifold product was not found.'; end if;

  for v_item in select value from jsonb_array_elements(p_variants) loop
    if jsonb_typeof(v_item)<>'object' then raise exception 'Every Manifold variant must be an object.'; end if;
    if v_section='sizing' then
      if coalesce(v_item->>'pumpQty','') !~ '^[1-6]$' then raise exception 'Sizing pump quantity must be from 1 to 6.'; end if;
      if coalesce(v_item->>'resultDn','') !~ '^DN[0-9]+$' then raise exception 'Sizing result must be a DN value.'; end if;
    else
      foreach v_field in array array['priceUsd','priceRmb','priceMyr'] loop
        if v_item ? v_field and v_item->v_field <> 'null'::jsonb and
           (jsonb_typeof(v_item->v_field)<>'number' or (v_item->>v_field)::numeric<0) then
          raise exception '% must be blank or zero and above.',v_field;
        end if;
      end loop;
    end if;
  end loop;

  update public.ks_products_manifold
  set variants=p_variants,rarity=v_rarity,updated_at=now()
  where id=p_product_id;

  return jsonb_build_object('product_id',p_product_id,'section',v_section,'rarity',v_rarity,'variants',p_variants);
end;
$$;

-- ---------------------------------------------------------------------------
-- Pricing Category editor now accepts MANIFOLD and creates a Manifold rule
-- for every new category.
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
  if v_product not in ('CHC','ES','GWS','KEYPLC','MANIFOLD') then raise exception 'Product must be CHC, ES, GWS, KEYPLC or MANIFOLD.'; end if;
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
        'KEYPLC',case when v_product='KEYPLC' then v_rule else v_defaults end,
        'MANIFOLD',case when v_product='MANIFOLD' then v_rule else v_defaults end
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
  '{MANIFOLD}',
  coalesce(product_rules->'MANIFOLD',jsonb_build_object(
    'margin',0,'normal',0,'rare',0,'transport',0,'commission',0,
    'set_discount',0,'final_discount',0,'include_commission',false,
    'include_set_discount',false,'include_final_discount',false,'include_fuel_charge',false
  )),true
);

revoke all on function public.keysuite_save_manifold_product_v213(text,jsonb,text) from public;
revoke all on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) from public;
revoke all on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
grant execute on function public.keysuite_save_manifold_product_v213(text,jsonb,text) to authenticated;
grant execute on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) to authenticated;
grant execute on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

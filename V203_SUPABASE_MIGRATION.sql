-- KeySuite V2.03
-- End Suction products, Assembly save fix, and ES price maintenance.
-- Run after V201_SUPABASE_MIGRATION.sql

begin;

create table if not exists public.ks_products_es (
  id text primary key,
  model text not null unique,
  source_row integer not null,
  variants jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.ks_products_es enable row level security;
revoke all on public.ks_products_es from anon,authenticated;

drop policy if exists ks_products_es_select on public.ks_products_es;
create policy ks_products_es_select on public.ks_products_es
for select to authenticated using (public.keysuite_has_access());

insert into public.ks_products_es(id,model,source_row,variants) values
('es-es-32-13','ES 32-13',5,'[{"material":"CI / BR / SS / MS","priceUsd":134.49},{"material":"CI / SS / SS / MS","priceUsd":134.49},{"material":"CI / CI / SS / MS","priceUsd":125.36},{"material":"CI / BR / SS / GP","priceUsd":184.49},{"material":"CI / SS / SS / GP","priceUsd":184.49},{"material":"CI / CI / SS / GP","priceUsd":175.36},{"material":"SS304","priceUsd":442.84},{"material":"SS316","priceUsd":537.1}]'::jsonb),
('es-es-32-16','ES 32-16',6,'[{"material":"CI / BR / SS / MS","priceUsd":148.57},{"material":"CI / SS / SS / MS","priceUsd":148.57},{"material":"CI / CI / SS / MS","priceUsd":134.07},{"material":"CI / BR / SS / GP","priceUsd":198.57},{"material":"CI / SS / SS / GP","priceUsd":198.57},{"material":"CI / CI / SS / GP","priceUsd":184.07},{"material":"SS304","priceUsd":484.1},{"material":"SS316","priceUsd":586.87}]'::jsonb),
('es-es-32-20','ES 32-20',7,'[{"material":"CI / BR / SS / MS","priceUsd":179.53},{"material":"CI / SS / SS / MS","priceUsd":179.53},{"material":"CI / CI / SS / MS","priceUsd":157.18},{"material":"CI / BR / SS / GP","priceUsd":229.53},{"material":"CI / SS / SS / GP","priceUsd":229.53},{"material":"CI / CI / SS / GP","priceUsd":207.18},{"material":"SS304","priceUsd":613.48},{"material":"SS316","priceUsd":757.58},{"material":"CI CI SS Dynamic","priceUsd":339.05}]'::jsonb),
('es-es-32-26','ES 32-26',8,'[{"material":"CI / BR / SS / MS","priceUsd":225.49},{"material":"CI / SS / SS / MS","priceUsd":225.49},{"material":"CI / CI / SS / MS","priceUsd":183.35},{"material":"CI / BR / SS / GP","priceUsd":275.49},{"material":"CI / SS / SS / GP","priceUsd":275.49},{"material":"CI / CI / SS / GP","priceUsd":233.35},{"material":"SS304","priceUsd":784.56},{"material":"SS316","priceUsd":976.29}]'::jsonb),
('es-es-40-13','ES 40-13',9,'[{"material":"CI / BR / SS / MS","priceUsd":141.1},{"material":"CI / SS / SS / MS","priceUsd":141.1},{"material":"CI / CI / SS / MS","priceUsd":130.37},{"material":"CI / BR / SS / GP","priceUsd":191.1},{"material":"CI / SS / SS / GP","priceUsd":191.1},{"material":"CI / CI / SS / GP","priceUsd":180.37},{"material":"SS304","priceUsd":478.14},{"material":"SS316","priceUsd":582.7}]'::jsonb),
('es-es-40-16','ES 40-16',10,'[{"material":"CI / BR / SS / MS","priceUsd":149.31},{"material":"CI / SS / SS / MS","priceUsd":149.31},{"material":"CI / CI / SS / MS","priceUsd":136.83},{"material":"CI / BR / SS / GP","priceUsd":199.31},{"material":"CI / SS / SS / GP","priceUsd":199.31},{"material":"CI / CI / SS / GP","priceUsd":186.83},{"material":"SS304","priceUsd":503.96},{"material":"SS316","priceUsd":612.33},{"material":"Duplex 2205","priceUsd":952.0}]'::jsonb),
('es-es-40-20','ES 40-20',11,'[{"material":"CI / BR / SS / MS","priceUsd":181.27},{"material":"CI / SS / SS / MS","priceUsd":181.27},{"material":"CI / CI / SS / MS","priceUsd":158.78},{"material":"CI / BR / SS / GP","priceUsd":231.27},{"material":"CI / SS / SS / GP","priceUsd":231.27},{"material":"CI / CI / SS / GP","priceUsd":208.78},{"material":"SS304","priceUsd":659.34},{"material":"SS316","priceUsd":816.74},{"material":"Duplex 2205","priceUsd":1270.0}]'::jsonb),
('es-es-40-26','ES 40-26',12,'[{"material":"CI / BR / SS / MS","priceUsd":227.17},{"material":"CI / SS / SS / MS","priceUsd":227.17},{"material":"CI / CI / SS / MS","priceUsd":187.07},{"material":"CI / BR / SS / GP","priceUsd":277.17},{"material":"CI / SS / SS / GP","priceUsd":277.17},{"material":"CI / CI / SS / GP","priceUsd":237.07},{"material":"SS304","priceUsd":794.15},{"material":"SS316","priceUsd":989.61}]'::jsonb),
('es-es-40-32','ES 40-32',13,'[{"material":"CI / BR / SS / MS","priceUsd":360.06},{"material":"CI / SS / SS / MS","priceUsd":360.06},{"material":"CI / CI / SS / MS","priceUsd":281.22},{"material":"CI / BR / SS / GP","priceUsd":410.06},{"material":"CI / SS / SS / GP","priceUsd":410.06},{"material":"CI / CI / SS / GP","priceUsd":331.22},{"material":"SS304","priceUsd":1167.3},{"material":"SS316","priceUsd":1396.56}]'::jsonb),
('es-es-40-32h','ES 40-32H',14,'[{"material":"CI / BR / SS / MS","priceUsd":413.71},{"material":"CI / SS / SS / MS","priceUsd":413.71},{"material":"CI / CI / SS / MS","priceUsd":331.27},{"material":"CI / BR / SS / GP","priceUsd":413.71},{"material":"CI / SS / SS / GP","priceUsd":413.71},{"material":"CI / CI / SS / GP","priceUsd":331.27}]'::jsonb),
('es-es-40-32g','ES 40-32G',15,'[{"material":"CI / BR / SS / MS","priceUsd":451.58},{"material":"CI / SS / SS / MS","priceUsd":451.58},{"material":"CI / CI / SS / MS","priceUsd":376.04},{"material":"CI / BR / SS / GP","priceUsd":451.58},{"material":"CI / SS / SS / GP","priceUsd":451.58},{"material":"CI / CI / SS / GP","priceUsd":376.04},{"material":"SS304","priceUsd":1457.79},{"material":"SS316","priceUsd":1812.16}]'::jsonb),
('es-es-50-13','ES 50-13',16,'[{"material":"CI / BR / SS / MS","priceUsd":145.78},{"material":"CI / SS / SS / MS","priceUsd":145.78},{"material":"CI / CI / SS / MS","priceUsd":133.28},{"material":"CI / BR / SS / GP","priceUsd":195.78},{"material":"CI / SS / SS / GP","priceUsd":195.78},{"material":"CI / CI / SS / GP","priceUsd":183.28},{"material":"SS304","priceUsd":491.74},{"material":"SS316","priceUsd":599.06}]'::jsonb),
('es-es-50-16','ES 50-16',17,'[{"material":"CI / BR / SS / MS","priceUsd":162.23},{"material":"CI / SS / SS / MS","priceUsd":162.23},{"material":"CI / CI / SS / MS","priceUsd":143.27},{"material":"CI / BR / SS / GP","priceUsd":212.23},{"material":"CI / SS / SS / GP","priceUsd":212.23},{"material":"CI / CI / SS / GP","priceUsd":193.27},{"material":"SS304","priceUsd":540.19},{"material":"SS316","priceUsd":661.86}]'::jsonb),
('es-es-50-20','ES 50-20',18,'[{"material":"CI / BR / SS / MS","priceUsd":191.7},{"material":"CI / SS / SS / MS","priceUsd":191.7},{"material":"CI / CI / SS / MS","priceUsd":163.82},{"material":"CI / BR / SS / GP","priceUsd":241.7},{"material":"CI / SS / SS / GP","priceUsd":241.7},{"material":"CI / CI / SS / GP","priceUsd":213.82},{"material":"SS304","priceUsd":665.25},{"material":"SS316","priceUsd":823.74},{"material":"CI CI SS Dynamic","priceUsd":345.69}]'::jsonb),
('es-es-50-26','ES 50-26',19,'[{"material":"CI / BR / SS / MS","priceUsd":231.4},{"material":"CI / SS / SS / MS","priceUsd":231.4},{"material":"CI / CI / SS / MS","priceUsd":188.81},{"material":"CI / BR / SS / GP","priceUsd":281.4},{"material":"CI / SS / SS / GP","priceUsd":281.4},{"material":"CI / CI / SS / GP","priceUsd":238.81},{"material":"SS304","priceUsd":835.52},{"material":"SS316","priceUsd":1041.94}]'::jsonb),
('es-es-50-26g','ES 50-26G',20,'[{"material":"CI / BR / SS / MS","priceUsd":296.49},{"material":"CI / SS / SS / MS","priceUsd":296.49},{"material":"CI / CI / SS / MS","priceUsd":250.58},{"material":"CI / BR / SS / GP","priceUsd":296.49},{"material":"CI / SS / SS / GP","priceUsd":296.49},{"material":"CI / CI / SS / GP","priceUsd":250.58},{"material":"SS304","priceUsd":919.08},{"material":"SS316","priceUsd":1146.13}]'::jsonb),
('es-es-50-32','ES 50-32',21,'[{"material":"CI / BR / SS / MS","priceUsd":367.23},{"material":"CI / SS / SS / MS","priceUsd":367.23},{"material":"CI / CI / SS / MS","priceUsd":287.07},{"material":"CI / BR / SS / GP","priceUsd":417.23},{"material":"CI / SS / SS / GP","priceUsd":417.23},{"material":"CI / CI / SS / GP","priceUsd":337.07},{"material":"SS304","priceUsd":1256.2},{"material":"SS316","priceUsd":1465.87}]'::jsonb),
('es-es-50-32h','ES 50-32H',22,'[{"material":"CI / BR / SS / MS","priceUsd":423.04},{"material":"CI / SS / SS / MS","priceUsd":423.04},{"material":"CI / CI / SS / MS","priceUsd":339.19},{"material":"CI / BR / SS / GP","priceUsd":423.04},{"material":"CI / SS / SS / GP","priceUsd":423.04},{"material":"CI / CI / SS / GP","priceUsd":339.19}]'::jsonb),
('es-es-50-32g','ES 50-32G',23,'[{"material":"CI / BR / SS / MS","priceUsd":460.55},{"material":"CI / SS / SS / MS","priceUsd":460.55},{"material":"CI / CI / SS / MS","priceUsd":383.78},{"material":"CI / BR / SS / GP","priceUsd":460.55},{"material":"CI / SS / SS / GP","priceUsd":460.55},{"material":"CI / CI / SS / GP","priceUsd":383.78},{"material":"SS304","priceUsd":1519.72},{"material":"SS316","priceUsd":1889.13}]'::jsonb),
('es-es-65-13','ES 65-13',24,'[{"material":"CI / BR / SS / MS","priceUsd":158.55},{"material":"CI / SS / SS / MS","priceUsd":158.55},{"material":"CI / CI / SS / MS","priceUsd":146.96},{"material":"CI / BR / SS / GP","priceUsd":208.55},{"material":"CI / SS / SS / GP","priceUsd":208.55},{"material":"CI / CI / SS / GP","priceUsd":196.96},{"material":"SS304","priceUsd":551.68},{"material":"SS316","priceUsd":675.25}]'::jsonb),
('es-es-65-16','ES 65-16',25,'[{"material":"CI / BR / SS / MS","priceUsd":169.59},{"material":"CI / SS / SS / MS","priceUsd":169.59},{"material":"CI / CI / SS / MS","priceUsd":152.05},{"material":"CI / BR / SS / GP","priceUsd":219.59},{"material":"CI / SS / SS / GP","priceUsd":219.59},{"material":"CI / CI / SS / GP","priceUsd":202.05},{"material":"SS304","priceUsd":639.51},{"material":"SS316","priceUsd":790.34}]'::jsonb),
('es-es-65-20','ES 65-20',26,'[{"material":"CI / BR / SS / MS","priceUsd":200.18},{"material":"CI / SS / SS / MS","priceUsd":200.18},{"material":"CI / CI / SS / MS","priceUsd":172.55},{"material":"CI / BR / SS / GP","priceUsd":250.18},{"material":"CI / SS / SS / GP","priceUsd":250.18},{"material":"CI / CI / SS / GP","priceUsd":222.55},{"material":"SS304","priceUsd":735.81},{"material":"SS316","priceUsd":914.55}]'::jsonb),
('es-es-65-20g','ES 65-20G',27,'[{"material":"CI / BR / SS / MS","priceUsd":252.1},{"material":"CI / SS / SS / MS","priceUsd":252.1},{"material":"CI / CI / SS / MS","priceUsd":227.89},{"material":"CI / BR / SS / GP","priceUsd":252.1},{"material":"CI / SS / SS / GP","priceUsd":252.1},{"material":"CI / CI / SS / GP","priceUsd":227.89},{"material":"SS304","priceUsd":809.4},{"material":"SS316","priceUsd":1006.0}]'::jsonb),
('es-es-65-26','ES 65-26',28,'[{"material":"CI / BR / SS / MS","priceUsd":306.12},{"material":"CI / SS / SS / MS","priceUsd":306.12},{"material":"CI / CI / SS / MS","priceUsd":261.48},{"material":"CI / BR / SS / GP","priceUsd":356.12},{"material":"CI / SS / SS / GP","priceUsd":356.12},{"material":"CI / CI / SS / GP","priceUsd":311.48},{"material":"SS304","priceUsd":1118.81},{"material":"SS316","priceUsd":1258.68}]'::jsonb),
('es-es-65-32','ES 65-32',29,'[{"material":"CI / BR / SS / MS","priceUsd":404.93},{"material":"CI / SS / SS / MS","priceUsd":404.93},{"material":"CI / CI / SS / MS","priceUsd":318.83},{"material":"CI / BR / SS / GP","priceUsd":454.93},{"material":"CI / SS / SS / GP","priceUsd":454.93},{"material":"CI / CI / SS / GP","priceUsd":368.83},{"material":"SS304","priceUsd":1382.65},{"material":"SS316","priceUsd":1738.58}]'::jsonb),
('es-es-65-32h','ES 65-32H',30,'[{"material":"CI / BR / SS / MS","priceUsd":460.69},{"material":"CI / SS / SS / MS","priceUsd":460.69},{"material":"CI / CI / SS / MS","priceUsd":367.56},{"material":"CI / BR / SS / GP","priceUsd":460.69},{"material":"CI / SS / SS / GP","priceUsd":460.69},{"material":"CI / CI / SS / GP","priceUsd":367.56}]'::jsonb),
('es-es-65-32g','ES 65-32G',31,'[{"material":"CI / BR / SS / MS","priceUsd":503.28},{"material":"CI / SS / SS / MS","priceUsd":503.28},{"material":"CI / CI / SS / MS","priceUsd":410.08},{"material":"CI / BR / SS / GP","priceUsd":503.28},{"material":"CI / SS / SS / GP","priceUsd":503.28},{"material":"CI / CI / SS / GP","priceUsd":410.08},{"material":"SS304","priceUsd":1534.28},{"material":"SS316","priceUsd":1893.86}]'::jsonb),
('es-es-80-16','ES 80-16',32,'[{"material":"CI / BR / SS / MS","priceUsd":198.61},{"material":"CI / SS / SS / MS","priceUsd":198.61},{"material":"CI / CI / SS / MS","priceUsd":170.22},{"material":"CI / BR / SS / GP","priceUsd":248.61},{"material":"CI / SS / SS / GP","priceUsd":248.61},{"material":"CI / CI / SS / GP","priceUsd":220.22},{"material":"SS304","priceUsd":779.47},{"material":"SS316","priceUsd":965.26}]'::jsonb),
('es-es-80-20','ES 80-20',33,'[{"material":"CI / BR / SS / MS","priceUsd":268.0},{"material":"CI / SS / SS / MS","priceUsd":268.0},{"material":"CI / CI / SS / MS","priceUsd":236.95},{"material":"CI / BR / SS / GP","priceUsd":318.0},{"material":"CI / SS / SS / GP","priceUsd":318.0},{"material":"CI / CI / SS / GP","priceUsd":286.95},{"material":"SS304","priceUsd":1015.28},{"material":"SS316","priceUsd":1272.19}]'::jsonb),
('es-es-80-26','ES 80-26',34,'[{"material":"CI / BR / SS / MS","priceUsd":324.67},{"material":"CI / SS / SS / MS","priceUsd":324.67},{"material":"CI / CI / SS / MS","priceUsd":281.84},{"material":"CI / BR / SS / GP","priceUsd":374.67},{"material":"CI / SS / SS / GP","priceUsd":374.67},{"material":"CI / CI / SS / GP","priceUsd":331.84},{"material":"SS304","priceUsd":1220.01},{"material":"SS316","priceUsd":1533.17}]'::jsonb),
('es-es-80-32','ES 80-32',35,'[{"material":"CI / BR / SS / MS","priceUsd":411.14},{"material":"CI / SS / SS / MS","priceUsd":411.14},{"material":"CI / CI / SS / MS","priceUsd":349.55},{"material":"CI / BR / SS / GP","priceUsd":461.14},{"material":"CI / SS / SS / GP","priceUsd":461.14},{"material":"CI / CI / SS / GP","priceUsd":399.55},{"material":"SS304","priceUsd":1545.13},{"material":"SS316","priceUsd":1943.2}]'::jsonb),
('es-es-80-32h','ES 80-32H',36,'[{"material":"CI / BR / SS / MS","priceUsd":471.04},{"material":"CI / SS / SS / MS","priceUsd":471.04},{"material":"CI / CI / SS / MS","priceUsd":392.22},{"material":"CI / BR / SS / GP","priceUsd":471.04},{"material":"CI / SS / SS / GP","priceUsd":471.04},{"material":"CI / CI / SS / GP","priceUsd":392.22}]'::jsonb),
('es-es-80-32g','ES 80-32G',37,'[{"material":"CI / BR / SS / MS","priceUsd":512.93},{"material":"CI / SS / SS / MS","priceUsd":512.93},{"material":"CI / CI / SS / MS","priceUsd":425.35},{"material":"CI / BR / SS / GP","priceUsd":512.93},{"material":"CI / SS / SS / GP","priceUsd":512.93},{"material":"CI / CI / SS / GP","priceUsd":425.35},{"material":"SS304","priceUsd":1787.17},{"material":"SS316","priceUsd":2205.77}]'::jsonb),
('es-es-80-40','ES 80-40',38,'[{"material":"CI / BR / SS / MS","priceUsd":592.43},{"material":"CI / SS / SS / MS","priceUsd":592.43},{"material":"CI / CI / SS / MS","priceUsd":493.14},{"material":"CI / BR / SS / GP","priceUsd":692.43},{"material":"CI / SS / SS / GP","priceUsd":692.43},{"material":"CI / CI / SS / GP","priceUsd":593.14},{"material":"SS304","priceUsd":2088.96},{"material":"SS316","priceUsd":2644.09}]'::jsonb),
('es-es-100-16','ES 100-16',39,'[{"material":"CI / BR / SS / MS","priceUsd":296.94},{"material":"CI / SS / SS / MS","priceUsd":296.94},{"material":"CI / CI / SS / MS","priceUsd":260.93},{"material":"CI / BR / SS / GP","priceUsd":346.94},{"material":"CI / SS / SS / GP","priceUsd":346.94},{"material":"CI / CI / SS / GP","priceUsd":310.93},{"material":"SS304","priceUsd":1156.5},{"material":"SS316","priceUsd":1393.2}]'::jsonb),
('es-es-100-20','ES 100-20',40,'[{"material":"CI / BR / SS / MS","priceUsd":298.74},{"material":"CI / SS / SS / MS","priceUsd":298.74},{"material":"CI / CI / SS / MS","priceUsd":273.98},{"material":"CI / BR / SS / GP","priceUsd":348.74},{"material":"CI / SS / SS / GP","priceUsd":348.74},{"material":"CI / CI / SS / GP","priceUsd":323.98},{"material":"SS304","priceUsd":1168.42},{"material":"SS316","priceUsd":1409.65}]'::jsonb),
('es-es-100-26','ES 100-26',41,'[{"material":"CI / BR / SS / MS","priceUsd":353.85},{"material":"CI / SS / SS / MS","priceUsd":353.85},{"material":"CI / CI / SS / MS","priceUsd":308.39},{"material":"CI / BR / SS / GP","priceUsd":403.85},{"material":"CI / SS / SS / GP","priceUsd":403.85},{"material":"CI / CI / SS / GP","priceUsd":358.39},{"material":"SS304","priceUsd":1439.77},{"material":"SS316","priceUsd":1813.37}]'::jsonb),
('es-es-100-26h','ES 100-26H',42,'[{"material":"CI / BR / SS / MS","priceUsd":413.5},{"material":"CI / SS / SS / MS","priceUsd":413.5},{"material":"CI / CI / SS / MS","priceUsd":368.39},{"material":"CI / BR / SS / GP","priceUsd":413.5},{"material":"CI / SS / SS / GP","priceUsd":413.5},{"material":"CI / CI / SS / GP","priceUsd":368.39}]'::jsonb),
('es-es-100-26g','ES 100-26G',43,'[{"material":"CI / BR / SS / MS","priceUsd":470.7},{"material":"CI / SS / SS / MS","priceUsd":470.7},{"material":"CI / CI / SS / MS","priceUsd":431.73},{"material":"CI / BR / SS / GP","priceUsd":470.7},{"material":"CI / SS / SS / GP","priceUsd":470.7},{"material":"CI / CI / SS / GP","priceUsd":431.73},{"material":"SS304","priceUsd":1583.74},{"material":"SS316","priceUsd":1994.71}]'::jsonb),
('es-es-100-32','ES 100-32',44,'[{"material":"CI / BR / SS / MS","priceUsd":432.55},{"material":"CI / SS / SS / MS","priceUsd":432.55},{"material":"CI / CI / SS / MS","priceUsd":361.51},{"material":"CI / BR / SS / GP","priceUsd":482.55},{"material":"CI / SS / SS / GP","priceUsd":482.55},{"material":"CI / CI / SS / GP","priceUsd":411.51},{"material":"SS304","priceUsd":1680.09},{"material":"SS316","priceUsd":2114.25}]'::jsonb),
('es-es-100-32g','ES 100-32G',45,'[{"material":"CI / BR / SS / MS","priceUsd":627.2},{"material":"CI / SS / SS / MS","priceUsd":627.2},{"material":"CI / CI / SS / MS","priceUsd":473.68},{"material":"CI / BR / SS / GP","priceUsd":627.2},{"material":"CI / SS / SS / GP","priceUsd":627.2},{"material":"CI / CI / SS / GP","priceUsd":473.68},{"material":"SS304","priceUsd":1932.11},{"material":"SS316","priceUsd":2431.38}]'::jsonb),
('es-es-100-40','ES 100-40',46,'[{"material":"CI / BR / SS / MS","priceUsd":628.27},{"material":"CI / SS / SS / MS","priceUsd":628.27},{"material":"CI / CI / SS / MS","priceUsd":513.14},{"material":"CI / BR / SS / GP","priceUsd":728.27},{"material":"CI / SS / SS / GP","priceUsd":728.27},{"material":"CI / CI / SS / GP","priceUsd":613.14},{"material":"SS304","priceUsd":2267.0},{"material":"SS316","priceUsd":2871.78}]'::jsonb),
('es-es-125-20','ES 125-20',47,'[{"material":"CI / BR / SS / MS","priceUsd":353.61},{"material":"CI / SS / SS / MS","priceUsd":353.61},{"material":"CI / CI / SS / MS","priceUsd":312.89},{"material":"CI / BR / SS / GP","priceUsd":403.61},{"material":"CI / SS / SS / GP","priceUsd":403.61},{"material":"CI / CI / SS / GP","priceUsd":362.89},{"material":"SS304","priceUsd":1412.03},{"material":"SS316","priceUsd":1765.04}]'::jsonb),
('es-es-125-26','ES 125-26',48,'[{"material":"CI / BR / SS / MS","priceUsd":397.03},{"material":"CI / SS / SS / MS","priceUsd":397.03},{"material":"CI / CI / SS / MS","priceUsd":341.22},{"material":"CI / BR / SS / GP","priceUsd":447.03},{"material":"CI / SS / SS / GP","priceUsd":447.03},{"material":"CI / CI / SS / GP","priceUsd":391.22},{"material":"SS304","priceUsd":1621.37},{"material":"SS316","priceUsd":2040.78}]'::jsonb),
('es-es-125-26g','ES 125-26G',49,'[{"material":"CI / BR / SS / MS","priceUsd":617.4},{"material":"CI / SS / SS / MS","priceUsd":617.4},{"material":"CI / CI / SS / MS","priceUsd":470.7},{"material":"CI / BR / SS / GP","priceUsd":617.4},{"material":"CI / SS / SS / GP","priceUsd":617.4},{"material":"CI / CI / SS / GP","priceUsd":470.7}]'::jsonb),
('es-es-125-32','ES 125-32',50,'[{"material":"CI / BR / SS / MS","priceUsd":544.47},{"material":"CI / SS / SS / MS","priceUsd":544.47},{"material":"CI / CI / SS / MS","priceUsd":464.99},{"material":"CI / BR / SS / GP","priceUsd":644.47},{"material":"CI / SS / SS / GP","priceUsd":644.47},{"material":"CI / CI / SS / GP","priceUsd":564.99},{"material":"SS304","priceUsd":2096.53},{"material":"SS316","priceUsd":2643.36}]'::jsonb),
('es-es-125-40','ES 125-40',51,'[{"material":"CI / BR / SS / MS","priceUsd":641.54},{"material":"CI / SS / SS / MS","priceUsd":641.54},{"material":"CI / CI / SS / MS","priceUsd":539.71},{"material":"CI / BR / SS / GP","priceUsd":741.54},{"material":"CI / SS / SS / GP","priceUsd":741.54},{"material":"CI / CI / SS / GP","priceUsd":639.71},{"material":"SS304","priceUsd":2553.61},{"material":"SS316","priceUsd":3215.3}]'::jsonb),
('es-es-150-20','ES 150-20',52,'[{"material":"CI / BR / SS / MS","priceUsd":441.74},{"material":"CI / SS / SS / MS","priceUsd":441.74},{"material":"CI / CI / SS / MS","priceUsd":377.21},{"material":"CI / BR / SS / GP","priceUsd":491.74},{"material":"CI / SS / SS / GP","priceUsd":491.74},{"material":"CI / CI / SS / GP","priceUsd":427.21},{"material":"SS304","priceUsd":1763.93},{"material":"SS316","priceUsd":2249.0}]'::jsonb),
('es-es-150-26','ES 150-26',53,'[{"material":"CI / BR / SS / MS","priceUsd":532.73},{"material":"CI / SS / SS / MS","priceUsd":532.73},{"material":"CI / CI / SS / MS","priceUsd":449.55},{"material":"CI / BR / SS / GP","priceUsd":632.73},{"material":"CI / SS / SS / GP","priceUsd":632.73},{"material":"CI / CI / SS / GP","priceUsd":549.55},{"material":"SS304","priceUsd":2046.22},{"material":"SS316","priceUsd":2589.97}]'::jsonb),
('es-es-150-32','ES 150-32',54,'[{"material":"CI / BR / SS / MS","priceUsd":581.38},{"material":"CI / SS / SS / MS","priceUsd":581.38},{"material":"CI / CI / SS / MS","priceUsd":518.95},{"material":"CI / BR / SS / GP","priceUsd":681.38},{"material":"CI / SS / SS / GP","priceUsd":681.38},{"material":"CI / CI / SS / GP","priceUsd":618.95},{"material":"SS304","priceUsd":2378.95},{"material":"SS316","priceUsd":3004.4}]'::jsonb),
('es-es-150-40','ES 150-40',55,'[{"material":"CI / BR / SS / MS","priceUsd":719.16},{"material":"CI / SS / SS / MS","priceUsd":719.16},{"material":"CI / CI / SS / MS","priceUsd":603.18},{"material":"CI / BR / SS / GP","priceUsd":819.16},{"material":"CI / SS / SS / GP","priceUsd":819.16},{"material":"CI / CI / SS / GP","priceUsd":703.18},{"material":"SS304","priceUsd":2898.87},{"material":"SS316","priceUsd":3658.87}]'::jsonb),
('es-es-200-26','ES 200-26',56,'[{"material":"CI / BR / SS / MS","priceUsd":806.08},{"material":"CI / SS / SS / MS","priceUsd":806.08},{"material":"CI / CI / SS / MS","priceUsd":679.37},{"material":"CI / BR / SS / GP","priceUsd":906.08},{"material":"CI / SS / SS / GP","priceUsd":906.08},{"material":"CI / CI / SS / GP","priceUsd":779.37},{"material":"SS304","priceUsd":3243.95},{"material":"SS316","priceUsd":3888.84}]'::jsonb),
('es-es-200-32','ES 200-32',57,'[{"material":"CI / BR / SS / MS","priceUsd":1093.58},{"material":"CI / SS / SS / MS","priceUsd":1093.58},{"material":"CI / CI / SS / MS","priceUsd":872.38},{"material":"CI / BR / SS / GP","priceUsd":1243.58},{"material":"CI / SS / SS / GP","priceUsd":1243.58},{"material":"CI / CI / SS / GP","priceUsd":1022.38},{"material":"SS304","priceUsd":3607.91},{"material":"SS316","priceUsd":4200.97}]'::jsonb),
('es-es-200-40','ES 200-40',58,'[{"material":"CI / BR / SS / MS","priceUsd":1265.55},{"material":"CI / SS / SS / MS","priceUsd":1265.55},{"material":"CI / CI / SS / MS","priceUsd":958.55},{"material":"CI / BR / SS / GP","priceUsd":1415.55},{"material":"CI / SS / SS / GP","priceUsd":1415.55},{"material":"CI / CI / SS / GP","priceUsd":1108.55},{"material":"SS304","priceUsd":4430.55},{"material":"SS316","priceUsd":5280.96}]'::jsonb),
('es-es-250-32','ES 250-32',59,'[{"material":"CI / BR / SS / MS","priceUsd":1260.56},{"material":"CI / SS / SS / MS","priceUsd":1260.56},{"material":"CI / CI / SS / MS","priceUsd":1065.31},{"material":"CI / BR / SS / GP","priceUsd":1410.56},{"material":"CI / SS / SS / GP","priceUsd":1410.56},{"material":"CI / CI / SS / GP","priceUsd":1215.31},{"material":"SS304","priceUsd":4677.32},{"material":"SS316","priceUsd":5581.19}]'::jsonb),
('es-es-250-40','ES 250-40',60,'[{"material":"CI / BR / SS / MS","priceUsd":1462.71},{"material":"CI / SS / SS / MS","priceUsd":1462.71},{"material":"CI / CI / SS / MS","priceUsd":1150.6},{"material":"CI / BR / SS / GP","priceUsd":1612.71},{"material":"CI / SS / SS / GP","priceUsd":1612.71},{"material":"CI / CI / SS / GP","priceUsd":1300.6},{"material":"SS304","priceUsd":5142.4},{"material":"SS316","priceUsd":6137.83},{"material":"CI CI SS Dynamic","priceUsd":1592.0}]'::jsonb)
on conflict(id) do update set
  model=excluded.model,
  source_row=excluded.source_row,
  variants=excluded.variants,
  updated_at=now();

create or replace function public.keysuite_save_es_price_v203(
  p_product_id text,p_material text,p_price_usd numeric
)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare v_variants jsonb; v_result jsonb;
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then raise exception 'Your role is not allowed to maintain ES prices.'; end if;
  if p_price_usd is null or p_price_usd<0 then raise exception 'Price cannot be negative.'; end if;
  select variants into v_variants from public.ks_products_es where id=p_product_id for update;
  if not found then raise exception 'ES product was not found.'; end if;
  select jsonb_agg(case when x->>'material'=p_material then jsonb_set(x,'{priceUsd}',to_jsonb(p_price_usd),true) else x end)
  into v_result from jsonb_array_elements(v_variants) x;
  if not exists(select 1 from jsonb_array_elements(v_variants) x where x->>'material'=p_material) then raise exception 'ES material variant was not found.'; end if;
  update public.ks_products_es set variants=v_result,updated_at=now() where id=p_product_id;
  return v_result;
end;
$$;

grant execute on function public.keysuite_save_es_price_v203(text,text,numeric) to authenticated;

create or replace function public.keysuite_save_assembly_v201(p_assembly jsonb)
returns table (
  id text, assembly_type text, name text, model_item text, description text,
  customer_id text, status text, created_by_email text, assigned_user_email text,
  created_at timestamptz, updated_at timestamptz, items jsonb
)
language plpgsql security definer set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id(); v_actor text:=public.keysuite_current_email();
  v_id text:=nullif(trim(p_assembly->>'id'),''); v_type text:=lower(coalesce(nullif(trim(p_assembly->>'assembly_type'),''),'system'));
  v_model_item text:=coalesce(p_assembly->>'model_item',''); v_description text:=coalesce(p_assembly->>'description','');
  v_name text:=coalesce(nullif(trim(p_assembly->>'name'),''),case when v_type='pumpset' then 'New Pumpset' else 'New System' end);
  v_customer text:=nullif(trim(p_assembly->>'customer_id'),''); v_status text:=lower(coalesce(nullif(trim(p_assembly->>'status'),''),'draft'));
  v_item jsonb; v_section text; v_line integer:=0;
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then raise exception 'Your role is not allowed to create or edit assemblies.'; end if;
  if coalesce(v_company,'')='' then raise exception 'Your account has no company assignment.'; end if;
  if v_id is null then raise exception 'Assembly ID is required.'; end if;
  if v_type not in ('system','pumpset') then raise exception 'Invalid assembly type.'; end if;
  if v_status not in ('draft','ready','quoted') then raise exception 'Invalid assembly status.'; end if;

  insert into public.ks_assemblies(id,company_id,assembly_type,name,model_item,description,customer_id,status,created_by_email,assigned_user_email,created_at,updated_at)
  values(v_id,v_company,v_type,v_name,v_model_item,v_description,v_customer,v_status,v_actor,v_actor,now(),now())
  on conflict on constraint ks_assemblies_pkey do update set
    assembly_type=excluded.assembly_type,name=excluded.name,model_item=excluded.model_item,description=excluded.description,
    customer_id=excluded.customer_id,status=excluded.status,updated_at=now()
  where public.ks_assemblies.company_id=v_company;

  if not found then raise exception 'Assembly was not found in your company.'; end if;
  delete from public.ks_assembly_items ai where ai.assembly_id=v_id;
  for v_item in select value from jsonb_array_elements(coalesce(p_assembly->'items','[]'::jsonb)) loop
    v_line:=v_line+1;
    v_section:=lower(coalesce(nullif(trim(v_item->>'section'),''),case when v_type='pumpset' then 'pump' else 'misc' end));
    if v_section not in ('pump','motor','coupling','baseplate','pumpset','control_panel','manifold','tank','misc') then v_section:=case when v_type='pumpset' then 'pump' else 'misc' end; end if;
    insert into public.ks_assembly_items(id,assembly_id,line_no,item_section,model,description,quantity,unit_price,pricing_source,pump_data)
    values(coalesce(nullif(trim(v_item->>'id'),''),v_id||'-'||v_line::text),v_id,v_line,v_section,
      coalesce(nullif(trim(v_item->>'model'),''),'Product'),coalesce(v_item->>'description',''),
      greatest(0,coalesce((v_item->>'qty')::numeric,1)),greatest(0,coalesce((v_item->>'unitPrice')::numeric,0)),
      v_item->'pricingSource',v_item->'pumpData');
  end loop;
  return query select * from public.keysuite_list_assemblies_v201() x where x.id=v_id;
end;
$$;

notify pgrst,'reload schema';
commit;

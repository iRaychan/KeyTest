-- KeySuite V2.31
-- Customer default quotation template
-- Run after the existing V2.30 / V2.18 quotation-template migrations.

begin;

alter table public.ks_customers
  add column if not exists default_quotation_template_id text;

create index if not exists ks_customers_default_quotation_template_v231_idx
  on public.ks_customers(company_id, default_quotation_template_id)
  where default_quotation_template_id is not null;

comment on column public.ks_customers.default_quotation_template_id is
  'Default active company quotation template selected for new quotations for this customer. Saved quotations retain their own template id and snapshot.';

commit;

select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema='public'
  and table_name='ks_customers'
  and column_name='default_quotation_template_id';

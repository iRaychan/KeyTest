-- KeySuite V1.11
-- Link each customer/company to a pricing category.
-- Run once in Supabase SQL Editor before uploading/testing V1.11.

-- 1) Customer pricing category ------------------------------------------------
alter table public.ks_customers
  add column if not exists pricing_category_id text;

-- Add the foreign key only when it is not already present.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'ks_customers_pricing_category_id_fkey'
      and conrelid = 'public.ks_customers'::regclass
  ) then
    alter table public.ks_customers
      add constraint ks_customers_pricing_category_id_fkey
      foreign key (pricing_category_id)
      references public.ks_pricing_categories(id);
  end if;
end;
$$;

create index if not exists ks_customers_pricing_category_idx
  on public.ks_customers(pricing_category_id);

-- Match existing customer records to the pricing category already assigned to
-- the user's company master (for example Keylargo -> Special).
update public.ks_customers customer
set pricing_category_id = category.id
from public.ks_companies company,
     public.ks_pricing_categories category
where customer.company_id = company.id
  and customer.pricing_category_id is null
  and lower(trim(category.category_name)) = lower(trim(company.pricing_category));

-- When the database currently has only one pricing category, use it for older
-- customer records that existed before V1.11. New customers remain unassigned
-- until Owner/Admin confirms the category in Key.
update public.ks_customers customer
set pricing_category_id = only_category.id
from (
  select min(id) as id
  from public.ks_pricing_categories
  having count(*) = 1
) only_category
where customer.pricing_category_id is null;

-- Normal users may edit their own customer contact records but cannot assign or
-- change the pricing category. Owner/Admin controls this field in Key.
create or replace function public.keysuite_protect_customer_pricing_category()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.keysuite_is_admin() then
    if tg_op = 'INSERT' then
      new.pricing_category_id := null;
    elsif new.pricing_category_id is distinct from old.pricing_category_id then
      raise exception 'Only Owner or Admin can assign a customer pricing category.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.keysuite_protect_customer_pricing_category() from public;

drop trigger if exists keysuite_customer_pricing_category_insert_guard on public.ks_customers;
create trigger keysuite_customer_pricing_category_insert_guard
before insert on public.ks_customers
for each row execute function public.keysuite_protect_customer_pricing_category();

drop trigger if exists keysuite_customer_pricing_category_update_guard on public.ks_customers;
create trigger keysuite_customer_pricing_category_update_guard
before update of pricing_category_id on public.ks_customers
for each row execute function public.keysuite_protect_customer_pricing_category();

-- Refresh Supabase/PostgREST schema cache.
notify pgrst, 'reload schema';

select
  count(*) as customer_records,
  count(pricing_category_id) as customers_with_pricing_category,
  count(*) - count(pricing_category_id) as customers_without_pricing_category
from public.ks_customers
where status = 'active';

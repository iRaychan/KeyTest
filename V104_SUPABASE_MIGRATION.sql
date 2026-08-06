-- KeySuite V1.04
-- Secure customer ownership + per-user quotation signature profile.
-- Run once in Supabase SQL Editor before testing Customers or Settings.

create extension if not exists pgcrypto;

-- Re-create the access helper so this migration also works if the earlier
-- secure-login SQL was only partially installed.
create or replace function public.keysuite_has_access()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.ks_user_access a
    where a.active = true
      and lower(a.email) = lower(coalesce(auth.jwt() ->> 'email',''))
  );
$$;

create or replace function public.keysuite_current_email()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select lower(coalesce(auth.jwt() ->> 'email',''));
$$;

create or replace function public.keysuite_current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select lower(a.role)
    from public.ks_user_access a
    where a.active = true
      and lower(a.email) = lower(coalesce(auth.jwt() ->> 'email',''))
    limit 1
  ),'');
$$;

create or replace function public.keysuite_current_company_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select a.company_id
    from public.ks_user_access a
    where a.active = true
      and lower(a.email) = lower(coalesce(auth.jwt() ->> 'email',''))
    limit 1
  ),'');
$$;

create or replace function public.keysuite_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.keysuite_current_role() in ('owner','admin');
$$;

create or replace function public.keysuite_user_in_current_company(target_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.ks_user_access a
    where a.active = true
      and lower(a.email) = lower(target_email)
      and a.company_id = public.keysuite_current_company_id()
  );
$$;

revoke all on function public.keysuite_has_access() from public;
revoke all on function public.keysuite_current_email() from public;
revoke all on function public.keysuite_current_role() from public;
revoke all on function public.keysuite_current_company_id() from public;
revoke all on function public.keysuite_is_admin() from public;
revoke all on function public.keysuite_user_in_current_company(text) from public;
grant execute on function public.keysuite_has_access() to authenticated;
grant execute on function public.keysuite_current_email() to authenticated;
grant execute on function public.keysuite_current_role() to authenticated;
grant execute on function public.keysuite_current_company_id() to authenticated;
grant execute on function public.keysuite_is_admin() to authenticated;
grant execute on function public.keysuite_user_in_current_company(text) to authenticated;

-- Customers -----------------------------------------------------------------
create table if not exists public.ks_customers (
  id uuid primary key default gen_random_uuid(),
  company_id text not null references public.ks_companies(id),
  company_name text not null,
  classification text not null default 'Other',
  assigned_user_email text not null,
  created_by_email text not null,
  company_phone text,
  address text,
  payment_terms text,
  tin_number text,
  business_registration_no text,
  sst_number text,
  msic_code text,
  business_activity text,
  notes text,
  contacts jsonb not null default '[]'::jsonb,
  status text not null default 'active' check (status in ('active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.ks_customers add column if not exists company_id text references public.ks_companies(id);
alter table public.ks_customers add column if not exists company_name text;
alter table public.ks_customers add column if not exists classification text default 'Other';
alter table public.ks_customers add column if not exists assigned_user_email text;
alter table public.ks_customers add column if not exists created_by_email text;
alter table public.ks_customers add column if not exists company_phone text;
alter table public.ks_customers add column if not exists address text;
alter table public.ks_customers add column if not exists payment_terms text;
alter table public.ks_customers add column if not exists tin_number text;
alter table public.ks_customers add column if not exists business_registration_no text;
alter table public.ks_customers add column if not exists sst_number text;
alter table public.ks_customers add column if not exists msic_code text;
alter table public.ks_customers add column if not exists business_activity text;
alter table public.ks_customers add column if not exists notes text;
alter table public.ks_customers add column if not exists contacts jsonb default '[]'::jsonb;
alter table public.ks_customers add column if not exists status text default 'active';
alter table public.ks_customers add column if not exists created_at timestamptz default now();
alter table public.ks_customers add column if not exists updated_at timestamptz default now();

create index if not exists ks_customers_company_idx on public.ks_customers(company_id);
create index if not exists ks_customers_owner_idx on public.ks_customers(lower(assigned_user_email));
create index if not exists ks_customers_name_idx on public.ks_customers(lower(company_name));

alter table public.ks_customers enable row level security;

drop policy if exists keysuite_customers_select on public.ks_customers;
create policy keysuite_customers_select
on public.ks_customers for select
to authenticated
using (
  public.keysuite_has_access()
  and company_id = public.keysuite_current_company_id()
  and (
    public.keysuite_is_admin()
    or lower(assigned_user_email) = public.keysuite_current_email()
  )
);

drop policy if exists keysuite_customers_insert on public.ks_customers;
create policy keysuite_customers_insert
on public.ks_customers for insert
to authenticated
with check (
  public.keysuite_has_access()
  and company_id = public.keysuite_current_company_id()
  and lower(created_by_email) = public.keysuite_current_email()
  and (
    (public.keysuite_is_admin() and public.keysuite_user_in_current_company(assigned_user_email))
    or lower(assigned_user_email) = public.keysuite_current_email()
  )
);

drop policy if exists keysuite_customers_update on public.ks_customers;
create policy keysuite_customers_update
on public.ks_customers for update
to authenticated
using (
  public.keysuite_has_access()
  and company_id = public.keysuite_current_company_id()
  and (
    public.keysuite_is_admin()
    or lower(assigned_user_email) = public.keysuite_current_email()
  )
)
with check (
  company_id = public.keysuite_current_company_id()
  and (
    (public.keysuite_is_admin() and public.keysuite_user_in_current_company(assigned_user_email))
    or lower(assigned_user_email) = public.keysuite_current_email()
  )
);

revoke all on table public.ks_customers from anon;
revoke all on table public.ks_customers from authenticated;
grant select,insert,update on table public.ks_customers to authenticated;

-- User settings and signature ------------------------------------------------
create table if not exists public.ks_user_profiles (
  email text primary key,
  company_id text not null references public.ks_companies(id),
  display_name text not null,
  designation text,
  phone text,
  signatory_name text,
  signature_image text,
  updated_at timestamptz not null default now()
);

alter table public.ks_user_profiles add column if not exists company_id text references public.ks_companies(id);
alter table public.ks_user_profiles add column if not exists display_name text;
alter table public.ks_user_profiles add column if not exists designation text;
alter table public.ks_user_profiles add column if not exists phone text;
alter table public.ks_user_profiles add column if not exists signatory_name text;
alter table public.ks_user_profiles add column if not exists signature_image text;
alter table public.ks_user_profiles add column if not exists updated_at timestamptz default now();

alter table public.ks_user_profiles enable row level security;

drop policy if exists keysuite_profiles_select_own on public.ks_user_profiles;
create policy keysuite_profiles_select_own
on public.ks_user_profiles for select
to authenticated
using (
  public.keysuite_has_access()
  and lower(email) = public.keysuite_current_email()
  and company_id = public.keysuite_current_company_id()
);

drop policy if exists keysuite_profiles_insert_own on public.ks_user_profiles;
create policy keysuite_profiles_insert_own
on public.ks_user_profiles for insert
to authenticated
with check (
  public.keysuite_has_access()
  and lower(email) = public.keysuite_current_email()
  and company_id = public.keysuite_current_company_id()
);

drop policy if exists keysuite_profiles_update_own on public.ks_user_profiles;
create policy keysuite_profiles_update_own
on public.ks_user_profiles for update
to authenticated
using (
  public.keysuite_has_access()
  and lower(email) = public.keysuite_current_email()
  and company_id = public.keysuite_current_company_id()
)
with check (
  lower(email) = public.keysuite_current_email()
  and company_id = public.keysuite_current_company_id()
);

revoke all on table public.ks_user_profiles from anon;
revoke all on table public.ks_user_profiles from authenticated;
grant select,insert,update on table public.ks_user_profiles to authenticated;

-- Force PostgREST to see newly created tables immediately.
notify pgrst, 'reload schema';

select
  to_regclass('public.ks_customers') as customers_table,
  to_regclass('public.ks_user_profiles') as user_profiles_table;

-- KeySuite V2.22
-- Customer-specific Commission, Set Discount and Final Discount.
-- Run after V221_SUPABASE_MIGRATION.sql.
begin;

create table if not exists public.ks_customer_pricing_settings (
  customer_id uuid primary key references public.ks_customers(id) on delete cascade,
  commission numeric not null default 0 check (commission >= 0 and commission < 1),
  set_discount numeric not null default 0 check (set_discount >= 0 and set_discount < 1),
  final_discount numeric not null default 0 check (final_discount >= 0 and final_discount < 1),
  updated_at timestamptz not null default now(),
  updated_by text
);

create index if not exists ks_customer_pricing_settings_updated_idx
  on public.ks_customer_pricing_settings(updated_at desc);

alter table public.ks_customer_pricing_settings enable row level security;

-- Seed every active customer with a zero-value row.
insert into public.ks_customer_pricing_settings(customer_id)
select c.id
from public.ks_customers c
where c.status='active'
on conflict on constraint ks_customer_pricing_settings_pkey do nothing;

-- Preserve the old company rate for a customer whose name matches its company
-- master (for example the Keylargo customer). Other customers, such as Apex,
-- remain Not Set until the Owner enters their rates.
do $$
begin
  if to_regclass('public.ks_company_pricing_settings') is not null then
    execute $migrate$
      insert into public.ks_customer_pricing_settings as target(
        customer_id,commission,set_discount,final_discount,updated_at,updated_by
      )
      select c.id,
             coalesce(s.quotation_commission,0),
             coalesce(s.quotation_set_discount,0),
             coalesce(s.quotation_final_discount,0),
             now(),
             'V2.22 migration'
      from public.ks_customers c
      join public.ks_companies company_master
        on company_master.id=c.company_id
      join public.ks_company_pricing_settings s
        on s.company_id=company_master.id
      where c.status='active'
        and lower(trim(c.company_name))=lower(trim(company_master.company_name))
      on conflict on constraint ks_customer_pricing_settings_pkey do update set
        commission=case
          when target.commission=0
           and target.set_discount=0
           and target.final_discount=0
          then excluded.commission else target.commission end,
        set_discount=case
          when target.commission=0
           and target.set_discount=0
           and target.final_discount=0
          then excluded.set_discount else target.set_discount end,
        final_discount=case
          when target.commission=0
           and target.set_discount=0
           and target.final_discount=0
          then excluded.final_discount else target.final_discount end,
        updated_at=case
          when target.commission=0
           and target.set_discount=0
           and target.final_discount=0
          then now() else target.updated_at end,
        updated_by=case
          when target.commission=0
           and target.set_discount=0
           and target.final_discount=0
          then excluded.updated_by else target.updated_by end
    $migrate$;
  end if;
end;
$$;

create or replace function public.keysuite_get_customer_pricing_v222()
returns table (
  customer_id uuid,
  customer_name text,
  commission numeric,
  set_discount numeric,
  final_discount numeric,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company_id text:=public.keysuite_current_company_id();
  v_role text:=public.keysuite_current_role();
  v_email text:=public.keysuite_current_email();
begin
  if coalesce(v_company_id,'')='' then
    raise exception 'Your account has no company assignment.';
  end if;

  insert into public.ks_customer_pricing_settings(customer_id)
  select c.id
  from public.ks_customers c
  where c.company_id=v_company_id
    and c.status='active'
    and (
      v_role in ('owner','admin')
      or lower(c.assigned_user_email)=v_email
    )
  on conflict on constraint ks_customer_pricing_settings_pkey do nothing;

  return query
  select c.id,
         c.company_name,
         s.commission,
         s.set_discount,
         s.final_discount,
         s.updated_at
  from public.ks_customers c
  join public.ks_customer_pricing_settings s
    on s.customer_id=c.id
  where c.company_id=v_company_id
    and c.status='active'
    and (
      v_role in ('owner','admin')
      or lower(c.assigned_user_email)=v_email
    )
  order by lower(coalesce(c.company_name,'')),c.id;
end;
$$;

create or replace function public.keysuite_save_customer_pricing_v222(
  p_customer_id uuid,
  p_commission numeric,
  p_set_discount numeric,
  p_final_discount numeric
)
returns table (
  customer_id uuid,
  customer_name text,
  commission numeric,
  set_discount numeric,
  final_discount numeric,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company_id text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can edit Customer pricing percentages.';
  end if;

  if p_customer_id is null or not exists(
    select 1
    from public.ks_customers c
    where c.id=p_customer_id
      and c.company_id=v_company_id
      and c.status='active'
  ) then
    raise exception 'The selected customer was not found.';
  end if;

  if p_commission is null or p_commission<0 or p_commission>=1
     or p_set_discount is null or p_set_discount<0 or p_set_discount>=1
     or p_final_discount is null or p_final_discount<0 or p_final_discount>=1 then
    raise exception 'Customer percentages must be from 0%% to below 100%%.';
  end if;

  insert into public.ks_customer_pricing_settings(
    customer_id,commission,set_discount,final_discount,updated_at,updated_by
  ) values(
    p_customer_id,p_commission,p_set_discount,p_final_discount,now(),v_actor
  )
  on conflict on constraint ks_customer_pricing_settings_pkey do update set
    commission=excluded.commission,
    set_discount=excluded.set_discount,
    final_discount=excluded.final_discount,
    updated_at=now(),
    updated_by=excluded.updated_by;

  return query
  select c.id,
         c.company_name,
         s.commission,
         s.set_discount,
         s.final_discount,
         s.updated_at
  from public.ks_customers c
  join public.ks_customer_pricing_settings s
    on s.customer_id=c.id
  where c.id=p_customer_id
    and c.company_id=v_company_id;
end;
$$;

revoke all on table public.ks_customer_pricing_settings from public;
revoke all on table public.ks_customer_pricing_settings from authenticated;
revoke all on function public.keysuite_get_customer_pricing_v222() from public;
revoke all on function public.keysuite_save_customer_pricing_v222(uuid,numeric,numeric,numeric) from public;
grant execute on function public.keysuite_get_customer_pricing_v222() to authenticated;
grant execute on function public.keysuite_save_customer_pricing_v222(uuid,numeric,numeric,numeric) to authenticated;

notify pgrst,'reload schema';
commit;

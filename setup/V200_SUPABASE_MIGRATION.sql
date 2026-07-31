-- KeySuite V2.0
-- Assembly: System and Pumpset drafts with BOM items
-- Run after V124_SUPABASE_MIGRATION.sql

begin;

create table if not exists public.ks_assemblies (
  id text primary key,
  company_id text not null references public.ks_companies(id) on delete cascade,
  assembly_type text not null check (assembly_type in ('system','pumpset')),
  name text not null,
  customer_id text,
  status text not null default 'draft' check (status in ('draft','ready','quoted')),
  created_by_email text not null,
  assigned_user_email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ks_assembly_items (
  id text primary key,
  assembly_id text not null references public.ks_assemblies(id) on delete cascade,
  line_no integer not null,
  model text not null,
  description text not null default '',
  quantity numeric not null default 1 check (quantity >= 0),
  unit_price numeric not null default 0 check (unit_price >= 0),
  pricing_source jsonb,
  pump_data jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assembly_id,line_no)
);

create index if not exists ks_assemblies_company_type_idx
  on public.ks_assemblies(company_id,assembly_type,status,updated_at desc);
create index if not exists ks_assembly_items_assembly_idx
  on public.ks_assembly_items(assembly_id,line_no);

alter table public.ks_assemblies enable row level security;
alter table public.ks_assembly_items enable row level security;
revoke all on public.ks_assemblies,public.ks_assembly_items from anon,authenticated;

-- Access follows the existing quotation visibility model.
create policy ks_assemblies_select on public.ks_assemblies
for select to authenticated
using (
  public.keysuite_has_access()
  and company_id=public.keysuite_current_company_id()
  and (
    public.keysuite_permission_level('view_quotations') in ('all','full')
    or (public.keysuite_permission_level('view_quotations')='assigned' and lower(assigned_user_email)=public.keysuite_current_email())
    or (public.keysuite_permission_level('view_quotations')='own' and lower(created_by_email)=public.keysuite_current_email())
  )
);

create policy ks_assemblies_insert on public.ks_assemblies
for insert to authenticated
with check (
  public.keysuite_permission_level('create_quotations')='full'
  and company_id=public.keysuite_current_company_id()
  and lower(created_by_email)=public.keysuite_current_email()
);

create policy ks_assemblies_update on public.ks_assemblies
for update to authenticated
using (
  public.keysuite_permission_level('create_quotations')='full'
  and company_id=public.keysuite_current_company_id()
)
with check (company_id=public.keysuite_current_company_id());

create policy ks_assemblies_delete on public.ks_assemblies
for delete to authenticated
using (
  public.keysuite_permission_level('create_quotations')='full'
  and company_id=public.keysuite_current_company_id()
);

create policy ks_assembly_items_select on public.ks_assembly_items
for select to authenticated
using (exists (
  select 1 from public.ks_assemblies a
  where a.id=assembly_id
    and a.company_id=public.keysuite_current_company_id()
));

create policy ks_assembly_items_manage on public.ks_assembly_items
for all to authenticated
using (
  public.keysuite_permission_level('create_quotations')='full'
  and exists (
    select 1 from public.ks_assemblies a
    where a.id=assembly_id
      and a.company_id=public.keysuite_current_company_id()
  )
)
with check (
  public.keysuite_permission_level('create_quotations')='full'
  and exists (
    select 1 from public.ks_assemblies a
    where a.id=assembly_id
      and a.company_id=public.keysuite_current_company_id()
  )
);

create or replace function public.keysuite_list_assemblies_v200()
returns table (
  id text,
  assembly_type text,
  name text,
  customer_id text,
  status text,
  created_by_email text,
  assigned_user_email text,
  created_at timestamptz,
  updated_at timestamptz,
  items jsonb
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.keysuite_has_access() then
    raise exception 'Your account has no active KeySuite access.';
  end if;

  return query
  select a.id,a.assembly_type,a.name,a.customer_id,a.status,
         a.created_by_email,a.assigned_user_email,a.created_at,a.updated_at,
         coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id',i.id,
               'model',i.model,
               'description',i.description,
               'qty',i.quantity,
               'unitPrice',i.unit_price,
               'pricingSource',i.pricing_source,
               'pumpData',i.pump_data
             ) order by i.line_no
           ) filter (where i.id is not null),
           '[]'::jsonb
         ) as items
  from public.ks_assemblies a
  left join public.ks_assembly_items i on i.assembly_id=a.id
  where a.company_id=public.keysuite_current_company_id()
    and (
      public.keysuite_permission_level('view_quotations') in ('all','full')
      or (public.keysuite_permission_level('view_quotations')='assigned' and lower(a.assigned_user_email)=public.keysuite_current_email())
      or (public.keysuite_permission_level('view_quotations')='own' and lower(a.created_by_email)=public.keysuite_current_email())
    )
  group by a.id
  order by a.updated_at desc;
end;
$$;

create or replace function public.keysuite_save_assembly_v200(p_assembly jsonb)
returns table (
  id text,
  assembly_type text,
  name text,
  customer_id text,
  status text,
  created_by_email text,
  assigned_user_email text,
  created_at timestamptz,
  updated_at timestamptz,
  items jsonb
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
  v_id text:=nullif(trim(p_assembly->>'id'),'');
  v_type text:=lower(coalesce(nullif(trim(p_assembly->>'assembly_type'),''),'system'));
  v_name text:=coalesce(nullif(trim(p_assembly->>'name'),''),case when v_type='pumpset' then 'New Pumpset' else 'New System' end);
  v_customer text:=nullif(trim(p_assembly->>'customer_id'),'');
  v_status text:=lower(coalesce(nullif(trim(p_assembly->>'status'),''),'draft'));
  v_item jsonb;
  v_line integer:=0;
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then
    raise exception 'Your role is not allowed to create or edit assemblies.';
  end if;
  if coalesce(v_company,'')='' then raise exception 'Your account has no company assignment.'; end if;
  if v_id is null then raise exception 'Assembly ID is required.'; end if;
  if v_type not in ('system','pumpset') then raise exception 'Invalid assembly type.'; end if;
  if v_status not in ('draft','ready','quoted') then raise exception 'Invalid assembly status.'; end if;

  insert into public.ks_assemblies(
    id,company_id,assembly_type,name,customer_id,status,
    created_by_email,assigned_user_email,created_at,updated_at
  ) values (
    v_id,v_company,v_type,v_name,v_customer,v_status,
    v_actor,v_actor,now(),now()
  )
  on conflict(id) do update set
    assembly_type=excluded.assembly_type,
    name=excluded.name,
    customer_id=excluded.customer_id,
    status=excluded.status,
    updated_at=now()
  where public.ks_assemblies.company_id=v_company;

  if not found then raise exception 'Assembly was not found in your company.'; end if;

  delete from public.ks_assembly_items where assembly_id=v_id;
  for v_item in select value from jsonb_array_elements(coalesce(p_assembly->'items','[]'::jsonb)) loop
    v_line:=v_line+1;
    insert into public.ks_assembly_items(
      id,assembly_id,line_no,model,description,quantity,unit_price,pricing_source,pump_data
    ) values (
      coalesce(nullif(trim(v_item->>'id'),''),v_id||'-'||v_line::text),
      v_id,v_line,
      coalesce(nullif(trim(v_item->>'model'),''),'Product'),
      coalesce(v_item->>'description',''),
      greatest(0,coalesce((v_item->>'qty')::numeric,1)),
      greatest(0,coalesce((v_item->>'unitPrice')::numeric,0)),
      v_item->'pricingSource',
      v_item->'pumpData'
    );
  end loop;

  return query select * from public.keysuite_list_assemblies_v200() x where x.id=v_id;
end;
$$;

create or replace function public.keysuite_delete_assembly_v200(p_assembly_id text)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then
    raise exception 'Your role is not allowed to delete assemblies.';
  end if;
  delete from public.ks_assemblies
  where id=p_assembly_id and company_id=public.keysuite_current_company_id();
  return found;
end;
$$;

revoke all on function public.keysuite_list_assemblies_v200() from public;
revoke all on function public.keysuite_save_assembly_v200(jsonb) from public;
revoke all on function public.keysuite_delete_assembly_v200(text) from public;
grant execute on function public.keysuite_list_assemblies_v200() to authenticated;
grant execute on function public.keysuite_save_assembly_v200(jsonb) to authenticated;
grant execute on function public.keysuite_delete_assembly_v200(text) to authenticated;

notify pgrst,'reload schema';
commit;

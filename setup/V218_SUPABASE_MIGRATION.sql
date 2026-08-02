-- KeySuite V2.18
-- Quotation templates and quotation-scoped Assembly drafts.
-- Run after V213_SUPABASE_MIGRATION.sql (or the latest migration already applied).

begin;

-- ---------------------------------------------------------------------------
-- Assembly drafts: keep every draft tied to its quotation workspace.
-- ---------------------------------------------------------------------------
alter table public.ks_assemblies add column if not exists model_item text not null default '';
alter table public.ks_assemblies add column if not exists description text not null default '';
alter table public.ks_assemblies add column if not exists quote_session_id text;
alter table public.ks_assembly_items add column if not exists item_section text;
alter table public.ks_assembly_items add column if not exists item_data jsonb;

create index if not exists ks_assemblies_quote_session_idx
  on public.ks_assemblies(company_id,quote_session_id,assembly_type,updated_at desc);

create or replace function public.keysuite_list_assemblies_v218()
returns table (
  id text, assembly_type text, name text, model_item text, description text,
  quote_session_id text, customer_id text, status text, created_by_email text,
  assigned_user_email text, created_at timestamptz, updated_at timestamptz, items jsonb
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
  select a.id,a.assembly_type,a.name,coalesce(a.model_item,''),coalesce(a.description,''),
         a.quote_session_id,a.customer_id,a.status,a.created_by_email,a.assigned_user_email,
         a.created_at,a.updated_at,
         coalesce(
           jsonb_agg(
             jsonb_strip_nulls(
               jsonb_build_object(
                 'id',i.id,
                 'section',coalesce(i.item_section,case when a.assembly_type='pumpset' then 'pump' else 'pumpset' end),
                 'model',i.model,
                 'description',i.description,
                 'qty',i.quantity,
                 'unitPrice',i.unit_price,
                 'pricingSource',i.pricing_source,
                 'pumpData',i.pump_data,
                 'bomDescription',i.item_data->'bomDescription',
                 'tankData',i.item_data->'tankData',
                 'keyplcData',i.item_data->'keyplcData',
                 'manifoldData',i.item_data->'manifoldData'
               )
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

create or replace function public.keysuite_save_assembly_v218(p_assembly jsonb)
returns table (
  id text, assembly_type text, name text, model_item text, description text,
  quote_session_id text, customer_id text, status text, created_by_email text,
  assigned_user_email text, created_at timestamptz, updated_at timestamptz, items jsonb
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
  v_model_item text:=coalesce(p_assembly->>'model_item','');
  v_description text:=coalesce(p_assembly->>'description','');
  v_quote_session text:=nullif(trim(p_assembly->>'quote_session_id'),'');
  v_customer text:=nullif(trim(p_assembly->>'customer_id'),'');
  v_status text:=lower(coalesce(nullif(trim(p_assembly->>'status'),''),'draft'));
  v_item jsonb;
  v_section text;
  v_line integer:=0;
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then
    raise exception 'Your role is not allowed to create or edit assemblies.';
  end if;
  if coalesce(v_company,'')='' then raise exception 'Your account has no company assignment.'; end if;
  if v_id is null then raise exception 'Assembly ID is required.'; end if;
  if v_quote_session is null then raise exception 'Quotation session ID is required.'; end if;
  if v_type not in ('system','pumpset') then raise exception 'Invalid assembly type.'; end if;
  if v_status not in ('draft','ready','quoted') then raise exception 'Invalid assembly status.'; end if;

  insert into public.ks_assemblies(
    id,company_id,assembly_type,name,model_item,description,quote_session_id,customer_id,status,
    created_by_email,assigned_user_email,created_at,updated_at
  ) values (
    v_id,v_company,v_type,v_name,v_model_item,v_description,v_quote_session,v_customer,v_status,
    v_actor,v_actor,now(),now()
  )
  on conflict on constraint ks_assemblies_pkey do update set
    assembly_type=excluded.assembly_type,
    name=excluded.name,
    model_item=excluded.model_item,
    description=excluded.description,
    quote_session_id=excluded.quote_session_id,
    customer_id=excluded.customer_id,
    status=excluded.status,
    updated_at=now()
  where public.ks_assemblies.company_id=v_company;

  if not found then raise exception 'Assembly was not found in your company.'; end if;

  delete from public.ks_assembly_items ai where ai.assembly_id=v_id;
  for v_item in select value from jsonb_array_elements(coalesce(p_assembly->'items','[]'::jsonb)) loop
    v_line:=v_line+1;
    v_section:=lower(coalesce(nullif(trim(v_item->>'section'),''),case when v_type='pumpset' then 'pump' else 'pumpset' end));
    if v_section not in ('pump','motor','coupling','baseplate','pumpset','control_panel','manifold','tank') then
      v_section:=case when v_type='pumpset' then 'pump' else 'pumpset' end;
    end if;
    insert into public.ks_assembly_items(
      id,assembly_id,line_no,item_section,model,description,quantity,unit_price,pricing_source,pump_data,item_data
    ) values (
      coalesce(nullif(trim(v_item->>'id'),''),v_id||'-'||v_line::text),v_id,v_line,v_section,
      coalesce(nullif(trim(v_item->>'model'),''),'Product'),coalesce(v_item->>'description',''),
      greatest(0,coalesce((v_item->>'qty')::numeric,1)),greatest(0,coalesce((v_item->>'unitPrice')::numeric,0)),
      v_item->'pricingSource',v_item->'pumpData',
      jsonb_strip_nulls(jsonb_build_object(
        'bomDescription',v_item->'bomDescription',
        'tankData',v_item->'tankData',
        'keyplcData',v_item->'keyplcData',
        'manifoldData',v_item->'manifoldData'
      ))
    );
  end loop;

  return query select * from public.keysuite_list_assemblies_v218() x where x.id=v_id;
end;
$$;

revoke all on function public.keysuite_list_assemblies_v218() from public;
revoke all on function public.keysuite_save_assembly_v218(jsonb) from public;
grant execute on function public.keysuite_list_assemblies_v218() to authenticated;
grant execute on function public.keysuite_save_assembly_v218(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Quotation templates: shared company templates and private dealer templates.
-- ---------------------------------------------------------------------------
create table if not exists public.ks_quotation_templates (
  id text primary key,
  company_id text not null references public.ks_companies(id) on delete cascade,
  template_name text not null,
  template_scope text not null default 'personal' check (template_scope in ('company','personal')),
  owner_email text,
  is_default boolean not null default false,
  status text not null default 'active' check (status in ('active','disabled')),
  settings jsonb not null default '{}'::jsonb,
  created_by_email text not null,
  updated_by_email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ks_quotation_templates_company_idx
  on public.ks_quotation_templates(company_id,template_scope,status,updated_at desc);
create index if not exists ks_quotation_templates_owner_idx
  on public.ks_quotation_templates(company_id,lower(owner_email),status);

alter table public.ks_quotation_templates enable row level security;
revoke all on public.ks_quotation_templates from anon,authenticated;

create or replace function public.keysuite_list_quotation_templates_v218()
returns table (
  id text, company_id text, template_name text, template_scope text, owner_email text,
  is_default boolean, status text, settings jsonb, created_at timestamptz, updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
begin
  if not public.keysuite_has_access() then raise exception 'Your account has no active KeySuite access.'; end if;
  return query
  select t.id,t.company_id,t.template_name,t.template_scope,t.owner_email,t.is_default,t.status,t.settings,t.created_at,t.updated_at
  from public.ks_quotation_templates t
  where t.company_id=v_company
    and (t.template_scope='company' or lower(coalesce(t.owner_email,''))=v_actor)
  order by t.is_default desc,t.template_scope,t.template_name;
end;
$$;

create or replace function public.keysuite_save_quotation_template_v218(p_template jsonb)
returns table (
  id text, company_id text, template_name text, template_scope text, owner_email text,
  is_default boolean, status text, settings jsonb, created_at timestamptz, updated_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
  v_role text;
  v_id text:=coalesce(nullif(trim(p_template->>'id'),''),gen_random_uuid()::text);
  v_name text:=nullif(trim(p_template->>'template_name'),'');
  v_scope text:=lower(coalesce(nullif(trim(p_template->>'template_scope'),''),'personal'));
  v_owner text;
  v_default boolean:=coalesce((p_template->>'is_default')::boolean,false);
  v_status text:=lower(coalesce(nullif(trim(p_template->>'status'),''),'active'));
  v_existing_scope text;
  v_existing_owner text;
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then raise exception 'Your role is not allowed to maintain quotation templates.'; end if;
  if coalesce(v_company,'')='' then raise exception 'Your account has no company assignment.'; end if;
  if v_name is null then raise exception 'Template Name is required.'; end if;
  if v_scope not in ('company','personal') then raise exception 'Invalid template ownership.'; end if;
  if v_status not in ('active','disabled') then raise exception 'Invalid template status.'; end if;

  select lower(coalesce(a.role,'user')) into v_role
  from public.ks_user_access a
  where lower(a.email)=v_actor and a.company_id=v_company and a.active=true
  limit 1;

  if v_scope='company' and coalesce(v_role,'user') not in ('owner','admin','administrator') then
    raise exception 'Only an Owner or Admin can maintain company templates.';
  end if;
  v_owner:=case when v_scope='personal' then v_actor else null end;

  select t.template_scope,lower(coalesce(t.owner_email,'')) into v_existing_scope,v_existing_owner
  from public.ks_quotation_templates t where t.id=v_id and t.company_id=v_company;
  if found then
    if v_existing_scope='company' and coalesce(v_role,'user') not in ('owner','admin','administrator') then
      raise exception 'Only an Owner or Admin can edit this company template.';
    end if;
    if v_existing_scope='personal' and v_existing_owner<>v_actor then
      raise exception 'You cannot edit another user''s personal template.';
    end if;
  end if;

  if v_default then
    update public.ks_quotation_templates t set is_default=false,updated_at=now(),updated_by_email=v_actor
    where t.company_id=v_company and t.template_scope=v_scope
      and (v_scope='company' or lower(coalesce(t.owner_email,''))=v_actor)
      and t.id<>v_id;
  end if;

  insert into public.ks_quotation_templates(
    id,company_id,template_name,template_scope,owner_email,is_default,status,settings,
    created_by_email,updated_by_email,created_at,updated_at
  ) values (
    v_id,v_company,v_name,v_scope,v_owner,v_default,v_status,coalesce(p_template->'settings','{}'::jsonb),
    v_actor,v_actor,now(),now()
  )
  on conflict on constraint ks_quotation_templates_pkey do update set
    template_name=excluded.template_name,
    template_scope=excluded.template_scope,
    owner_email=excluded.owner_email,
    is_default=excluded.is_default,
    status=excluded.status,
    settings=excluded.settings,
    updated_by_email=v_actor,
    updated_at=now()
  where public.ks_quotation_templates.company_id=v_company;

  if not found then raise exception 'Quotation template was not found in your company.'; end if;
  return query select * from public.keysuite_list_quotation_templates_v218() x where x.id=v_id;
end;
$$;

create or replace function public.keysuite_delete_quotation_template_v218(p_template_id text)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
  v_role text;
  v_scope text;
  v_owner text;
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then raise exception 'Your role is not allowed to maintain quotation templates.'; end if;
  select lower(coalesce(a.role,'user')) into v_role from public.ks_user_access a
  where lower(a.email)=v_actor and a.company_id=v_company and a.active=true limit 1;
  select t.template_scope,lower(coalesce(t.owner_email,'')) into v_scope,v_owner
  from public.ks_quotation_templates t where t.id=p_template_id and t.company_id=v_company;
  if not found then return false; end if;
  if v_scope='company' and coalesce(v_role,'user') not in ('owner','admin','administrator') then raise exception 'Only an Owner or Admin can delete a company template.'; end if;
  if v_scope='personal' and v_owner<>v_actor then raise exception 'You cannot delete another user''s personal template.'; end if;
  delete from public.ks_quotation_templates where id=p_template_id and company_id=v_company;
  return found;
end;
$$;

revoke all on function public.keysuite_list_quotation_templates_v218() from public;
revoke all on function public.keysuite_save_quotation_template_v218(jsonb) from public;
revoke all on function public.keysuite_delete_quotation_template_v218(text) from public;
grant execute on function public.keysuite_list_quotation_templates_v218() to authenticated;
grant execute on function public.keysuite_save_quotation_template_v218(jsonb) to authenticated;
grant execute on function public.keysuite_delete_quotation_template_v218(text) to authenticated;

notify pgrst,'reload schema';
commit;

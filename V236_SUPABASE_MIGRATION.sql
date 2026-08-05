-- KeySuite V2.36
-- Secure quotation history and complete Pumpset BOM component persistence.
-- Run after V231_SUPABASE_MIGRATION.sql and all prior migrations.

begin;

create table if not exists public.ks_quotations (
  id text primary key,
  company_id text not null references public.ks_companies(id) on delete cascade,
  quotation_no text not null,
  quotation_date date,
  document_type text not null default 'Quotation',
  customer_id text,
  customer_name text not null default '',
  total numeric not null default 0,
  status text not null default 'saved',
  created_by_email text not null,
  created_by_name text not null default '',
  updated_by_email text not null,
  quote_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, quotation_no)
);

create index if not exists ks_quotations_company_date_idx on public.ks_quotations(company_id, quotation_date desc, updated_at desc);
create index if not exists ks_quotations_company_creator_idx on public.ks_quotations(company_id, lower(created_by_email), quotation_date desc);
create index if not exists ks_quotations_company_customer_idx on public.ks_quotations(company_id, lower(customer_name), quotation_date desc);

alter table public.ks_quotations enable row level security;
revoke all on public.ks_quotations from anon, authenticated;

create or replace function public.keysuite_list_quotations_v236(
  p_year integer default null,
  p_month integer default null,
  p_customer text default null,
  p_user_email text default null
)
returns table (
  id text, quotation_no text, quotation_date date, document_type text,
  customer_id text, customer_name text, total numeric, status text,
  created_by_email text, created_by_name text, updated_by_email text,
  quote_data jsonb, created_at timestamptz, updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
  v_manage boolean:=public.keysuite_permission_level('view_quotations') in ('all','full');
  v_customer text:=lower(trim(coalesce(p_customer,'')));
  v_user text:=lower(trim(coalesce(p_user_email,'')));
begin
  if not public.keysuite_has_access() then raise exception 'Your account has no active KeySuite access.'; end if;
  if coalesce(v_company,'')='' then raise exception 'Your account has no company assignment.'; end if;
  if v_user<>'' and not v_manage then raise exception 'Your role is not allowed to filter another user''s quotations.'; end if;

  return query
  select q.id,q.quotation_no,q.quotation_date,q.document_type,q.customer_id,q.customer_name,
         q.total,q.status,q.created_by_email,q.created_by_name,q.updated_by_email,
         q.quote_data,q.created_at,q.updated_at
  from public.ks_quotations q
  where q.company_id=v_company
    and (v_manage or lower(q.created_by_email)=v_actor)
    and (p_year is null or extract(year from q.quotation_date)::integer=p_year)
    and (p_month is null or extract(month from q.quotation_date)::integer=p_month)
    and (v_customer='' or lower(q.customer_name) like '%'||v_customer||'%')
    and (v_user='' or lower(q.created_by_email)=v_user)
  order by q.quotation_date desc nulls last,q.updated_at desc;
end;
$$;

create or replace function public.keysuite_save_quotation_v236(p_quotation jsonb)
returns table (
  id text, quotation_no text, quotation_date date, document_type text,
  customer_id text, customer_name text, total numeric, status text,
  created_by_email text, created_by_name text, updated_by_email text,
  quote_data jsonb, created_at timestamptz, updated_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
  v_manage boolean:=public.keysuite_permission_level('view_quotations') in ('all','full');
  v_id text:=nullif(trim(p_quotation->>'id'),'');
  v_no text:=upper(nullif(trim(p_quotation->>'no'),''));
  v_date date:=nullif(trim(p_quotation->>'date'),'')::date;
  v_existing public.ks_quotations%rowtype;
  v_creator text;
  v_creator_name text;
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then raise exception 'Your role is not allowed to create or edit quotations.'; end if;
  if coalesce(v_company,'')='' then raise exception 'Your account has no company assignment.'; end if;
  if v_id is null or v_no is null then raise exception 'Quotation ID and number are required.'; end if;

  select * into v_existing from public.ks_quotations q where q.id=v_id and q.company_id=v_company;
  if found and not (v_manage or lower(v_existing.created_by_email)=v_actor) then raise exception 'You may update only your own quotations.'; end if;
  v_creator:=coalesce(v_existing.created_by_email,nullif(lower(trim(p_quotation->>'createdByEmail')),''),v_actor);
  if not v_manage then v_creator:=coalesce(v_existing.created_by_email,v_actor); end if;
  v_creator_name:=coalesce(v_existing.created_by_name,nullif(trim(p_quotation->>'createdByName'),''),v_creator);

  insert into public.ks_quotations(
    id,company_id,quotation_no,quotation_date,document_type,customer_id,customer_name,total,status,
    created_by_email,created_by_name,updated_by_email,quote_data,created_at,updated_at
  ) values (
    v_id,v_company,v_no,v_date,coalesce(nullif(trim(p_quotation->>'documentType'),''),'Quotation'),
    nullif(trim(p_quotation->>'customerId'),''),coalesce(nullif(trim(p_quotation->>'printedCompany'),''),nullif(trim(p_quotation#>>'{pricingCustomerSnapshot,company}'),''),''),
    greatest(0,coalesce((p_quotation->>'total')::numeric,0)),coalesce(nullif(trim(p_quotation->>'status'),''),'saved'),
    v_creator,v_creator_name,v_actor,p_quotation,coalesce(v_existing.created_at,now()),now()
  )
  on conflict on constraint ks_quotations_pkey do update set
    quotation_no=excluded.quotation_no,quotation_date=excluded.quotation_date,document_type=excluded.document_type,
    customer_id=excluded.customer_id,customer_name=excluded.customer_name,total=excluded.total,status=excluded.status,
    updated_by_email=v_actor,quote_data=excluded.quote_data,updated_at=now()
  where public.ks_quotations.company_id=v_company
    and (v_manage or lower(public.ks_quotations.created_by_email)=v_actor);

  if not found then raise exception 'Quotation was not found or is not editable by this user.'; end if;
  return query select q.id,q.quotation_no,q.quotation_date,q.document_type,q.customer_id,q.customer_name,q.total,q.status,q.created_by_email,q.created_by_name,q.updated_by_email,q.quote_data,q.created_at,q.updated_at from public.ks_quotations q where q.id=v_id and q.company_id=v_company;
end;
$$;

create or replace function public.keysuite_delete_quotation_v236(p_id text)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
  v_manage boolean:=public.keysuite_permission_level('view_quotations') in ('all','full');
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then raise exception 'Your role is not allowed to delete quotations.'; end if;
  delete from public.ks_quotations q where q.id=p_id and q.company_id=v_company and (v_manage or lower(q.created_by_email)=v_actor);
  if not found then raise exception 'Quotation was not found or cannot be deleted by this user.'; end if;
  return true;
end;
$$;

-- Preserve every Pumpset component's full typed data across Supabase saves/reloads.
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
  if not public.keysuite_has_access() then raise exception 'Your account has no active KeySuite access.'; end if;
  return query
  select a.id,a.assembly_type,a.name,coalesce(a.model_item,''),coalesce(a.description,''),a.quote_session_id,a.customer_id,a.status,a.created_by_email,a.assigned_user_email,a.created_at,a.updated_at,
    coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'id',i.id,'section',coalesce(i.item_section,case when a.assembly_type='pumpset' then 'pump' else 'pumpset' end),
      'model',i.model,'description',i.description,'qty',i.quantity,'unitPrice',i.unit_price,
      'pricingSource',i.pricing_source,'pumpData',i.pump_data,
      'bomDescription',i.item_data->'bomDescription','tankData',i.item_data->'tankData','keyplcData',i.item_data->'keyplcData',
      'manifoldData',i.item_data->'manifoldData','motorData',i.item_data->'motorData','couplingData',i.item_data->'couplingData','pumpsetData',i.item_data->'pumpsetData'
    )) order by i.line_no) filter (where i.id is not null),'[]'::jsonb)
  from public.ks_assemblies a left join public.ks_assembly_items i on i.assembly_id=a.id
  where a.company_id=public.keysuite_current_company_id()
    and (public.keysuite_permission_level('view_quotations') in ('all','full') or lower(a.created_by_email)=public.keysuite_current_email())
  group by a.id order by a.updated_at desc;
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
  v_company text:=public.keysuite_current_company_id();v_actor text:=public.keysuite_current_email();v_id text:=nullif(trim(p_assembly->>'id'),'');
  v_type text:=lower(coalesce(nullif(trim(p_assembly->>'assembly_type'),''),'system'));v_name text:=coalesce(nullif(trim(p_assembly->>'name'),''),case when v_type='pumpset' then 'New Pumpset' else 'New System' end);
  v_model_item text:=coalesce(p_assembly->>'model_item','');v_description text:=coalesce(p_assembly->>'description','');v_quote_session text:=nullif(trim(p_assembly->>'quote_session_id'),'');v_customer text:=nullif(trim(p_assembly->>'customer_id'),'');v_status text:=lower(coalesce(nullif(trim(p_assembly->>'status'),''),'draft'));v_item jsonb;v_section text;v_line integer:=0;
begin
  if public.keysuite_permission_level('create_quotations')<>'full' then raise exception 'Your role is not allowed to create or edit assemblies.'; end if;
  if coalesce(v_company,'')='' or v_id is null or v_quote_session is null then raise exception 'Assembly company, ID and quotation session are required.'; end if;
  insert into public.ks_assemblies(id,company_id,assembly_type,name,model_item,description,quote_session_id,customer_id,status,created_by_email,assigned_user_email,created_at,updated_at)
  values(v_id,v_company,v_type,v_name,v_model_item,v_description,v_quote_session,v_customer,v_status,v_actor,v_actor,now(),now())
  on conflict on constraint ks_assemblies_pkey do update set assembly_type=excluded.assembly_type,name=excluded.name,model_item=excluded.model_item,description=excluded.description,quote_session_id=excluded.quote_session_id,customer_id=excluded.customer_id,status=excluded.status,updated_at=now()
  where public.ks_assemblies.company_id=v_company and (public.keysuite_permission_level('view_quotations') in ('all','full') or lower(public.ks_assemblies.created_by_email)=v_actor);
  if not found then raise exception 'Assembly was not found or is not editable by this user.'; end if;
  delete from public.ks_assembly_items ai where ai.assembly_id=v_id;
  for v_item in select value from jsonb_array_elements(coalesce(p_assembly->'items','[]'::jsonb)) loop
    v_line:=v_line+1;v_section:=lower(coalesce(nullif(trim(v_item->>'section'),''),case when v_type='pumpset' then 'pump' else 'pumpset' end));
    insert into public.ks_assembly_items(id,assembly_id,line_no,item_section,model,description,quantity,unit_price,pricing_source,pump_data,item_data)
    values(coalesce(nullif(trim(v_item->>'id'),''),v_id||'-'||v_line::text),v_id,v_line,v_section,coalesce(nullif(trim(v_item->>'model'),''),'Product'),coalesce(v_item->>'description',''),greatest(0,coalesce((v_item->>'qty')::numeric,1)),greatest(0,coalesce((v_item->>'unitPrice')::numeric,0)),v_item->'pricingSource',v_item->'pumpData',jsonb_strip_nulls(jsonb_build_object('bomDescription',v_item->'bomDescription','tankData',v_item->'tankData','keyplcData',v_item->'keyplcData','manifoldData',v_item->'manifoldData','motorData',v_item->'motorData','couplingData',v_item->'couplingData','pumpsetData',v_item->'pumpsetData')));
  end loop;
  return query select * from public.keysuite_list_assemblies_v218() x where x.id=v_id;
end;
$$;

revoke all on function public.keysuite_list_quotations_v236(integer,integer,text,text) from public;
revoke all on function public.keysuite_save_quotation_v236(jsonb) from public;
revoke all on function public.keysuite_delete_quotation_v236(text) from public;
grant execute on function public.keysuite_list_quotations_v236(integer,integer,text,text) to authenticated;
grant execute on function public.keysuite_save_quotation_v236(jsonb) to authenticated;
grant execute on function public.keysuite_delete_quotation_v236(text) to authenticated;
revoke all on function public.keysuite_list_assemblies_v218() from public;
revoke all on function public.keysuite_save_assembly_v218(jsonb) from public;
grant execute on function public.keysuite_list_assemblies_v218() to authenticated;
grant execute on function public.keysuite_save_assembly_v218(jsonb) to authenticated;

notify pgrst,'reload schema';
commit;

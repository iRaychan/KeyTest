-- KeySuite V2.02 Assembly save hotfix
begin;
create or replace function public.keysuite_save_assembly_v201(p_assembly jsonb)
returns table (
  id text,
  assembly_type text,
  name text,
  model_item text,
  description text,
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
  v_model_item text:=coalesce(p_assembly->>'model_item','');
  v_description text:=coalesce(p_assembly->>'description','');
  v_name text:=coalesce(nullif(trim(p_assembly->>'name'),''),case when v_type='pumpset' then 'New Pumpset' else 'New System' end);
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
  if v_type not in ('system','pumpset') then raise exception 'Invalid assembly type.'; end if;
  if v_status not in ('draft','ready','quoted') then raise exception 'Invalid assembly status.'; end if;

  insert into public.ks_assemblies(
    id,company_id,assembly_type,name,model_item,description,customer_id,status,
    created_by_email,assigned_user_email,created_at,updated_at
  ) values (
    v_id,v_company,v_type,v_name,v_model_item,v_description,v_customer,v_status,
    v_actor,v_actor,now(),now()
  )
  on conflict on constraint ks_assemblies_pkey do update set
    assembly_type=excluded.assembly_type,
    name=excluded.name,
    model_item=excluded.model_item,
    description=excluded.description,
    customer_id=excluded.customer_id,
    status=excluded.status,
    updated_at=now()
  where public.ks_assemblies.company_id=v_company;

  if not found then raise exception 'Assembly was not found in your company.'; end if;

  delete from public.ks_assembly_items where assembly_id=v_id;
  for v_item in select value from jsonb_array_elements(coalesce(p_assembly->'items','[]'::jsonb)) loop
    v_line:=v_line+1;
    v_section:=lower(coalesce(nullif(trim(v_item->>'section'),''),case when v_type='pumpset' then 'pump' else 'misc' end));
    if v_section not in ('pump','motor','coupling','baseplate','pumpset','control_panel','manifold','tank','misc') then
      v_section:=case when v_type='pumpset' then 'pump' else 'misc' end;
    end if;
    insert into public.ks_assembly_items(
      id,assembly_id,line_no,item_section,model,description,quantity,unit_price,pricing_source,pump_data
    ) values (
      coalesce(nullif(trim(v_item->>'id'),''),v_id||'-'||v_line::text),
      v_id,v_line,v_section,
      coalesce(nullif(trim(v_item->>'model'),''),'Product'),
      coalesce(v_item->>'description',''),
      greatest(0,coalesce((v_item->>'qty')::numeric,1)),
      greatest(0,coalesce((v_item->>'unitPrice')::numeric,0)),
      v_item->'pricingSource',
      v_item->'pumpData'
    );
  end loop;

  return query select x.* from public.keysuite_list_assemblies_v201() as x where x.id=v_id;
end;
$$;


revoke all on function public.keysuite_save_assembly_v201(jsonb) from public;
grant execute on function public.keysuite_save_assembly_v201(jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

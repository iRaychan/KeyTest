-- KeySuite V2.21
-- Single company rate set, category-level factor Use controls, and Owner company selection.
begin;

-- V2.21 keeps the V2.20 storage table for backward compatibility, but the
-- Quotation columns become the canonical company percentages. Assembly uses
-- the same Commission / Final Discount and always excludes Set Discount.
alter table public.ks_company_pricing_settings
  alter column quotation_commission set default 0,
  alter column quotation_set_discount set default 0,
  alter column quotation_final_discount set default 0,
  alter column assembly_commission set default 0,
  alter column assembly_final_discount set default 0;

-- Create zero-value rows for companies that have not been configured yet.
insert into public.ks_company_pricing_settings(
  company_id,
  quotation_commission,quotation_set_discount,quotation_final_discount,
  quotation_include_commission,quotation_include_set_discount,quotation_include_final_discount,quotation_include_fuel_charge,
  assembly_commission,assembly_final_discount,
  assembly_include_commission,assembly_include_final_discount,assembly_include_fuel_charge
)
select c.id,0,0,0,true,true,true,true,0,0,true,true,true
from public.ks_companies c
on conflict(company_id) do nothing;

-- Existing categories keep the V2.20 behaviour by starting with all company
-- factors enabled. New categories can choose each factor independently.
update public.ks_pricing_categories pc
set product_rules=(
  select jsonb_object_agg(f.code,
    coalesce(pc.product_rules->f.code,'{}'::jsonb) || jsonb_build_object(
      'use_commission',coalesce(nullif(pc.product_rules->f.code->>'use_commission','')::boolean,nullif(pc.product_rules->f.code->>'include_commission','')::boolean,true),
      'use_set_discount',coalesce(nullif(pc.product_rules->f.code->>'use_set_discount','')::boolean,nullif(pc.product_rules->f.code->>'include_set_discount','')::boolean,true),
      'use_final_discount',coalesce(nullif(pc.product_rules->f.code->>'use_final_discount','')::boolean,nullif(pc.product_rules->f.code->>'include_final_discount','')::boolean,true),
      'use_fuel_charge',coalesce(nullif(pc.product_rules->f.code->>'use_fuel_charge','')::boolean,nullif(pc.product_rules->f.code->>'include_fuel_charge','')::boolean,true)
    )
  )
  from (values('CHC'),('ES'),('GWS'),('KEYPLC'),('MANIFOLD')) as f(code)
);

create or replace function public.keysuite_get_company_pricing_v221()
returns table (
  company_id text,
  company_name text,
  commission numeric,
  set_discount numeric,
  final_discount numeric,
  updated_at timestamptz
)
language plpgsql security definer set search_path=public
as $$
declare
  v_company_id text:=public.keysuite_current_company_id();
  v_role text:=public.keysuite_current_role();
begin
  if coalesce(v_company_id,'')='' then raise exception 'Your account has no company assignment.'; end if;

  if v_role='owner' then
    insert into public.ks_company_pricing_settings(
      company_id,quotation_commission,quotation_set_discount,quotation_final_discount,
      quotation_include_commission,quotation_include_set_discount,quotation_include_final_discount,quotation_include_fuel_charge,
      assembly_commission,assembly_final_discount,
      assembly_include_commission,assembly_include_final_discount,assembly_include_fuel_charge
    )
    select c.id,0,0,0,true,true,true,true,0,0,true,true,true
    from public.ks_companies c
    on conflict(company_id) do nothing;

    return query
    select c.id,c.company_name,
           s.quotation_commission,s.quotation_set_discount,s.quotation_final_discount,s.updated_at
    from public.ks_companies c
    join public.ks_company_pricing_settings s on s.company_id=c.id
    order by lower(coalesce(c.company_name,'')),c.id;
  else
    insert into public.ks_company_pricing_settings(
      company_id,quotation_commission,quotation_set_discount,quotation_final_discount,
      quotation_include_commission,quotation_include_set_discount,quotation_include_final_discount,quotation_include_fuel_charge,
      assembly_commission,assembly_final_discount,
      assembly_include_commission,assembly_include_final_discount,assembly_include_fuel_charge
    ) values(v_company_id,0,0,0,true,true,true,true,0,0,true,true,true)
    on conflict(company_id) do nothing;

    return query
    select c.id,c.company_name,
           s.quotation_commission,s.quotation_set_discount,s.quotation_final_discount,s.updated_at
    from public.ks_companies c
    join public.ks_company_pricing_settings s on s.company_id=c.id
    where c.id=v_company_id;
  end if;
end;
$$;

create or replace function public.keysuite_save_company_pricing_v221(
  p_company_id text,
  p_commission numeric,
  p_set_discount numeric,
  p_final_discount numeric
)
returns table (
  company_id text,
  company_name text,
  commission numeric,
  set_discount numeric,
  final_discount numeric,
  updated_at timestamptz
)
language plpgsql security definer set search_path=public
as $$
declare
  v_target text:=trim(coalesce(p_company_id,''));
  v_actor text:=lower(coalesce(auth.jwt()->>'email',''));
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can edit Company pricing percentages.'; end if;
  if v_target='' or not exists(select 1 from public.ks_companies c where c.id=v_target) then raise exception 'The selected company was not found.'; end if;
  if p_commission is null or p_commission<0 or p_commission>=1
     or p_set_discount is null or p_set_discount<0 or p_set_discount>=1
     or p_final_discount is null or p_final_discount<0 or p_final_discount>=1 then
    raise exception 'Company percentages must be from 0%% to below 100%%.';
  end if;

  insert into public.ks_company_pricing_settings(
    company_id,
    quotation_commission,quotation_set_discount,quotation_final_discount,
    quotation_include_commission,quotation_include_set_discount,quotation_include_final_discount,quotation_include_fuel_charge,
    assembly_commission,assembly_final_discount,
    assembly_include_commission,assembly_include_final_discount,assembly_include_fuel_charge,
    updated_at,updated_by
  ) values(
    v_target,p_commission,p_set_discount,p_final_discount,
    true,true,true,true,
    p_commission,p_final_discount,true,true,true,
    now(),v_actor
  )
  on conflict(company_id) do update set
    quotation_commission=excluded.quotation_commission,
    quotation_set_discount=excluded.quotation_set_discount,
    quotation_final_discount=excluded.quotation_final_discount,
    quotation_include_commission=true,
    quotation_include_set_discount=true,
    quotation_include_final_discount=true,
    quotation_include_fuel_charge=true,
    assembly_commission=excluded.assembly_commission,
    assembly_final_discount=excluded.assembly_final_discount,
    assembly_include_commission=true,
    assembly_include_final_discount=true,
    assembly_include_fuel_charge=true,
    updated_at=now(),updated_by=excluded.updated_by;

  return query
  select c.id,c.company_name,s.quotation_commission,s.quotation_set_discount,s.quotation_final_discount,s.updated_at
  from public.ks_companies c
  join public.ks_company_pricing_settings s on s.company_id=c.id
  where c.id=v_target;
end;
$$;

create or replace function public.keysuite_manage_pricing_category_v221(
  p_category_id text,p_category_name text,p_product_code text,
  p_margin numeric,p_normal numeric,p_rare numeric,p_transport numeric,
  p_use_commission boolean,p_use_set_discount boolean,p_use_final_discount boolean,p_use_fuel_charge boolean
)
returns table (category_id text,category_name text,product_rules jsonb)
language plpgsql security definer set search_path=public
as $$
declare
  v_id text:=trim(coalesce(p_category_id,''));v_name text:=trim(coalesce(p_category_name,''));
  v_product text:=upper(trim(coalesce(p_product_code,'')));v_rule jsonb;v_defaults jsonb;
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can manage pricing categories.'; end if;
  if v_name='' then raise exception 'Category Name is required.'; end if;
  if v_product not in ('CHC','ES','GWS','KEYPLC','MANIFOLD') then raise exception 'Invalid product family.'; end if;
  if p_margin is null or p_margin<0 or p_margin>=1 or p_normal is null or p_normal<0 or p_normal>=1 or p_rare is null or p_rare<0 or p_rare>=1 then raise exception 'Percentages must be from 0%% to below 100%%.'; end if;
  if p_transport is null or p_transport<0 then raise exception 'Transport must be zero or more.'; end if;
  if exists(select 1 from public.ks_pricing_categories pc where lower(pc.category_name)=lower(v_name) and (v_id='' or pc.id<>v_id)) then raise exception 'A pricing category with this name already exists.'; end if;

  v_rule:=jsonb_build_object(
    'margin',p_margin,'normal',p_normal,'rare',p_rare,'transport',p_transport,
    'use_commission',coalesce(p_use_commission,false),
    'use_set_discount',coalesce(p_use_set_discount,false),
    'use_final_discount',coalesce(p_use_final_discount,false),
    'use_fuel_charge',coalesce(p_use_fuel_charge,false)
  );
  v_defaults:=jsonb_build_object(
    'margin',0,'normal',0,'rare',0,'transport',0,
    'use_commission',false,'use_set_discount',false,'use_final_discount',false,'use_fuel_charge',false
  );

  if v_id='' then
    v_id:='CCID'||upper(substr(md5(clock_timestamp()::text||random()::text||v_name),1,12));
    insert into public.ks_pricing_categories(id,category_name,final_discount,set_discount,commission,chc_factor,transport,chc_margin,product_rules)
    values(v_id,v_name,0,0,0,case when v_product='CHC' then p_margin else 0 end,case when v_product='CHC' then p_transport else 0 end,case when v_product='CHC' then p_margin else 0 end,
      jsonb_build_object('CHC',case when v_product='CHC' then v_rule else v_defaults end,'ES',case when v_product='ES' then v_rule else v_defaults end,'GWS',case when v_product='GWS' then v_rule else v_defaults end,'KEYPLC',case when v_product='KEYPLC' then v_rule else v_defaults end,'MANIFOLD',case when v_product='MANIFOLD' then v_rule else v_defaults end));
  else
    update public.ks_pricing_categories pc set
      category_name=v_name,
      product_rules=jsonb_set(coalesce(pc.product_rules,'{}'::jsonb),array[v_product],v_rule,true),
      chc_factor=case when v_product='CHC' then p_margin else pc.chc_factor end,
      chc_margin=case when v_product='CHC' then p_margin else pc.chc_margin end,
      transport=case when v_product='CHC' then p_transport else pc.transport end
    where pc.id=v_id;
    if not found then raise exception 'Pricing category was not found.'; end if;
  end if;

  return query select pc.id,pc.category_name,pc.product_rules from public.ks_pricing_categories pc where pc.id=v_id;
end;
$$;

revoke all on function public.keysuite_get_company_pricing_v221() from public;
revoke all on function public.keysuite_save_company_pricing_v221(text,numeric,numeric,numeric) from public;
revoke all on function public.keysuite_manage_pricing_category_v221(text,text,text,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
grant execute on function public.keysuite_get_company_pricing_v221() to authenticated;
grant execute on function public.keysuite_save_company_pricing_v221(text,numeric,numeric,numeric) to authenticated;
grant execute on function public.keysuite_manage_pricing_category_v221(text,text,text,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

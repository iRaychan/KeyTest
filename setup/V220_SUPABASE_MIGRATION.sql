-- KeySuite V2.20
-- Company-level Assembly / Quotation pricing factors and simplified Category Pricing Rules.
begin;

create table if not exists public.ks_company_pricing_settings (
  company_id text primary key references public.ks_companies(id) on delete cascade,
  quotation_commission numeric not null default 0.03 check (quotation_commission>=0 and quotation_commission<1),
  quotation_set_discount numeric not null default 0.068 check (quotation_set_discount>=0 and quotation_set_discount<1),
  quotation_final_discount numeric not null default 0.08 check (quotation_final_discount>=0 and quotation_final_discount<1),
  quotation_include_commission boolean not null default true,
  quotation_include_set_discount boolean not null default true,
  quotation_include_final_discount boolean not null default true,
  quotation_include_fuel_charge boolean not null default true,
  assembly_commission numeric not null default 0.03 check (assembly_commission>=0 and assembly_commission<1),
  assembly_final_discount numeric not null default 0.08 check (assembly_final_discount>=0 and assembly_final_discount<1),
  assembly_include_commission boolean not null default true,
  assembly_include_final_discount boolean not null default true,
  assembly_include_fuel_charge boolean not null default true,
  updated_at timestamptz not null default now(),
  updated_by text
);

alter table public.ks_company_pricing_settings enable row level security;
revoke all on public.ks_company_pricing_settings from public, anon, authenticated;

-- Seed the existing company factors into Quotation. Assembly starts with the same
-- Commission / Final / Fuel settings but intentionally excludes Set Discount.
insert into public.ks_company_pricing_settings (
  company_id,
  quotation_commission,quotation_set_discount,quotation_final_discount,
  quotation_include_commission,quotation_include_set_discount,quotation_include_final_discount,quotation_include_fuel_charge,
  assembly_commission,assembly_final_discount,
  assembly_include_commission,assembly_include_final_discount,assembly_include_fuel_charge
)
select c.id,
  coalesce(nullif(pc.product_rules->'CHC'->>'commission','')::numeric,pc.commission,0.03),
  coalesce(nullif(pc.product_rules->'CHC'->>'set_discount','')::numeric,pc.set_discount,0.068),
  coalesce(nullif(pc.product_rules->'CHC'->>'final_discount','')::numeric,pc.final_discount,0.08),
  coalesce(nullif(pc.product_rules->'CHC'->>'include_commission','')::boolean,true),
  coalesce(nullif(pc.product_rules->'CHC'->>'include_set_discount','')::boolean,true),
  coalesce(nullif(pc.product_rules->'CHC'->>'include_final_discount','')::boolean,true),
  coalesce(nullif(pc.product_rules->'CHC'->>'include_fuel_charge','')::boolean,true),
  coalesce(nullif(pc.product_rules->'CHC'->>'commission','')::numeric,pc.commission,0.03),
  coalesce(nullif(pc.product_rules->'CHC'->>'final_discount','')::numeric,pc.final_discount,0.08),
  coalesce(nullif(pc.product_rules->'CHC'->>'include_commission','')::boolean,true),
  coalesce(nullif(pc.product_rules->'CHC'->>'include_final_discount','')::boolean,true),
  coalesce(nullif(pc.product_rules->'CHC'->>'include_fuel_charge','')::boolean,true)
from public.ks_companies c
left join lateral (
  select p.* from public.ks_pricing_categories p
  order by case when lower(trim(coalesce(p.category_name,'')))=lower(trim(coalesce(c.pricing_category,''))) then 0 else 1 end,
           p.category_name
  limit 1
) pc on true
on conflict (company_id) do nothing;

create or replace function public.keysuite_get_company_pricing_v220()
returns table (
  company_id text,
  quotation_commission numeric,quotation_set_discount numeric,quotation_final_discount numeric,
  quotation_include_commission boolean,quotation_include_set_discount boolean,quotation_include_final_discount boolean,quotation_include_fuel_charge boolean,
  assembly_commission numeric,assembly_final_discount numeric,
  assembly_include_commission boolean,assembly_include_final_discount boolean,assembly_include_fuel_charge boolean,
  updated_at timestamptz
)
language plpgsql security definer set search_path=public
as $$
declare v_company_id text:=public.keysuite_current_company_id();
begin
  if coalesce(v_company_id,'')='' then raise exception 'Your account has no company assignment.'; end if;
  insert into public.ks_company_pricing_settings(company_id) values(v_company_id) on conflict(company_id) do nothing;
  return query
  select s.company_id,s.quotation_commission,s.quotation_set_discount,s.quotation_final_discount,
         s.quotation_include_commission,s.quotation_include_set_discount,s.quotation_include_final_discount,s.quotation_include_fuel_charge,
         s.assembly_commission,s.assembly_final_discount,
         s.assembly_include_commission,s.assembly_include_final_discount,s.assembly_include_fuel_charge,s.updated_at
  from public.ks_company_pricing_settings s where s.company_id=v_company_id;
end;
$$;

create or replace function public.keysuite_save_company_pricing_v220(p_settings jsonb)
returns table (
  company_id text,
  quotation_commission numeric,quotation_set_discount numeric,quotation_final_discount numeric,
  quotation_include_commission boolean,quotation_include_set_discount boolean,quotation_include_final_discount boolean,quotation_include_fuel_charge boolean,
  assembly_commission numeric,assembly_final_discount numeric,
  assembly_include_commission boolean,assembly_include_final_discount boolean,assembly_include_fuel_charge boolean,
  updated_at timestamptz
)
language plpgsql security definer set search_path=public
as $$
declare
  v_company_id text:=public.keysuite_current_company_id();
  q_comm numeric:=coalesce((p_settings->>'quotation_commission')::numeric,0);
  q_set numeric:=coalesce((p_settings->>'quotation_set_discount')::numeric,0);
  q_final numeric:=coalesce((p_settings->>'quotation_final_discount')::numeric,0);
  a_comm numeric:=coalesce((p_settings->>'assembly_commission')::numeric,0);
  a_final numeric:=coalesce((p_settings->>'assembly_final_discount')::numeric,0);
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can edit Company pricing factors.'; end if;
  if coalesce(v_company_id,'')='' then raise exception 'Your account has no company assignment.'; end if;
  if q_comm<0 or q_comm>=1 or q_set<0 or q_set>=1 or q_final<0 or q_final>=1 or a_comm<0 or a_comm>=1 or a_final<0 or a_final>=1 then
    raise exception 'Company percentages must be from 0%% to below 100%%.';
  end if;
  insert into public.ks_company_pricing_settings(
    company_id,quotation_commission,quotation_set_discount,quotation_final_discount,
    quotation_include_commission,quotation_include_set_discount,quotation_include_final_discount,quotation_include_fuel_charge,
    assembly_commission,assembly_final_discount,assembly_include_commission,assembly_include_final_discount,assembly_include_fuel_charge,
    updated_at,updated_by
  ) values (
    v_company_id,q_comm,q_set,q_final,
    coalesce((p_settings->>'quotation_include_commission')::boolean,false),coalesce((p_settings->>'quotation_include_set_discount')::boolean,false),coalesce((p_settings->>'quotation_include_final_discount')::boolean,false),coalesce((p_settings->>'quotation_include_fuel_charge')::boolean,false),
    a_comm,a_final,coalesce((p_settings->>'assembly_include_commission')::boolean,false),coalesce((p_settings->>'assembly_include_final_discount')::boolean,false),coalesce((p_settings->>'assembly_include_fuel_charge')::boolean,false),
    now(),lower(coalesce(auth.jwt()->>'email',''))
  )
  on conflict(company_id) do update set
    quotation_commission=excluded.quotation_commission,quotation_set_discount=excluded.quotation_set_discount,quotation_final_discount=excluded.quotation_final_discount,
    quotation_include_commission=excluded.quotation_include_commission,quotation_include_set_discount=excluded.quotation_include_set_discount,quotation_include_final_discount=excluded.quotation_include_final_discount,quotation_include_fuel_charge=excluded.quotation_include_fuel_charge,
    assembly_commission=excluded.assembly_commission,assembly_final_discount=excluded.assembly_final_discount,
    assembly_include_commission=excluded.assembly_include_commission,assembly_include_final_discount=excluded.assembly_include_final_discount,assembly_include_fuel_charge=excluded.assembly_include_fuel_charge,
    updated_at=now(),updated_by=excluded.updated_by;
  return query select * from public.keysuite_get_company_pricing_v220();
end;
$$;

-- Category rules now own only Margin, Normal, Rare and Transport.
create or replace function public.keysuite_manage_pricing_category_v220(
  p_category_id text,p_category_name text,p_product_code text,
  p_margin numeric,p_normal numeric,p_rare numeric,p_transport numeric
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
  v_rule:=jsonb_build_object('margin',p_margin,'normal',p_normal,'rare',p_rare,'transport',p_transport);
  v_defaults:=jsonb_build_object('margin',0,'normal',0,'rare',0,'transport',0);
  if v_id='' then
    v_id:='CCID'||upper(substr(md5(clock_timestamp()::text||random()::text||v_name),1,12));
    insert into public.ks_pricing_categories(id,category_name,final_discount,set_discount,commission,chc_factor,transport,chc_margin,product_rules)
    values(v_id,v_name,0,0,0,case when v_product='CHC' then p_margin else 0 end,case when v_product='CHC' then p_transport else 0 end,case when v_product='CHC' then p_margin else 0 end,
      jsonb_build_object('CHC',case when v_product='CHC' then v_rule else v_defaults end,'ES',case when v_product='ES' then v_rule else v_defaults end,'GWS',case when v_product='GWS' then v_rule else v_defaults end,'KEYPLC',case when v_product='KEYPLC' then v_rule else v_defaults end,'MANIFOLD',case when v_product='MANIFOLD' then v_rule else v_defaults end));
  else
    update public.ks_pricing_categories pc set category_name=v_name,product_rules=jsonb_set(coalesce(pc.product_rules,'{}'::jsonb),array[v_product],v_rule,true),
      chc_factor=case when v_product='CHC' then p_margin else pc.chc_factor end,chc_margin=case when v_product='CHC' then p_margin else pc.chc_margin end,transport=case when v_product='CHC' then p_transport else pc.transport end
    where pc.id=v_id;
    if not found then raise exception 'Pricing category was not found.'; end if;
  end if;
  return query select pc.id,pc.category_name,pc.product_rules from public.ks_pricing_categories pc where pc.id=v_id;
end;
$$;

revoke all on function public.keysuite_get_company_pricing_v220() from public;
revoke all on function public.keysuite_save_company_pricing_v220(jsonb) from public;
revoke all on function public.keysuite_manage_pricing_category_v220(text,text,text,numeric,numeric,numeric,numeric) from public;
grant execute on function public.keysuite_get_company_pricing_v220() to authenticated;
grant execute on function public.keysuite_save_company_pricing_v220(jsonb) to authenticated;
grant execute on function public.keysuite_manage_pricing_category_v220(text,text,text,numeric,numeric,numeric,numeric) to authenticated;

notify pgrst,'reload schema';
commit;

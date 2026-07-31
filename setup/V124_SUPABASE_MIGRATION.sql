-- KeySuite V1.24
-- Customisable role permissions, controlled by Owner.
-- Run after the V1.20/V1.20.4 migrations.

begin;

create table if not exists public.ks_role_permissions (
  company_id text not null references public.ks_companies(id) on delete cascade,
  role text not null check (role in ('viewer','dealer','user','admin','owner')),
  permissions jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by text,
  primary key (company_id,role)
);

alter table public.ks_role_permissions enable row level security;
revoke all on table public.ks_role_permissions from anon,authenticated;

create or replace function public.keysuite_default_role_permissions(p_role text)
returns jsonb
language sql
immutable
as $$
select case lower(coalesce(p_role,''))
  when 'viewer' then '{
    "key_dashboard":"none","manage_roles":"none","company_pricing":"none",
    "manage_categories":"none","manage_price_list":"none","change_fuel_price":"none",
    "view_customers":"assigned","edit_customers":"none","customer_assignment":"none",
    "create_quotations":"none","view_quotations":"assigned","own_profile":"full"
  }'::jsonb
  when 'dealer' then '{
    "key_dashboard":"none","manage_roles":"none","company_pricing":"none",
    "manage_categories":"none","manage_price_list":"none","change_fuel_price":"none",
    "view_customers":"own","edit_customers":"own","customer_assignment":"none",
    "create_quotations":"full","view_quotations":"own","own_profile":"full"
  }'::jsonb
  when 'user' then '{
    "key_dashboard":"none","manage_roles":"none","company_pricing":"none",
    "manage_categories":"none","manage_price_list":"none","change_fuel_price":"none",
    "view_customers":"assigned","edit_customers":"assigned","customer_assignment":"none",
    "create_quotations":"full","view_quotations":"assigned","own_profile":"full"
  }'::jsonb
  when 'admin' then '{
    "key_dashboard":"none","manage_roles":"none","company_pricing":"none",
    "manage_categories":"none","manage_price_list":"none","change_fuel_price":"none",
    "view_customers":"all","edit_customers":"all","customer_assignment":"full",
    "create_quotations":"full","view_quotations":"all","own_profile":"full"
  }'::jsonb
  when 'owner' then '{
    "key_dashboard":"full","manage_roles":"full","company_pricing":"full",
    "manage_categories":"full","manage_price_list":"full","change_fuel_price":"full",
    "view_customers":"all","edit_customers":"all","customer_assignment":"full",
    "create_quotations":"full","view_quotations":"all","own_profile":"full"
  }'::jsonb
  else '{}'::jsonb end;
$$;

-- Seed every company with the agreed defaults. Existing custom values remain unchanged.
insert into public.ks_role_permissions(company_id,role,permissions)
select c.id,r.role,public.keysuite_default_role_permissions(r.role)
from public.ks_companies c
cross join (values ('viewer'),('dealer'),('user'),('admin'),('owner')) as r(role)
on conflict(company_id,role) do nothing;

create or replace function public.keysuite_permission_level(p_key text,p_role text default null)
returns text
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_role text:=lower(coalesce(nullif(p_role,''),public.keysuite_current_role()));
  v_permissions jsonb;
begin
  select rp.permissions into v_permissions
  from public.ks_role_permissions rp
  where rp.company_id=v_company and rp.role=v_role;

  return coalesce(
    nullif(v_permissions->>p_key,''),
    public.keysuite_default_role_permissions(v_role)->>p_key,
    'none'
  );
end;
$$;

create or replace function public.keysuite_get_role_permissions()
returns table(role text,permissions jsonb)
language plpgsql
stable
security definer
set search_path=public
as $$
declare v_company text:=public.keysuite_current_company_id();
begin
  if coalesce(v_company,'')='' then
    raise exception 'Your account has no company assignment.';
  end if;
  return query
  select r.role,
         coalesce(p.permissions,public.keysuite_default_role_permissions(r.role))
  from (values ('viewer'),('dealer'),('user'),('admin'),('owner')) as r(role)
  left join public.ks_role_permissions p
    on p.company_id=v_company and p.role=r.role
  order by case r.role when 'viewer' then 1 when 'dealer' then 2 when 'user' then 3 when 'admin' then 4 else 5 end;
end;
$$;

create or replace function public.keysuite_save_role_permissions(p_matrix jsonb)
returns table(role text,permissions jsonb)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_actor text:=public.keysuite_current_email();
  v_role text;
  v_permissions jsonb;
  v_allowed text[]:=array['none','view','own','assigned','all','full'];
  v_key text;
  v_value text;
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can customise role permissions.';
  end if;
  if jsonb_typeof(p_matrix)<>'object' then
    raise exception 'Permission matrix must be a JSON object.';
  end if;

  foreach v_role in array array['viewer','dealer','user','admin','owner'] loop
    v_permissions:=coalesce(p_matrix->v_role,public.keysuite_default_role_permissions(v_role));
    if jsonb_typeof(v_permissions)<>'object' then
      raise exception 'Invalid permissions for role %.',v_role;
    end if;

    for v_key,v_value in select key,value #>> '{}' from jsonb_each(v_permissions) loop
      if not (lower(coalesce(v_value,''))=any(v_allowed)) then
        raise exception 'Invalid permission value % for % / %.',v_value,v_role,v_key;
      end if;
    end loop;

    -- Never allow the system to lose its final administration path.
    if v_role='owner' then
      v_permissions:=v_permissions||jsonb_build_object(
        'key_dashboard','full',
        'manage_roles','full',
        'own_profile','full'
      );
    end if;

    insert into public.ks_role_permissions(company_id,role,permissions,updated_at,updated_by)
    values(v_company,v_role,v_permissions,now(),v_actor)
    on conflict(company_id,role) do update set
      permissions=excluded.permissions,
      updated_at=excluded.updated_at,
      updated_by=excluded.updated_by;
  end loop;

  return query select * from public.keysuite_get_role_permissions();
end;
$$;

-- Role-management functions now obey the custom manage_roles authority.
create or replace function public.keysuite_list_role_users()
returns table (
  email text,display_name text,role text,active boolean,auth_exists boolean,
  last_sign_in_at timestamptz,created_at timestamptz
)
language plpgsql
security definer
set search_path=public,auth
as $$
begin
  if public.keysuite_permission_level('manage_roles')='none' then
    raise exception 'Your role is not allowed to view role management.';
  end if;
  return query
  select a.email,coalesce(nullif(a.display_name,''),u.full_name,a.email),lower(a.role),a.active,
    exists(select 1 from auth.users au where lower(au.email)=lower(a.email)),
    (select au.last_sign_in_at from auth.users au where lower(au.email)=lower(a.email) limit 1),a.created_at
  from public.ks_user_access a
  left join public.ks_company_users u on u.id=a.employee_id
  where a.company_id=public.keysuite_current_company_id()
  order by case lower(a.role) when 'viewer' then 1 when 'dealer' then 2 when 'user' then 3 when 'admin' then 4 else 5 end,
           coalesce(nullif(a.display_name,''),u.full_name,a.email);
end;
$$;

create or replace function public.keysuite_list_role_audit(p_limit integer default 30)
returns table (
  target_email text,target_display_name text,old_role text,new_role text,
  old_active boolean,new_active boolean,changed_by_email text,changed_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if public.keysuite_permission_level('manage_roles')='none' then
    raise exception 'Your role is not allowed to view role history.';
  end if;
  return query
  select a.target_email,a.target_display_name,a.old_role,a.new_role,a.old_active,a.new_active,a.changed_by_email,a.changed_at
  from public.ks_role_audit a
  where a.company_id=public.keysuite_current_company_id()
  order by a.changed_at desc
  limit greatest(1,least(coalesce(p_limit,30),100));
end;
$$;

create or replace function public.keysuite_manage_user_role(
  p_email text,p_display_name text,p_role text,p_active boolean default true
)
returns table(email text,display_name text,role text,active boolean,auth_exists boolean)
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_actor_email text:=public.keysuite_current_email();
  v_actor_role text:=public.keysuite_current_role();
  v_company_id text:=public.keysuite_current_company_id();
  v_email text:=lower(trim(coalesce(p_email,'')));
  v_name text:=trim(coalesce(p_display_name,''));
  v_role text:=lower(trim(coalesce(p_role,'')));
  v_old_role text;v_old_active boolean;v_old_company text;v_employee_id text;
  v_existing boolean:=false;v_owner_count integer;
begin
  if public.keysuite_permission_level('manage_roles')='none' then
    raise exception 'Your role is not allowed to manage users.';
  end if;
  if coalesce(v_company_id,'')='' then raise exception 'Your account has no company assignment.'; end if;
  if v_email='' or position('@' in v_email)<2 then raise exception 'Enter a valid email address.'; end if;
  if v_name='' then raise exception 'Display Name is required.'; end if;
  if v_role not in ('owner','admin','user','dealer','viewer') then raise exception 'Invalid role.'; end if;

  select a.role,a.active,a.company_id,a.employee_id into v_old_role,v_old_active,v_old_company,v_employee_id
  from public.ks_user_access a where lower(a.email)=v_email limit 1;
  v_existing:=found;
  if v_existing and v_old_company<>v_company_id then raise exception 'This email belongs to another company.'; end if;

  if v_actor_role<>'owner' and (coalesce(lower(v_old_role),'')='owner' or v_role='owner') then
    raise exception 'Only an Owner can assign or change an Owner role.';
  end if;

  if v_existing and lower(v_old_role)='owner' and coalesce(v_old_active,false)
     and (v_role<>'owner' or not coalesce(p_active,false)) then
    select count(*) into v_owner_count from public.ks_user_access a
    where a.company_id=v_company_id and lower(a.role)='owner' and a.active=true;
    if v_owner_count<=1 then raise exception 'The last active Owner cannot be removed or disabled.'; end if;
  end if;

  if v_employee_id is null then
    select u.id into v_employee_id from public.ks_company_users u
    where u.company_id=v_company_id and lower(coalesce(u.email,''))=v_email limit 1;
  end if;
  if v_employee_id is null then
    v_employee_id:='EID-'||upper(substr(md5(v_company_id||':'||v_email),1,16));
    insert into public.ks_company_users(id,company_id,full_name,email)
    values(v_employee_id,v_company_id,v_name,v_email)
    on conflict(id) do update set full_name=excluded.full_name,email=excluded.email;
  else
    update public.ks_company_users set full_name=v_name,email=v_email where id=v_employee_id;
  end if;

  update public.ks_user_access a set employee_id=v_employee_id,company_id=v_company_id,role=v_role,
    display_name=v_name,active=coalesce(p_active,true) where lower(a.email)=v_email;
  if not found then
    insert into public.ks_user_access(email,employee_id,company_id,role,display_name,active)
    values(v_email,v_employee_id,v_company_id,v_role,v_name,coalesce(p_active,true));
  end if;

  if not v_existing or lower(coalesce(v_old_role,''))<>v_role or coalesce(v_old_active,false)<>coalesce(p_active,true) then
    insert into public.ks_role_audit(company_id,target_email,target_display_name,old_role,new_role,old_active,new_active,changed_by_email)
    values(v_company_id,v_email,v_name,case when v_existing then lower(v_old_role) else null end,v_role,
      case when v_existing then v_old_active else null end,coalesce(p_active,true),v_actor_email);
  end if;

  return query select a.email,a.display_name,lower(a.role),a.active,
    exists(select 1 from auth.users au where lower(au.email)=lower(a.email))
  from public.ks_user_access a where lower(a.email)=v_email;
end;
$$;

revoke all on function public.keysuite_default_role_permissions(text) from public;
revoke all on function public.keysuite_permission_level(text,text) from public;
revoke all on function public.keysuite_get_role_permissions() from public;
revoke all on function public.keysuite_save_role_permissions(jsonb) from public;
revoke all on function public.keysuite_list_role_users() from public;
revoke all on function public.keysuite_list_role_audit(integer) from public;
revoke all on function public.keysuite_manage_user_role(text,text,text,boolean) from public;

grant execute on function public.keysuite_default_role_permissions(text) to authenticated;
grant execute on function public.keysuite_permission_level(text,text) to authenticated;
grant execute on function public.keysuite_get_role_permissions() to authenticated;
grant execute on function public.keysuite_save_role_permissions(jsonb) to authenticated;
grant execute on function public.keysuite_list_role_users() to authenticated;
grant execute on function public.keysuite_list_role_audit(integer) to authenticated;
grant execute on function public.keysuite_manage_user_role(text,text,text,boolean) to authenticated;



-- Custom authority for Category and Price List maintenance.
create or replace function public.keysuite_save_product_pricelist_multiplier_v119(
  p_product_code text,p_currency text,p_multiplier numeric
)
returns table (product_code text,usd_multiplier numeric,rmb_multiplier numeric)
language plpgsql security definer set search_path=public
as $$
declare v_product text:=upper(trim(coalesce(p_product_code,'')));v_currency text:=upper(trim(coalesce(p_currency,'')));
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then raise exception 'Your role is not allowed to maintain Price List settings.'; end if;
  if v_product not in ('CHC','GWS') then raise exception 'Product must be CHC or GWS.'; end if;
  if v_currency not in ('USD','RMB') then raise exception 'Currency must be USD or RMB.'; end if;
  if p_multiplier is null or p_multiplier<=0 then raise exception 'Currency rate must be greater than zero.'; end if;
  update public.ks_app_settings s set
    chc_usd_multiplier=case when v_product='CHC' and v_currency='USD' then p_multiplier else s.chc_usd_multiplier end,
    chc_rmb_multiplier=case when v_product='CHC' and v_currency='RMB' then p_multiplier else s.chc_rmb_multiplier end,
    gws_usd_multiplier=case when v_product='GWS' and v_currency='USD' then p_multiplier else s.gws_usd_multiplier end,
    gws_rmb_multiplier=case when v_product='GWS' and v_currency='RMB' then p_multiplier else s.gws_rmb_multiplier end
  where s.id='default';
  if not found then raise exception 'KeySuite application settings were not found.'; end if;
  return query select v_product,
    case when v_product='CHC' then s.chc_usd_multiplier else s.gws_usd_multiplier end,
    case when v_product='CHC' then s.chc_rmb_multiplier else s.gws_rmb_multiplier end
  from public.ks_app_settings s where s.id='default';
end;
$$;

create or replace function public.keysuite_save_chc_product_price_v120(
  p_product_id text,p_currency text,p_chc_price numeric,p_chcs_price numeric,p_chcn_price numeric,
  p_chc_rarity text,p_chcs_rarity text,p_chcn_rarity text
)
returns table (product_id text,currency text,chc_price numeric,chcs_price numeric,chcn_price numeric,chc_rarity text,chcs_rarity text,chcn_rarity text)
language plpgsql security definer set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_currency,'')));
  v_chc_rarity text:=lower(trim(coalesce(p_chc_rarity,'common')));
  v_chcs_rarity text:=lower(trim(coalesce(p_chcs_rarity,'common')));
  v_chcn_rarity text:=lower(trim(coalesce(p_chcn_rarity,'common')));
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then raise exception 'Your role is not allowed to maintain product prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_chc_price is not null and p_chc_price<0 then raise exception 'CHC Price cannot be negative.'; end if;
  if p_chcs_price is not null and p_chcs_price<0 then raise exception 'CHCS Price cannot be negative.'; end if;
  if p_chcn_price is not null and p_chcn_price<0 then raise exception 'CHCN Price cannot be negative.'; end if;
  if v_chc_rarity not in ('common','many','rare') or v_chcs_rarity not in ('common','many','rare') or v_chcn_rarity not in ('common','many','rare') then raise exception 'Rarity is invalid.'; end if;
  update public.ks_products_chc p set
    chc_usd=case when v_currency='USD' then p_chc_price else p.chc_usd end,
    chcs_usd=case when v_currency='USD' then p_chcs_price else p.chcs_usd end,
    chcn_usd=case when v_currency='USD' then p_chcn_price else p.chcn_usd end,
    chc_rmb=case when v_currency='RMB' then p_chc_price else p.chc_rmb end,
    chcs_rmb=case when v_currency='RMB' then p_chcs_price else p.chcs_rmb end,
    chcn_rmb=case when v_currency='RMB' then p_chcn_price else p.chcn_rmb end,
    chc_myr=case when v_currency='MYR' then p_chc_price else p.chc_myr end,
    chcs_myr=case when v_currency='MYR' then p_chcs_price else p.chcs_myr end,
    chcn_myr=case when v_currency='MYR' then p_chcn_price else p.chcn_myr end,
    chc_rarity_usd=case when v_currency='USD' then v_chc_rarity else p.chc_rarity_usd end,
    chcs_rarity_usd=case when v_currency='USD' then v_chcs_rarity else p.chcs_rarity_usd end,
    chcn_rarity_usd=case when v_currency='USD' then v_chcn_rarity else p.chcn_rarity_usd end,
    chc_rarity_rmb=case when v_currency='RMB' then v_chc_rarity else p.chc_rarity_rmb end,
    chcs_rarity_rmb=case when v_currency='RMB' then v_chcs_rarity else p.chcs_rarity_rmb end,
    chcn_rarity_rmb=case when v_currency='RMB' then v_chcn_rarity else p.chcn_rarity_rmb end,
    chc_rarity_myr=case when v_currency='MYR' then v_chc_rarity else p.chc_rarity_myr end,
    chcs_rarity_myr=case when v_currency='MYR' then v_chcs_rarity else p.chcs_rarity_myr end,
    chcn_rarity_myr=case when v_currency='MYR' then v_chcn_rarity else p.chcn_rarity_myr end,
    updated_at=now()
  where p.id=p_product_id;
  if not found then raise exception 'CHC model was not found.'; end if;
  return query select p.id,v_currency,
    case v_currency when 'USD' then p.chc_usd when 'RMB' then p.chc_rmb else p.chc_myr end,
    case v_currency when 'USD' then p.chcs_usd when 'RMB' then p.chcs_rmb else p.chcs_myr end,
    case v_currency when 'USD' then p.chcn_usd when 'RMB' then p.chcn_rmb else p.chcn_myr end,
    case v_currency when 'USD' then p.chc_rarity_usd when 'RMB' then p.chc_rarity_rmb else p.chc_rarity_myr end,
    case v_currency when 'USD' then p.chcs_rarity_usd when 'RMB' then p.chcs_rarity_rmb else p.chcs_rarity_myr end,
    case v_currency when 'USD' then p.chcn_rarity_usd when 'RMB' then p.chcn_rarity_rmb else p.chcn_rarity_myr end
  from public.ks_products_chc p where p.id=p_product_id;
end;
$$;

create or replace function public.keysuite_save_gws_sku_price_v120(
  p_product_id text,p_currency text,p_price numeric,p_rarity text
)
returns table (product_id text,currency text,price numeric,rarity text)
language plpgsql security definer set search_path=public
as $$
declare v_currency text:=upper(trim(coalesce(p_currency,'')));v_rarity text:=lower(trim(coalesce(p_rarity,'common')));
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then raise exception 'Your role is not allowed to maintain product prices.'; end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_price is not null and p_price<0 then raise exception 'Price cannot be negative.'; end if;
  if v_rarity not in ('common','many','rare') then raise exception 'Rarity is invalid.'; end if;
  update public.ks_products_gws p set
    price_usd=case when v_currency='USD' then p_price else p.price_usd end,
    price_rmb=case when v_currency='RMB' then p_price else p.price_rmb end,
    price_myr=case when v_currency='MYR' then p_price else p.price_myr end,
    rarity_usd=case when v_currency='USD' then v_rarity else p.rarity_usd end,
    rarity_rmb=case when v_currency='RMB' then v_rarity else p.rarity_rmb end,
    rarity_myr=case when v_currency='MYR' then v_rarity else p.rarity_myr end,
    updated_at=now()
  where p.id=p_product_id and p.status='active';
  if not found then raise exception 'GWS Tank SKU was not found.'; end if;
  return query select p.id,v_currency,
    case v_currency when 'USD' then p.price_usd when 'RMB' then p.price_rmb else p.price_myr end,
    case v_currency when 'USD' then p.rarity_usd when 'RMB' then p.rarity_rmb else p.rarity_myr end
  from public.ks_products_gws p where p.id=p_product_id;
end;
$$;

create or replace function public.keysuite_manage_pricing_category_v119(
  p_category_id text,p_category_name text,p_product_code text,p_margin numeric,p_normal numeric,p_rare numeric,
  p_transport numeric,p_commission numeric,p_set_discount numeric,p_final_discount numeric,
  p_include_commission boolean,p_include_set_discount boolean,p_include_final_discount boolean,p_include_fuel_charge boolean
)
returns table (category_id text,category_name text,product_rules jsonb)
language plpgsql security definer set search_path=public
as $$
declare
  v_id text:=trim(coalesce(p_category_id,''));v_name text:=trim(coalesce(p_category_name,''));
  v_product text:=upper(trim(coalesce(p_product_code,'')));v_rule jsonb;v_defaults jsonb;
begin
  if public.keysuite_permission_level('manage_categories')<>'full' then raise exception 'Your role is not allowed to manage pricing categories.'; end if;
  if v_name='' then raise exception 'Category Name is required.'; end if;
  if v_product not in ('CHC','GWS') then raise exception 'Product must be CHC or GWS.'; end if;
  if p_margin is null or p_margin<0 or p_margin>=1 then raise exception 'Margin must be from 0%% to below 100%%.'; end if;
  if p_normal is null or p_normal<0 or p_normal>=1 then raise exception 'Normal must be from 0%% to below 100%%.'; end if;
  if p_rare is null or p_rare<0 or p_rare>=1 then raise exception 'Rare must be from 0%% to below 100%%.'; end if;
  if p_transport is null or p_transport<0 then raise exception 'Transport must be zero or more.'; end if;
  if p_commission is null or p_commission<0 or p_commission>=1 then raise exception 'Commission must be from 0%% to below 100%%.'; end if;
  if p_set_discount is null or p_set_discount<0 or p_set_discount>=1 then raise exception 'Set Discount must be from 0%% to below 100%%.'; end if;
  if p_final_discount is null or p_final_discount<0 or p_final_discount>=1 then raise exception 'Final Discount must be from 0%% to below 100%%.'; end if;
  if exists(select 1 from public.ks_pricing_categories pc where lower(pc.category_name)=lower(v_name) and (v_id='' or pc.id<>v_id)) then raise exception 'A pricing category with this name already exists.'; end if;
  v_rule:=jsonb_build_object('margin',p_margin,'normal',p_normal,'rare',p_rare,'transport',p_transport,'commission',p_commission,'set_discount',p_set_discount,'final_discount',p_final_discount,'include_commission',coalesce(p_include_commission,false),'include_set_discount',coalesce(p_include_set_discount,false),'include_final_discount',coalesce(p_include_final_discount,false),'include_fuel_charge',coalesce(p_include_fuel_charge,false));
  v_defaults:=jsonb_build_object('margin',0.38,'normal',0,'rare',0,'transport',30,'commission',0.03,'set_discount',0.068,'final_discount',0.08,'include_commission',true,'include_set_discount',true,'include_final_discount',true,'include_fuel_charge',true);
  if v_id='' then
    v_id:='CCID'||upper(substr(md5(clock_timestamp()::text||random()::text||v_name),1,12));
    insert into public.ks_pricing_categories(id,category_name,final_discount,set_discount,commission,chc_factor,transport,chc_margin,product_rules)
    values(v_id,v_name,case when v_product='CHC' then p_final_discount else 0.08 end,case when v_product='CHC' then p_set_discount else 0.068 end,case when v_product='CHC' then p_commission else 0.03 end,case when v_product='CHC' then p_margin else 0.38 end,case when v_product='CHC' then p_transport else 30 end,case when v_product='CHC' then p_margin else 0.38 end,jsonb_build_object('CHC',case when v_product='CHC' then v_rule else v_defaults end,'GWS',case when v_product='GWS' then v_rule else v_defaults end));
  else
    update public.ks_pricing_categories pc set category_name=v_name,product_rules=jsonb_set(coalesce(pc.product_rules,'{}'::jsonb),array[v_product],v_rule,true),final_discount=case when v_product='CHC' then p_final_discount else pc.final_discount end,set_discount=case when v_product='CHC' then p_set_discount else pc.set_discount end,commission=case when v_product='CHC' then p_commission else pc.commission end,chc_factor=case when v_product='CHC' then p_margin else pc.chc_factor end,chc_margin=case when v_product='CHC' then p_margin else pc.chc_margin end,transport=case when v_product='CHC' then p_transport else pc.transport end where pc.id=v_id;
    if not found then raise exception 'Pricing category was not found.'; end if;
  end if;
  return query select pc.id,pc.category_name,pc.product_rules from public.ks_pricing_categories pc where pc.id=v_id;
end;
$$;

create or replace function public.keysuite_save_fuel_price_v124(p_fuel_price numeric)
returns table(fuel_price numeric,fuel_base_price numeric)
language plpgsql security definer set search_path=public
as $$
begin
  if public.keysuite_permission_level('change_fuel_price')<>'full' then raise exception 'Your role is not allowed to change Fuel Price.'; end if;
  if p_fuel_price is null or p_fuel_price<0 then raise exception 'Fuel Price must be zero or more.'; end if;
  update public.ks_app_settings s set fuel_price=p_fuel_price where s.id='default';
  if not found then raise exception 'KeySuite application settings were not found.'; end if;
  return query select s.fuel_price,s.fuel_base_price from public.ks_app_settings s where s.id='default';
end;
$$;

create or replace function public.keysuite_assign_customer_pricing_category_v124(p_customer_id text,p_category_id text)
returns table(customer_id text,pricing_category_id text)
language plpgsql security definer set search_path=public
as $$
begin
  if public.keysuite_permission_level('company_pricing')<>'full' then raise exception 'Your role is not allowed to assign a Pricing Category.'; end if;
  if coalesce(trim(p_customer_id),'')='' then raise exception 'Customer is required.'; end if;
  if coalesce(trim(p_category_id),'')<>'' and not exists(select 1 from public.ks_pricing_categories pc where pc.id=p_category_id) then raise exception 'Pricing Category was not found.'; end if;
  update public.ks_customers c set pricing_category_id=nullif(trim(p_category_id),''),updated_at=now()
  where c.id::text=p_customer_id and c.company_id=public.keysuite_current_company_id();
  if not found then raise exception 'Customer was not found.'; end if;
  return query select c.id::text,c.pricing_category_id from public.ks_customers c where c.id::text=p_customer_id;
end;
$$;

revoke all on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) from public;
revoke all on function public.keysuite_save_chc_product_price_v120(text,text,numeric,numeric,numeric,text,text,text) from public;
revoke all on function public.keysuite_save_gws_sku_price_v120(text,text,numeric,text) from public;
revoke all on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
revoke all on function public.keysuite_save_fuel_price_v124(numeric) from public;
revoke all on function public.keysuite_assign_customer_pricing_category_v124(text,text) from public;
grant execute on function public.keysuite_save_product_pricelist_multiplier_v119(text,text,numeric) to authenticated;
grant execute on function public.keysuite_save_chc_product_price_v120(text,text,numeric,numeric,numeric,text,text,text) to authenticated;
grant execute on function public.keysuite_save_gws_sku_price_v120(text,text,numeric,text) to authenticated;
grant execute on function public.keysuite_manage_pricing_category_v119(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;
grant execute on function public.keysuite_save_fuel_price_v124(numeric) to authenticated;
grant execute on function public.keysuite_assign_customer_pricing_category_v124(text,text) to authenticated;



-- Customer access now follows the custom permission matrix.
drop policy if exists keysuite_customers_select on public.ks_customers;
create policy keysuite_customers_select
on public.ks_customers for select to authenticated
using (
  public.keysuite_has_access()
  and company_id=public.keysuite_current_company_id()
  and (
    public.keysuite_permission_level('view_customers') in ('all','full')
    or (public.keysuite_permission_level('view_customers') in ('assigned','own') and lower(assigned_user_email)=public.keysuite_current_email())
  )
);

drop policy if exists keysuite_customers_insert on public.ks_customers;
create policy keysuite_customers_insert
on public.ks_customers for insert to authenticated
with check (
  public.keysuite_has_access()
  and company_id=public.keysuite_current_company_id()
  and lower(created_by_email)=public.keysuite_current_email()
  and (
    (public.keysuite_permission_level('edit_customers') in ('all','full') and public.keysuite_user_in_current_company(assigned_user_email))
    or (public.keysuite_permission_level('edit_customers') in ('assigned','own') and lower(assigned_user_email)=public.keysuite_current_email())
  )
);

drop policy if exists keysuite_customers_update on public.ks_customers;
create policy keysuite_customers_update
on public.ks_customers for update to authenticated
using (
  public.keysuite_has_access()
  and company_id=public.keysuite_current_company_id()
  and (
    public.keysuite_permission_level('edit_customers') in ('all','full')
    or (public.keysuite_permission_level('edit_customers') in ('assigned','own') and lower(assigned_user_email)=public.keysuite_current_email())
  )
)
with check (
  company_id=public.keysuite_current_company_id()
  and (
    (public.keysuite_permission_level('edit_customers') in ('all','full') and public.keysuite_user_in_current_company(assigned_user_email))
    or (public.keysuite_permission_level('edit_customers') in ('assigned','own') and lower(assigned_user_email)=public.keysuite_current_email())
  )
);

notify pgrst,'reload schema';
commit;

-- KeySuite V1.13
-- Owner-only Key / Role security update.
-- Safe to run after the V1.12 migration and V1.12 email hotfix.

begin;

create or replace function public.keysuite_list_role_users()
returns table (
  email text,
  display_name text,
  role text,
  active boolean,
  auth_exists boolean,
  last_sign_in_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path=public,auth
as $$
begin
  if public.keysuite_current_role() <> 'owner' then
    raise exception 'Only the Owner can view role management.';
  end if;

  return query
  select
    a.email,
    coalesce(nullif(a.display_name,''),u.full_name,a.email) as display_name,
    lower(a.role) as role,
    a.active,
    exists(select 1 from auth.users au where lower(au.email)=lower(a.email)) as auth_exists,
    (select au.last_sign_in_at from auth.users au where lower(au.email)=lower(a.email) limit 1) as last_sign_in_at,
    a.created_at
  from public.ks_user_access a
  left join public.ks_company_users u on u.id=a.employee_id
  where a.company_id=public.keysuite_current_company_id()
  order by
    case lower(a.role) when 'owner' then 1 when 'admin' then 2 when 'user' then 3 when 'dealer' then 4 else 5 end,
    coalesce(nullif(a.display_name,''),u.full_name,a.email);
end;
$$;

create or replace function public.keysuite_list_role_audit(p_limit integer default 30)
returns table (
  target_email text,
  target_display_name text,
  old_role text,
  new_role text,
  old_active boolean,
  new_active boolean,
  changed_by_email text,
  changed_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if public.keysuite_current_role() <> 'owner' then
    raise exception 'Only the Owner can view role history.';
  end if;

  return query
  select
    a.target_email,a.target_display_name,a.old_role,a.new_role,
    a.old_active,a.new_active,a.changed_by_email,a.changed_at
  from public.ks_role_audit a
  where a.company_id=public.keysuite_current_company_id()
  order by a.changed_at desc
  limit greatest(1,least(coalesce(p_limit,30),100));
end;
$$;

create or replace function public.keysuite_manage_user_role(
  p_email text,
  p_display_name text,
  p_role text,
  p_active boolean default true
)
returns table (
  email text,
  display_name text,
  role text,
  active boolean,
  auth_exists boolean
)
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
  v_old_role text;
  v_old_active boolean;
  v_old_company text;
  v_employee_id text;
  v_existing boolean:=false;
  v_owner_count integer;
begin
  if v_actor_role <> 'owner' then
    raise exception 'Only the Owner can manage roles.';
  end if;
  if coalesce(v_company_id,'')='' then
    raise exception 'Your account has no company assignment.';
  end if;
  if v_email='' or position('@' in v_email)<2 then
    raise exception 'Enter a valid email address.';
  end if;
  if v_name='' then
    raise exception 'Display Name is required.';
  end if;
  if v_role not in ('owner','admin','user','dealer','viewer') then
    raise exception 'Invalid role.';
  end if;

  select a.role,a.active,a.company_id,a.employee_id
    into v_old_role,v_old_active,v_old_company,v_employee_id
  from public.ks_user_access a
  where lower(a.email)=v_email
  limit 1;
  v_existing:=found;

  if v_existing and v_old_company<>v_company_id then
    raise exception 'This email belongs to another company.';
  end if;

  if v_existing and lower(v_old_role)='owner' and coalesce(v_old_active,false)
     and (v_role<>'owner' or not coalesce(p_active,false)) then
    select count(*) into v_owner_count
    from public.ks_user_access a
    where a.company_id=v_company_id
      and lower(a.role)='owner'
      and a.active=true;

    if v_owner_count<=1 then
      raise exception 'The last active Owner cannot be removed or disabled.';
    end if;
  end if;

  if v_employee_id is null then
    select u.id into v_employee_id
    from public.ks_company_users u
    where u.company_id=v_company_id
      and lower(coalesce(u.email,''))=v_email
    limit 1;
  end if;

  if v_employee_id is null then
    v_employee_id:='EID-'||upper(substr(md5(v_company_id||':'||v_email),1,16));
    insert into public.ks_company_users(id,company_id,full_name,email)
    values(v_employee_id,v_company_id,v_name,v_email)
    on conflict(id) do update set
      full_name=excluded.full_name,
      email=excluded.email;
  else
    update public.ks_company_users
      set full_name=v_name,
          email=v_email
    where id=v_employee_id;
  end if;

  update public.ks_user_access a
     set employee_id=v_employee_id,
         company_id=v_company_id,
         role=v_role,
         display_name=v_name,
         active=coalesce(p_active,true)
   where lower(a.email)=v_email;

  if not found then
    insert into public.ks_user_access(
      email,employee_id,company_id,role,display_name,active
    ) values (
      v_email,v_employee_id,v_company_id,v_role,v_name,coalesce(p_active,true)
    );
  end if;

  if not v_existing
     or lower(coalesce(v_old_role,''))<>v_role
     or coalesce(v_old_active,false)<>coalesce(p_active,true) then
    insert into public.ks_role_audit(
      company_id,target_email,target_display_name,old_role,new_role,
      old_active,new_active,changed_by_email
    ) values (
      v_company_id,v_email,v_name,
      case when v_existing then lower(v_old_role) else null end,
      v_role,
      case when v_existing then v_old_active else null end,
      coalesce(p_active,true),v_actor_email
    );
  end if;

  return query
  select a.email,
         a.display_name,
         lower(a.role),
         a.active,
         exists(
           select 1
           from auth.users au
           where lower(au.email)=lower(a.email)
         )
  from public.ks_user_access a
  where lower(a.email)=v_email;
end;
$$;

revoke all on function public.keysuite_list_role_users() from public;
revoke all on function public.keysuite_list_role_audit(integer) from public;
revoke all on function public.keysuite_manage_user_role(text,text,text,boolean) from public;
grant execute on function public.keysuite_list_role_users() to authenticated;
grant execute on function public.keysuite_list_role_audit(integer) to authenticated;
grant execute on function public.keysuite_manage_user_role(text,text,text,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

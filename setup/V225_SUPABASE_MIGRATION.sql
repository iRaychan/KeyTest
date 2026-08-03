-- KeySuite V2.25
-- Owner-assigned quotation prefixes for Key > Role.
-- Run after V223_SUPABASE_MIGRATION.sql. V2.24 had no database migration.
begin;

alter table public.ks_user_profiles
  add column if not exists quotation_prefix text;

create unique index if not exists ks_user_profiles_quotation_prefix_uidx
  on public.ks_user_profiles ((lower(trim(quotation_prefix))))
  where nullif(trim(quotation_prefix),'') is not null;

create or replace function public.keysuite_list_quotation_prefixes_v225()
returns table(email text,quotation_prefix text)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can view quotation prefix assignments.';
  end if;
  return query
  select lower(a.email),upper(trim(p.quotation_prefix))
  from public.ks_user_access a
  left join public.ks_user_profiles p on lower(p.email)=lower(a.email)
  where a.company_id=public.keysuite_current_company_id()
  order by coalesce(nullif(a.display_name,''),a.email);
end;
$$;

create or replace function public.keysuite_assign_quotation_prefix_v225(
  p_email text,
  p_prefix text
)
returns table(email text,quotation_prefix text)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_actor_role text:=public.keysuite_current_role();
  v_company text:=public.keysuite_current_company_id();
  v_email text:=lower(trim(coalesce(p_email,'')));
  v_prefix text:=upper(trim(coalesce(p_prefix,'')));
  v_name text;
begin
  if v_actor_role<>'owner' then
    raise exception 'Only the Owner can assign or change quotation prefixes.';
  end if;
  if v_email='' or position('@' in v_email)<2 then raise exception 'Enter a valid user email.'; end if;
  if v_prefix<>'' and v_prefix!~'^[A-Z0-9]{1,8}$' then
    raise exception 'Quotation prefix must contain 1 to 8 letters or numbers only.';
  end if;

  select coalesce(nullif(a.display_name,''),u.full_name,a.email)
  into v_name
  from public.ks_user_access a
  left join public.ks_company_users u on u.id=a.employee_id
  where lower(a.email)=v_email and a.company_id=v_company
  limit 1;
  if not found then raise exception 'The selected user is not assigned to your company.'; end if;

  if v_prefix<>'' and exists(
    select 1 from public.ks_user_profiles p
    where lower(trim(coalesce(p.quotation_prefix,'')))=lower(v_prefix)
      and lower(p.email)<>v_email
  ) then
    raise exception 'Quotation prefix "%" is already used. Please choose another prefix.',v_prefix;
  end if;

  insert into public.ks_user_profiles(email,company_id,display_name,quotation_prefix,updated_at)
  values(v_email,v_company,coalesce(nullif(v_name,''),v_email),nullif(v_prefix,''),now())
  on conflict(email) do update set
    company_id=excluded.company_id,
    display_name=coalesce(nullif(public.ks_user_profiles.display_name,''),excluded.display_name),
    quotation_prefix=excluded.quotation_prefix,
    updated_at=now();

  return query select v_email,nullif(v_prefix,'');
exception
  when unique_violation then
    raise exception 'Quotation prefix "%" is already used. Please choose another prefix.',v_prefix;
end;
$$;

-- Prefixes are no longer self-service in User Settings.
revoke execute on function public.keysuite_save_quotation_prefix_v223(text) from authenticated;

create or replace function public.keysuite_next_quotation_reference_v223(
  p_requested_at timestamptz default now(),
  p_minimum_last_number integer default 0
)
returns table(
  quotation_reference text,
  quotation_prefix text,
  calendar_year integer,
  running_number integer
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_email text:=public.keysuite_current_email();
  v_prefix text;
  v_local_date date:=(coalesce(p_requested_at,now()) at time zone 'Asia/Kuala_Lumpur')::date;
  v_year integer;
  v_yymm text;
  v_number integer;
  v_floor integer:=greatest(0,coalesce(p_minimum_last_number,0));
begin
  if coalesce(v_email,'')='' then raise exception 'Your signed-in email could not be determined.'; end if;

  select upper(trim(p.quotation_prefix)) into v_prefix
  from public.ks_user_profiles p
  where lower(p.email)=v_email
  limit 1;
  if coalesce(v_prefix,'')='' then
    raise exception 'No quotation prefix has been assigned. Please contact the Owner.';
  end if;

  v_year:=extract(year from v_local_date)::integer;
  v_yymm:=to_char(v_local_date,'YYMM');

  insert into public.ks_quotation_sequences(user_email,calendar_year,last_number,updated_at)
  values(v_email,v_year,v_floor+1,now())
  on conflict(user_email,calendar_year) do update set
    last_number=greatest(public.ks_quotation_sequences.last_number,v_floor)+1,
    updated_at=now()
  returning last_number into v_number;

  return query select
    format('%s-%s-%s',v_prefix,v_yymm,lpad(v_number::text,4,'0')),
    v_prefix,v_year,v_number;
end;
$$;

revoke all on function public.keysuite_list_quotation_prefixes_v225() from public;
revoke all on function public.keysuite_assign_quotation_prefix_v225(text,text) from public;
grant execute on function public.keysuite_list_quotation_prefixes_v225() to authenticated;
grant execute on function public.keysuite_assign_quotation_prefix_v225(text,text) to authenticated;

commit;

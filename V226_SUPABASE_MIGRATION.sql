-- KeySuite V2.26
-- Corrected Owner prefix RPCs and quotation sequencing by assigned prefix + calendar year.
-- Run after V225_SUPABASE_MIGRATION.sql or the V2.25 prefix hotfixes.
-- Safe to run more than once.

begin;

alter table public.ks_user_profiles
  add column if not exists quotation_prefix text;

create table if not exists public.ks_quotation_prefix_sequences (
  quotation_prefix text not null,
  calendar_year integer not null check (calendar_year between 2000 and 9999),
  last_number integer not null default 0 check (last_number >= 0),
  updated_at timestamptz not null default now(),
  primary key (quotation_prefix, calendar_year)
);

alter table public.ks_quotation_prefix_sequences enable row level security;
revoke all on table public.ks_quotation_prefix_sequences from public, anon, authenticated;

-- Preserve the highest counters already allocated by older per-email sequencing.
do $$
begin
  if to_regclass('public.ks_quotation_sequences') is not null then
    execute $copy$
      insert into public.ks_quotation_prefix_sequences(quotation_prefix, calendar_year, last_number, updated_at)
      select upper(trim(profile.quotation_prefix)), sequence.calendar_year, max(sequence.last_number), now()
      from public.ks_quotation_sequences as sequence
      join public.ks_user_profiles as profile on lower(profile.email)=lower(sequence.user_email)
      where nullif(trim(profile.quotation_prefix),'') is not null
      group by upper(trim(profile.quotation_prefix)), sequence.calendar_year
      on conflict on constraint ks_quotation_prefix_sequences_pkey do update set
        last_number=greatest(public.ks_quotation_prefix_sequences.last_number, excluded.last_number),
        updated_at=now()
    $copy$;
  end if;
end;
$$;

create or replace function public.keysuite_list_quotation_prefixes_v225()
returns table(email text, quotation_prefix text)
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
  select lower(a.email)::text, nullif(upper(trim(profile.quotation_prefix)),'')::text
  from public.ks_user_access as a
  left join public.ks_user_profiles as profile on lower(profile.email)=lower(a.email)
  where a.company_id=public.keysuite_current_company_id()
  order by coalesce(nullif(a.display_name,''),a.email);
end;
$$;

create or replace function public.keysuite_assign_quotation_prefix_v225(p_email text,p_prefix text)
returns table(email text,quotation_prefix text)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_company text:=public.keysuite_current_company_id();
  v_email text:=lower(trim(coalesce(p_email,'')));
  v_prefix text:=upper(trim(coalesce(p_prefix,'')));
  v_name text;
begin
  if public.keysuite_current_role()<>'owner' then raise exception 'Only the Owner can assign or change quotation prefixes.'; end if;
  if v_email='' or position('@' in v_email)<2 then raise exception 'Enter a valid user email.'; end if;
  if v_prefix<>'' and v_prefix!~'^[A-Z0-9]{1,8}$' then raise exception 'Quotation prefix must contain 1 to 8 letters or numbers only.'; end if;

  select coalesce(nullif(a.display_name,''),u.full_name,a.email) into v_name
  from public.ks_user_access as a
  left join public.ks_company_users as u on u.id=a.employee_id
  where lower(a.email)=v_email and a.company_id=v_company
  limit 1;
  if not found then raise exception 'The selected user is not assigned to your company.'; end if;

  if v_prefix<>'' and exists(
    select 1 from public.ks_user_profiles as profile
    where lower(trim(coalesce(profile.quotation_prefix,'')))=lower(v_prefix)
      and lower(profile.email)<>v_email
  ) then raise exception 'Quotation prefix "%" is already used. Please choose another prefix.',v_prefix; end if;

  update public.ks_user_profiles as profile
  set company_id=v_company,
      display_name=coalesce(nullif(profile.display_name,''),coalesce(nullif(v_name,''),v_email)),
      quotation_prefix=nullif(v_prefix,''),
      updated_at=now()
  where lower(profile.email)=v_email;

  if not found then
    insert into public.ks_user_profiles(email,company_id,display_name,quotation_prefix,updated_at)
    values(v_email,v_company,coalesce(nullif(v_name,''),v_email),nullif(v_prefix,''),now());
  end if;

  return query select v_email::text,nullif(v_prefix,'')::text;
exception when unique_violation then
  raise exception 'Quotation prefix "%" is already used. Please choose another prefix.',v_prefix;
end;
$$;

create or replace function public.keysuite_next_quotation_reference_v223(
  p_requested_at timestamptz default now(),
  p_minimum_last_number integer default 0
)
returns table(quotation_reference text,quotation_prefix text,calendar_year integer,running_number integer)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_email text:=public.keysuite_current_email();
  v_prefix text;
  v_local_date date:=(coalesce(p_requested_at,now()) at time zone 'Asia/Kuala_Lumpur')::date;
  v_year integer:=extract(year from v_local_date)::integer;
  v_number integer;
  v_floor integer:=greatest(0,coalesce(p_minimum_last_number,0));
begin
  if coalesce(v_email,'')='' then raise exception 'Your signed-in email could not be determined.'; end if;
  select upper(trim(profile.quotation_prefix)) into v_prefix
  from public.ks_user_profiles as profile where lower(profile.email)=v_email limit 1;
  if coalesce(v_prefix,'')='' then raise exception 'No quotation prefix has been assigned. Please contact the Owner.'; end if;

  insert into public.ks_quotation_prefix_sequences(quotation_prefix,calendar_year,last_number,updated_at)
  values(v_prefix,v_year,v_floor+1,now())
  on conflict on constraint ks_quotation_prefix_sequences_pkey do update set
    last_number=greatest(public.ks_quotation_prefix_sequences.last_number,v_floor)+1,
    updated_at=now()
  returning last_number into v_number;

  return query select format('%s-%s-%s',v_prefix,to_char(v_local_date,'YYMM'),lpad(v_number::text,4,'0')),v_prefix,v_year,v_number;
end;
$$;

create or replace function public.keysuite_register_quotation_reference_v226(p_reference text)
returns table(quotation_prefix text,calendar_year integer,running_number integer)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_email text:=public.keysuite_current_email();
  v_assigned_prefix text;
  v_reference text:=upper(trim(coalesce(p_reference,'')));
  v_match text[];
  v_year integer;
  v_number integer;
begin
  if coalesce(v_email,'')='' then raise exception 'Your signed-in email could not be determined.'; end if;
  select upper(trim(profile.quotation_prefix)) into v_assigned_prefix
  from public.ks_user_profiles as profile where lower(profile.email)=v_email limit 1;
  if coalesce(v_assigned_prefix,'')='' then raise exception 'No quotation prefix has been assigned. Please contact the Owner.'; end if;

  v_match:=regexp_match(v_reference,'^([A-Z0-9]{1,8})-([0-9]{2})([0-9]{2})-([0-9]{1,4})(-V[0-9]+)?$');
  if v_match is null then raise exception 'Quotation number must use PREFIX-YYMM-0001 format.'; end if;
  if v_match[1]<>v_assigned_prefix then raise exception 'The quotation prefix is assigned by the Owner and cannot be amended.'; end if;
  if v_match[3]::integer not between 1 and 12 then raise exception 'Quotation YYMM contains an invalid month.'; end if;
  v_year:=2000+v_match[2]::integer;
  v_number:=v_match[4]::integer;
  if v_number<1 then raise exception 'Quotation running number must be at least 0001.'; end if;

  insert into public.ks_quotation_prefix_sequences(quotation_prefix,calendar_year,last_number,updated_at)
  values(v_assigned_prefix,v_year,v_number,now())
  on conflict on constraint ks_quotation_prefix_sequences_pkey do update set
    last_number=greatest(public.ks_quotation_prefix_sequences.last_number,v_number),
    updated_at=now();

  return query select v_assigned_prefix,v_year,v_number;
end;
$$;

revoke all on function public.keysuite_list_quotation_prefixes_v225() from public;
revoke all on function public.keysuite_assign_quotation_prefix_v225(text,text) from public;
revoke all on function public.keysuite_next_quotation_reference_v223(timestamptz,integer) from public;
revoke all on function public.keysuite_register_quotation_reference_v226(text) from public;
grant execute on function public.keysuite_list_quotation_prefixes_v225() to authenticated;
grant execute on function public.keysuite_assign_quotation_prefix_v225(text,text) to authenticated;
grant execute on function public.keysuite_next_quotation_reference_v223(timestamptz,integer) to authenticated;
grant execute on function public.keysuite_register_quotation_reference_v226(text) to authenticated;

do $$
begin
  if to_regprocedure('public.keysuite_save_quotation_prefix_v223(text)') is not null then
    execute 'revoke execute on function public.keysuite_save_quotation_prefix_v223(text) from authenticated';
  end if;
end;
$$;

commit;

-- Create the case-insensitive unique index only when existing assignments are clean.
do $$
begin
  if exists(
    select 1 from public.ks_user_profiles
    where nullif(trim(quotation_prefix),'') is not null
    group by lower(trim(quotation_prefix)) having count(*)>1
  ) then
    raise notice 'Duplicate quotation prefixes already exist; resolve them before creating the unique index.';
  else
    execute $index$
      create unique index if not exists ks_user_profiles_quotation_prefix_uidx
      on public.ks_user_profiles ((lower(trim(quotation_prefix))))
      where nullif(trim(quotation_prefix),'') is not null
    $index$;
  end if;
end;
$$;

notify pgrst,'reload schema';

select
  to_regprocedure('public.keysuite_list_quotation_prefixes_v225()') as list_prefixes_rpc,
  to_regprocedure('public.keysuite_assign_quotation_prefix_v225(text,text)') as assign_prefix_rpc,
  to_regprocedure('public.keysuite_next_quotation_reference_v223(timestamptz,integer)') as next_reference_rpc,
  to_regprocedure('public.keysuite_register_quotation_reference_v226(text)') as register_reference_rpc;

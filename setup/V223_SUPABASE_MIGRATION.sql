-- KeySuite V2.23
-- Per-user quotation references and Motor Price List (IE1 to IE5).
-- Run after V222_SUPABASE_MIGRATION.sql.
begin;

-- ---------------------------------------------------------------------------
-- 1. Per-user quotation prefix and annual running sequence
-- Format: [User Prefix]-[YYMM]-[Running Number]
-- The running number resets only when the calendar year changes.
-- ---------------------------------------------------------------------------
alter table public.ks_user_profiles
  add column if not exists quotation_prefix text;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='ks_user_profiles' and column_name='prefix'
  ) then
    execute $seed$
      update public.ks_user_profiles target
      set quotation_prefix=upper(trim(target.prefix))
      where nullif(trim(coalesce(target.quotation_prefix,'')),'') is null
        and upper(trim(coalesce(target.prefix,''))) ~ '^[A-Z0-9]{1,8}$'
        and (
          select count(*) from public.ks_user_profiles peer
          where lower(trim(coalesce(peer.prefix,'')))=lower(trim(coalesce(target.prefix,'')))
        )=1
    $seed$;
  end if;
end;
$$;

create unique index if not exists ks_user_profiles_quotation_prefix_uidx
  on public.ks_user_profiles ((lower(trim(quotation_prefix))))
  where nullif(trim(quotation_prefix),'') is not null;

create table if not exists public.ks_quotation_sequences (
  user_email text not null,
  calendar_year integer not null check (calendar_year between 2000 and 9999),
  last_number integer not null default 0 check (last_number>=0),
  updated_at timestamptz not null default now(),
  primary key(user_email,calendar_year)
);

alter table public.ks_quotation_sequences enable row level security;
revoke all on table public.ks_quotation_sequences from public,anon,authenticated;

create or replace function public.keysuite_get_quotation_prefix_v223()
returns table(quotation_prefix text)
language sql
stable
security definer
set search_path=public
as $$
  select upper(trim(p.quotation_prefix))
  from public.ks_user_profiles p
  where lower(p.email)=public.keysuite_current_email()
  limit 1
$$;

create or replace function public.keysuite_save_quotation_prefix_v223(p_prefix text)
returns table(quotation_prefix text)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_prefix text:=upper(trim(coalesce(p_prefix,'')));
  v_email text:=public.keysuite_current_email();
begin
  if coalesce(v_email,'')='' then
    raise exception 'Your signed-in email could not be determined.';
  end if;
  if v_prefix!~'^[A-Z0-9]{1,8}$' then
    raise exception 'Quotation prefix must contain 1 to 8 letters or numbers only.';
  end if;
  if exists(
    select 1 from public.ks_user_profiles p
    where lower(trim(coalesce(p.quotation_prefix,'')))=lower(v_prefix)
      and lower(p.email)<>v_email
  ) then
    raise exception 'Quotation prefix "%" is already used. Please choose another prefix.',v_prefix;
  end if;

  update public.ks_user_profiles p
  set quotation_prefix=v_prefix
  where lower(p.email)=v_email;
  if not found then raise exception 'Your user profile was not found.'; end if;

  return query select v_prefix;
exception
  when unique_violation then
    raise exception 'Quotation prefix "%" is already used. Please choose another prefix.',v_prefix;
end;
$$;

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
    raise exception 'Set your quotation prefix before creating a quotation.';
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

-- ---------------------------------------------------------------------------
-- 2. Motor product and price list
-- Prefixes: IE1=BM, IE2=2BM, IE3=3BM, IE4=4BM, IE5=5BM.
-- ---------------------------------------------------------------------------
alter table public.ks_app_settings
  add column if not exists motor_usd_multiplier numeric not null default 1,
  add column if not exists motor_rmb_multiplier numeric not null default 1;

update public.ks_app_settings
set motor_usd_multiplier=case
      when motor_usd_multiplier=1 then coalesce(chc_usd_multiplier,usd_multiplier,1)
      else motor_usd_multiplier end,
    motor_rmb_multiplier=case
      when motor_rmb_multiplier=1 then coalesce(chc_rmb_multiplier,rmb_multiplier,1)
      else motor_rmb_multiplier end
where id='default';

create table if not exists public.ks_products_motor (
  id text primary key,
  model text not null unique,
  efficiency_class text not null check (efficiency_class in ('IE1','IE2','IE3','IE4','IE5')),
  model_prefix text not null check (model_prefix in ('BM','2BM','3BM','4BM','5BM')),
  hp numeric not null check (hp>0),
  pole smallint not null check (pole>0),
  description text not null,
  source_sheet text,
  source_row integer,
  price_usd numeric not null default 0 check (price_usd>=0),
  price_rmb numeric not null default 0 check (price_rmb>=0),
  price_myr numeric not null default 0 check (price_myr>=0),
  rarity text not null default 'common' check (rarity in ('common','many','rare')),
  active boolean not null default true,
  updated_at timestamptz not null default now(),
  unique(efficiency_class,hp,pole)
);

alter table public.ks_products_motor enable row level security;
revoke all on table public.ks_products_motor from public,anon,authenticated;
drop policy if exists ks_products_motor_select on public.ks_products_motor;
create policy ks_products_motor_select on public.ks_products_motor
for select to authenticated using (public.keysuite_has_access());
grant select on table public.ks_products_motor to authenticated;

insert into public.ks_products_motor(
  id,model,efficiency_class,model_prefix,hp,pole,description,
  source_sheet,source_row,price_usd,price_rmb,price_myr,rarity,active
) values
('motor-ie1-0_25-2','BM0.25-2','IE1','BM',0.25,2,'0.25HP 2Pole IE1 Motor','IE1-260803',4,0,0,0,'common',true),
('motor-ie1-0_25-4','BM0.25-4','IE1','BM',0.25,4,'0.25HP 4Pole IE1 Motor','IE1-260803',4,0,0,0,'common',true),
('motor-ie1-0_25-6','BM0.25-6','IE1','BM',0.25,6,'0.25HP 6Pole IE1 Motor','IE1-260803',4,0,0,0,'common',true),
('motor-ie1-0_25-8','BM0.25-8','IE1','BM',0.25,8,'0.25HP 8Pole IE1 Motor','IE1-260803',4,0,0,0,'common',true),
('motor-ie1-0_33-2','BM0.33-2','IE1','BM',0.33,2,'0.33HP 2Pole IE1 Motor','IE1-260803',5,0,0,0,'common',true),
('motor-ie1-0_33-4','BM0.33-4','IE1','BM',0.33,4,'0.33HP 4Pole IE1 Motor','IE1-260803',5,0,0,0,'common',true),
('motor-ie1-0_33-6','BM0.33-6','IE1','BM',0.33,6,'0.33HP 6Pole IE1 Motor','IE1-260803',5,0,0,0,'common',true),
('motor-ie1-0_33-8','BM0.33-8','IE1','BM',0.33,8,'0.33HP 8Pole IE1 Motor','IE1-260803',5,0,0,0,'common',true),
('motor-ie1-0_5-2','BM0.5-2','IE1','BM',0.5,2,'0.5HP 2Pole IE1 Motor','IE1-260803',6,0,0,0,'common',true),
('motor-ie1-0_5-4','BM0.5-4','IE1','BM',0.5,4,'0.5HP 4Pole IE1 Motor','IE1-260803',6,0,0,0,'common',true),
('motor-ie1-0_5-6','BM0.5-6','IE1','BM',0.5,6,'0.5HP 6Pole IE1 Motor','IE1-260803',6,0,0,0,'common',true),
('motor-ie1-0_5-8','BM0.5-8','IE1','BM',0.5,8,'0.5HP 8Pole IE1 Motor','IE1-260803',6,0,0,0,'common',true),
('motor-ie1-0_75-2','BM0.75-2','IE1','BM',0.75,2,'0.75HP 2Pole IE1 Motor','IE1-260803',7,0,0,0,'common',true),
('motor-ie1-0_75-4','BM0.75-4','IE1','BM',0.75,4,'0.75HP 4Pole IE1 Motor','IE1-260803',7,0,0,0,'common',true),
('motor-ie1-0_75-6','BM0.75-6','IE1','BM',0.75,6,'0.75HP 6Pole IE1 Motor','IE1-260803',7,0,0,0,'common',true),
('motor-ie1-0_75-8','BM0.75-8','IE1','BM',0.75,8,'0.75HP 8Pole IE1 Motor','IE1-260803',7,0,0,0,'common',true),
('motor-ie1-1-2','BM1-2','IE1','BM',1,2,'1HP 2Pole IE1 Motor','IE1-260803',8,0,0,0,'common',true),
('motor-ie1-1-4','BM1-4','IE1','BM',1,4,'1HP 4Pole IE1 Motor','IE1-260803',8,0,0,0,'common',true),
('motor-ie1-1-6','BM1-6','IE1','BM',1,6,'1HP 6Pole IE1 Motor','IE1-260803',8,0,0,0,'common',true),
('motor-ie1-1-8','BM1-8','IE1','BM',1,8,'1HP 8Pole IE1 Motor','IE1-260803',8,0,0,0,'common',true),
('motor-ie1-1_5-2','BM1.5-2','IE1','BM',1.5,2,'1.5HP 2Pole IE1 Motor','IE1-260803',9,0,0,0,'common',true),
('motor-ie1-1_5-4','BM1.5-4','IE1','BM',1.5,4,'1.5HP 4Pole IE1 Motor','IE1-260803',9,0,0,0,'common',true),
('motor-ie1-1_5-6','BM1.5-6','IE1','BM',1.5,6,'1.5HP 6Pole IE1 Motor','IE1-260803',9,0,0,0,'common',true),
('motor-ie1-1_5-8','BM1.5-8','IE1','BM',1.5,8,'1.5HP 8Pole IE1 Motor','IE1-260803',9,0,0,0,'common',true),
('motor-ie1-2-2','BM2-2','IE1','BM',2,2,'2HP 2Pole IE1 Motor','IE1-260803',10,0,0,0,'common',true),
('motor-ie1-2-4','BM2-4','IE1','BM',2,4,'2HP 4Pole IE1 Motor','IE1-260803',10,0,0,0,'common',true),
('motor-ie1-2-6','BM2-6','IE1','BM',2,6,'2HP 6Pole IE1 Motor','IE1-260803',10,0,0,0,'common',true),
('motor-ie1-2-8','BM2-8','IE1','BM',2,8,'2HP 8Pole IE1 Motor','IE1-260803',10,0,0,0,'common',true),
('motor-ie1-3-2','BM3-2','IE1','BM',3,2,'3HP 2Pole IE1 Motor','IE1-260803',11,0,0,0,'common',true),
('motor-ie1-3-4','BM3-4','IE1','BM',3,4,'3HP 4Pole IE1 Motor','IE1-260803',11,0,0,0,'common',true),
('motor-ie1-3-6','BM3-6','IE1','BM',3,6,'3HP 6Pole IE1 Motor','IE1-260803',11,0,0,0,'common',true),
('motor-ie1-3-8','BM3-8','IE1','BM',3,8,'3HP 8Pole IE1 Motor','IE1-260803',11,0,0,0,'common',true),
('motor-ie1-4-2','BM4-2','IE1','BM',4,2,'4HP 2Pole IE1 Motor','IE1-260803',12,0,0,0,'common',true),
('motor-ie1-4-4','BM4-4','IE1','BM',4,4,'4HP 4Pole IE1 Motor','IE1-260803',12,0,0,0,'common',true),
('motor-ie1-4-6','BM4-6','IE1','BM',4,6,'4HP 6Pole IE1 Motor','IE1-260803',12,0,0,0,'common',true),
('motor-ie1-4-8','BM4-8','IE1','BM',4,8,'4HP 8Pole IE1 Motor','IE1-260803',12,0,0,0,'common',true),
('motor-ie1-5_5-2','BM5.5-2','IE1','BM',5.5,2,'5.5HP 2Pole IE1 Motor','IE1-260803',13,0,0,0,'common',true),
('motor-ie1-5_5-4','BM5.5-4','IE1','BM',5.5,4,'5.5HP 4Pole IE1 Motor','IE1-260803',13,0,0,0,'common',true),
('motor-ie1-5_5-6','BM5.5-6','IE1','BM',5.5,6,'5.5HP 6Pole IE1 Motor','IE1-260803',13,0,0,0,'common',true),
('motor-ie1-5_5-8','BM5.5-8','IE1','BM',5.5,8,'5.5HP 8Pole IE1 Motor','IE1-260803',13,0,0,0,'common',true),
('motor-ie1-7_5-2','BM7.5-2','IE1','BM',7.5,2,'7.5HP 2Pole IE1 Motor','IE1-260803',14,0,0,0,'common',true),
('motor-ie1-7_5-4','BM7.5-4','IE1','BM',7.5,4,'7.5HP 4Pole IE1 Motor','IE1-260803',14,0,0,0,'common',true),
('motor-ie1-7_5-6','BM7.5-6','IE1','BM',7.5,6,'7.5HP 6Pole IE1 Motor','IE1-260803',14,0,0,0,'common',true),
('motor-ie1-7_5-8','BM7.5-8','IE1','BM',7.5,8,'7.5HP 8Pole IE1 Motor','IE1-260803',14,0,0,0,'common',true),
('motor-ie1-10-2','BM10-2','IE1','BM',10,2,'10HP 2Pole IE1 Motor','IE1-260803',15,0,0,0,'common',true),
('motor-ie1-10-4','BM10-4','IE1','BM',10,4,'10HP 4Pole IE1 Motor','IE1-260803',15,0,0,0,'common',true),
('motor-ie1-10-6','BM10-6','IE1','BM',10,6,'10HP 6Pole IE1 Motor','IE1-260803',15,0,0,0,'common',true),
('motor-ie1-10-8','BM10-8','IE1','BM',10,8,'10HP 8Pole IE1 Motor','IE1-260803',15,0,0,0,'common',true),
('motor-ie1-15-2','BM15-2','IE1','BM',15,2,'15HP 2Pole IE1 Motor','IE1-260803',16,0,0,0,'common',true),
('motor-ie1-15-4','BM15-4','IE1','BM',15,4,'15HP 4Pole IE1 Motor','IE1-260803',16,0,0,0,'common',true),
('motor-ie1-15-6','BM15-6','IE1','BM',15,6,'15HP 6Pole IE1 Motor','IE1-260803',16,0,0,0,'common',true),
('motor-ie1-15-8','BM15-8','IE1','BM',15,8,'15HP 8Pole IE1 Motor','IE1-260803',16,0,0,0,'common',true),
('motor-ie1-20-2','BM20-2','IE1','BM',20,2,'20HP 2Pole IE1 Motor','IE1-260803',17,0,0,0,'common',true),
('motor-ie1-20-4','BM20-4','IE1','BM',20,4,'20HP 4Pole IE1 Motor','IE1-260803',17,0,0,0,'common',true),
('motor-ie1-20-6','BM20-6','IE1','BM',20,6,'20HP 6Pole IE1 Motor','IE1-260803',17,0,0,0,'common',true),
('motor-ie1-20-8','BM20-8','IE1','BM',20,8,'20HP 8Pole IE1 Motor','IE1-260803',17,0,0,0,'common',true),
('motor-ie1-25-2','BM25-2','IE1','BM',25,2,'25HP 2Pole IE1 Motor','IE1-260803',18,0,0,0,'common',true),
('motor-ie1-25-4','BM25-4','IE1','BM',25,4,'25HP 4Pole IE1 Motor','IE1-260803',18,0,0,0,'common',true),
('motor-ie1-25-6','BM25-6','IE1','BM',25,6,'25HP 6Pole IE1 Motor','IE1-260803',18,0,0,0,'common',true),
('motor-ie1-25-8','BM25-8','IE1','BM',25,8,'25HP 8Pole IE1 Motor','IE1-260803',18,0,0,0,'common',true),
('motor-ie1-30-2','BM30-2','IE1','BM',30,2,'30HP 2Pole IE1 Motor','IE1-260803',19,0,0,0,'common',true),
('motor-ie1-30-4','BM30-4','IE1','BM',30,4,'30HP 4Pole IE1 Motor','IE1-260803',19,0,0,0,'common',true),
('motor-ie1-30-6','BM30-6','IE1','BM',30,6,'30HP 6Pole IE1 Motor','IE1-260803',19,0,0,0,'common',true),
('motor-ie1-30-8','BM30-8','IE1','BM',30,8,'30HP 8Pole IE1 Motor','IE1-260803',19,0,0,0,'common',true),
('motor-ie1-40-2','BM40-2','IE1','BM',40,2,'40HP 2Pole IE1 Motor','IE1-260803',20,0,0,0,'common',true),
('motor-ie1-40-4','BM40-4','IE1','BM',40,4,'40HP 4Pole IE1 Motor','IE1-260803',20,0,0,0,'common',true),
('motor-ie1-40-6','BM40-6','IE1','BM',40,6,'40HP 6Pole IE1 Motor','IE1-260803',20,0,0,0,'common',true),
('motor-ie1-40-8','BM40-8','IE1','BM',40,8,'40HP 8Pole IE1 Motor','IE1-260803',20,0,0,0,'common',true),
('motor-ie1-50-2','BM50-2','IE1','BM',50,2,'50HP 2Pole IE1 Motor','IE1-260803',21,0,0,0,'common',true),
('motor-ie1-50-4','BM50-4','IE1','BM',50,4,'50HP 4Pole IE1 Motor','IE1-260803',21,0,0,0,'common',true),
('motor-ie1-50-6','BM50-6','IE1','BM',50,6,'50HP 6Pole IE1 Motor','IE1-260803',21,0,0,0,'common',true),
('motor-ie1-50-8','BM50-8','IE1','BM',50,8,'50HP 8Pole IE1 Motor','IE1-260803',21,0,0,0,'common',true),
('motor-ie1-60-2','BM60-2','IE1','BM',60,2,'60HP 2Pole IE1 Motor','IE1-260803',22,0,0,0,'common',true),
('motor-ie1-60-4','BM60-4','IE1','BM',60,4,'60HP 4Pole IE1 Motor','IE1-260803',22,0,0,0,'common',true),
('motor-ie1-60-6','BM60-6','IE1','BM',60,6,'60HP 6Pole IE1 Motor','IE1-260803',22,0,0,0,'common',true),
('motor-ie1-60-8','BM60-8','IE1','BM',60,8,'60HP 8Pole IE1 Motor','IE1-260803',22,0,0,0,'common',true),
('motor-ie1-75-2','BM75-2','IE1','BM',75,2,'75HP 2Pole IE1 Motor','IE1-260803',23,0,0,0,'common',true),
('motor-ie1-75-4','BM75-4','IE1','BM',75,4,'75HP 4Pole IE1 Motor','IE1-260803',23,0,0,0,'common',true),
('motor-ie1-75-6','BM75-6','IE1','BM',75,6,'75HP 6Pole IE1 Motor','IE1-260803',23,0,0,0,'common',true),
('motor-ie1-75-8','BM75-8','IE1','BM',75,8,'75HP 8Pole IE1 Motor','IE1-260803',23,0,0,0,'common',true),
('motor-ie1-100-2','BM100-2','IE1','BM',100,2,'100HP 2Pole IE1 Motor','IE1-260803',24,0,0,0,'common',true),
('motor-ie1-100-4','BM100-4','IE1','BM',100,4,'100HP 4Pole IE1 Motor','IE1-260803',24,0,0,0,'common',true),
('motor-ie1-100-6','BM100-6','IE1','BM',100,6,'100HP 6Pole IE1 Motor','IE1-260803',24,0,0,0,'common',true),
('motor-ie1-100-8','BM100-8','IE1','BM',100,8,'100HP 8Pole IE1 Motor','IE1-260803',24,0,0,0,'common',true),
('motor-ie1-125-2','BM125-2','IE1','BM',125,2,'125HP 2Pole IE1 Motor','IE1-260803',25,0,0,0,'common',true),
('motor-ie1-125-4','BM125-4','IE1','BM',125,4,'125HP 4Pole IE1 Motor','IE1-260803',25,0,0,0,'common',true),
('motor-ie1-125-6','BM125-6','IE1','BM',125,6,'125HP 6Pole IE1 Motor','IE1-260803',25,0,0,0,'common',true),
('motor-ie1-125-8','BM125-8','IE1','BM',125,8,'125HP 8Pole IE1 Motor','IE1-260803',25,0,0,0,'common',true),
('motor-ie1-150-2','BM150-2','IE1','BM',150,2,'150HP 2Pole IE1 Motor','IE1-260803',26,0,0,0,'common',true),
('motor-ie1-150-4','BM150-4','IE1','BM',150,4,'150HP 4Pole IE1 Motor','IE1-260803',26,0,0,0,'common',true),
('motor-ie1-150-6','BM150-6','IE1','BM',150,6,'150HP 6Pole IE1 Motor','IE1-260803',26,0,0,0,'common',true),
('motor-ie1-150-8','BM150-8','IE1','BM',150,8,'150HP 8Pole IE1 Motor','IE1-260803',26,0,0,0,'common',true),
('motor-ie1-175-2','BM175-2','IE1','BM',175,2,'175HP 2Pole IE1 Motor','IE1-260803',27,0,0,0,'common',true),
('motor-ie1-175-4','BM175-4','IE1','BM',175,4,'175HP 4Pole IE1 Motor','IE1-260803',27,0,0,0,'common',true),
('motor-ie1-175-6','BM175-6','IE1','BM',175,6,'175HP 6Pole IE1 Motor','IE1-260803',27,0,0,0,'common',true),
('motor-ie1-175-8','BM175-8','IE1','BM',175,8,'175HP 8Pole IE1 Motor','IE1-260803',27,0,0,0,'common',true),
('motor-ie1-200-2','BM200-2','IE1','BM',200,2,'200HP 2Pole IE1 Motor','IE1-260803',28,0,0,0,'common',true),
('motor-ie1-200-4','BM200-4','IE1','BM',200,4,'200HP 4Pole IE1 Motor','IE1-260803',28,0,0,0,'common',true),
('motor-ie1-200-6','BM200-6','IE1','BM',200,6,'200HP 6Pole IE1 Motor','IE1-260803',28,0,0,0,'common',true),
('motor-ie1-200-8','BM200-8','IE1','BM',200,8,'200HP 8Pole IE1 Motor','IE1-260803',28,0,0,0,'common',true),
('motor-ie1-215-2','BM215-2','IE1','BM',215,2,'215HP 2Pole IE1 Motor','IE1-260803',29,0,0,0,'common',true),
('motor-ie1-215-4','BM215-4','IE1','BM',215,4,'215HP 4Pole IE1 Motor','IE1-260803',29,0,0,0,'common',true),
('motor-ie1-215-6','BM215-6','IE1','BM',215,6,'215HP 6Pole IE1 Motor','IE1-260803',29,0,0,0,'common',true),
('motor-ie1-215-8','BM215-8','IE1','BM',215,8,'215HP 8Pole IE1 Motor','IE1-260803',29,0,0,0,'common',true),
('motor-ie1-250-2','BM250-2','IE1','BM',250,2,'250HP 2Pole IE1 Motor','IE1-260803',30,0,0,0,'common',true),
('motor-ie1-250-4','BM250-4','IE1','BM',250,4,'250HP 4Pole IE1 Motor','IE1-260803',30,0,0,0,'common',true),
('motor-ie1-250-6','BM250-6','IE1','BM',250,6,'250HP 6Pole IE1 Motor','IE1-260803',30,0,0,0,'common',true),
('motor-ie1-250-8','BM250-8','IE1','BM',250,8,'250HP 8Pole IE1 Motor','IE1-260803',30,0,0,0,'common',true),
('motor-ie1-270-2','BM270-2','IE1','BM',270,2,'270HP 2Pole IE1 Motor','IE1-260803',31,0,0,0,'common',true),
('motor-ie1-270-4','BM270-4','IE1','BM',270,4,'270HP 4Pole IE1 Motor','IE1-260803',31,0,0,0,'common',true),
('motor-ie1-270-6','BM270-6','IE1','BM',270,6,'270HP 6Pole IE1 Motor','IE1-260803',31,0,0,0,'common',true),
('motor-ie1-270-8','BM270-8','IE1','BM',270,8,'270HP 8Pole IE1 Motor','IE1-260803',31,0,0,0,'common',true),
('motor-ie1-300-2','BM300-2','IE1','BM',300,2,'300HP 2Pole IE1 Motor','IE1-260803',32,0,0,0,'common',true),
('motor-ie1-300-4','BM300-4','IE1','BM',300,4,'300HP 4Pole IE1 Motor','IE1-260803',32,0,0,0,'common',true),
('motor-ie1-300-6','BM300-6','IE1','BM',300,6,'300HP 6Pole IE1 Motor','IE1-260803',32,0,0,0,'common',true),
('motor-ie1-300-8','BM300-8','IE1','BM',300,8,'300HP 8Pole IE1 Motor','IE1-260803',32,0,0,0,'common',true),
('motor-ie1-335-2','BM335-2','IE1','BM',335,2,'335HP 2Pole IE1 Motor','IE1-260803',33,0,0,0,'common',true),
('motor-ie1-335-4','BM335-4','IE1','BM',335,4,'335HP 4Pole IE1 Motor','IE1-260803',33,0,0,0,'common',true),
('motor-ie1-335-6','BM335-6','IE1','BM',335,6,'335HP 6Pole IE1 Motor','IE1-260803',33,0,0,0,'common',true),
('motor-ie1-335-8','BM335-8','IE1','BM',335,8,'335HP 8Pole IE1 Motor','IE1-260803',33,0,0,0,'common',true),
('motor-ie1-375-2','BM375-2','IE1','BM',375,2,'375HP 2Pole IE1 Motor','IE1-260803',34,0,0,0,'common',true),
('motor-ie1-375-4','BM375-4','IE1','BM',375,4,'375HP 4Pole IE1 Motor','IE1-260803',34,0,0,0,'common',true),
('motor-ie1-375-6','BM375-6','IE1','BM',375,6,'375HP 6Pole IE1 Motor','IE1-260803',34,0,0,0,'common',true),
('motor-ie1-375-8','BM375-8','IE1','BM',375,8,'375HP 8Pole IE1 Motor','IE1-260803',34,0,0,0,'common',true),
('motor-ie1-420-2','BM420-2','IE1','BM',420,2,'420HP 2Pole IE1 Motor','IE1-260803',35,0,0,0,'common',true),
('motor-ie1-420-4','BM420-4','IE1','BM',420,4,'420HP 4Pole IE1 Motor','IE1-260803',35,0,0,0,'common',true),
('motor-ie1-420-6','BM420-6','IE1','BM',420,6,'420HP 6Pole IE1 Motor','IE1-260803',35,0,0,0,'common',true),
('motor-ie1-420-8','BM420-8','IE1','BM',420,8,'420HP 8Pole IE1 Motor','IE1-260803',35,0,0,0,'common',true),
('motor-ie1-500-2','BM500-2','IE1','BM',500,2,'500HP 2Pole IE1 Motor','IE1-260803',36,0,0,0,'common',true),
('motor-ie1-500-4','BM500-4','IE1','BM',500,4,'500HP 4Pole IE1 Motor','IE1-260803',36,0,0,0,'common',true),
('motor-ie1-500-6','BM500-6','IE1','BM',500,6,'500HP 6Pole IE1 Motor','IE1-260803',36,0,0,0,'common',true),
('motor-ie1-500-8','BM500-8','IE1','BM',500,8,'500HP 8Pole IE1 Motor','IE1-260803',36,0,0,0,'common',true),
('motor-ie1-600-2','BM600-2','IE1','BM',600,2,'600HP 2Pole IE1 Motor','IE1-260803',37,0,0,0,'common',true),
('motor-ie1-600-4','BM600-4','IE1','BM',600,4,'600HP 4Pole IE1 Motor','IE1-260803',37,0,0,0,'common',true),
('motor-ie1-600-6','BM600-6','IE1','BM',600,6,'600HP 6Pole IE1 Motor','IE1-260803',37,0,0,0,'common',true),
('motor-ie1-600-8','BM600-8','IE1','BM',600,8,'600HP 8Pole IE1 Motor','IE1-260803',37,0,0,0,'common',true),
('motor-ie2-0_25-2','2BM0.25-2','IE2','2BM',0.25,2,'0.25HP 2Pole IE2 Motor','IE2-260803',4,0,0,0,'common',true),
('motor-ie2-0_25-4','2BM0.25-4','IE2','2BM',0.25,4,'0.25HP 4Pole IE2 Motor','IE2-260803',4,0,0,0,'common',true),
('motor-ie2-0_25-6','2BM0.25-6','IE2','2BM',0.25,6,'0.25HP 6Pole IE2 Motor','IE2-260803',4,0,0,0,'common',true),
('motor-ie2-0_25-8','2BM0.25-8','IE2','2BM',0.25,8,'0.25HP 8Pole IE2 Motor','IE2-260803',4,0,0,0,'common',true),
('motor-ie2-0_33-2','2BM0.33-2','IE2','2BM',0.33,2,'0.33HP 2Pole IE2 Motor','IE2-260803',5,0,0,0,'common',true),
('motor-ie2-0_33-4','2BM0.33-4','IE2','2BM',0.33,4,'0.33HP 4Pole IE2 Motor','IE2-260803',5,0,0,0,'common',true),
('motor-ie2-0_33-6','2BM0.33-6','IE2','2BM',0.33,6,'0.33HP 6Pole IE2 Motor','IE2-260803',5,0,0,0,'common',true),
('motor-ie2-0_33-8','2BM0.33-8','IE2','2BM',0.33,8,'0.33HP 8Pole IE2 Motor','IE2-260803',5,0,0,0,'common',true),
('motor-ie2-0_5-2','2BM0.5-2','IE2','2BM',0.5,2,'0.5HP 2Pole IE2 Motor','IE2-260803',6,0,0,0,'common',true),
('motor-ie2-0_5-4','2BM0.5-4','IE2','2BM',0.5,4,'0.5HP 4Pole IE2 Motor','IE2-260803',6,0,0,0,'common',true),
('motor-ie2-0_5-6','2BM0.5-6','IE2','2BM',0.5,6,'0.5HP 6Pole IE2 Motor','IE2-260803',6,0,0,0,'common',true),
('motor-ie2-0_5-8','2BM0.5-8','IE2','2BM',0.5,8,'0.5HP 8Pole IE2 Motor','IE2-260803',6,0,0,0,'common',true),
('motor-ie2-0_75-2','2BM0.75-2','IE2','2BM',0.75,2,'0.75HP 2Pole IE2 Motor','IE2-260803',7,0,0,0,'common',true),
('motor-ie2-0_75-4','2BM0.75-4','IE2','2BM',0.75,4,'0.75HP 4Pole IE2 Motor','IE2-260803',7,0,0,0,'common',true),
('motor-ie2-0_75-6','2BM0.75-6','IE2','2BM',0.75,6,'0.75HP 6Pole IE2 Motor','IE2-260803',7,0,0,0,'common',true),
('motor-ie2-0_75-8','2BM0.75-8','IE2','2BM',0.75,8,'0.75HP 8Pole IE2 Motor','IE2-260803',7,0,0,0,'common',true),
('motor-ie2-1-2','2BM1-2','IE2','2BM',1,2,'1HP 2Pole IE2 Motor','IE2-260803',8,0,0,0,'common',true),
('motor-ie2-1-4','2BM1-4','IE2','2BM',1,4,'1HP 4Pole IE2 Motor','IE2-260803',8,0,0,0,'common',true),
('motor-ie2-1-6','2BM1-6','IE2','2BM',1,6,'1HP 6Pole IE2 Motor','IE2-260803',8,0,0,0,'common',true),
('motor-ie2-1-8','2BM1-8','IE2','2BM',1,8,'1HP 8Pole IE2 Motor','IE2-260803',8,0,0,0,'common',true),
('motor-ie2-1_5-2','2BM1.5-2','IE2','2BM',1.5,2,'1.5HP 2Pole IE2 Motor','IE2-260803',9,0,0,0,'common',true),
('motor-ie2-1_5-4','2BM1.5-4','IE2','2BM',1.5,4,'1.5HP 4Pole IE2 Motor','IE2-260803',9,0,0,0,'common',true),
('motor-ie2-1_5-6','2BM1.5-6','IE2','2BM',1.5,6,'1.5HP 6Pole IE2 Motor','IE2-260803',9,0,0,0,'common',true),
('motor-ie2-1_5-8','2BM1.5-8','IE2','2BM',1.5,8,'1.5HP 8Pole IE2 Motor','IE2-260803',9,0,0,0,'common',true),
('motor-ie2-2-2','2BM2-2','IE2','2BM',2,2,'2HP 2Pole IE2 Motor','IE2-260803',10,0,0,0,'common',true),
('motor-ie2-2-4','2BM2-4','IE2','2BM',2,4,'2HP 4Pole IE2 Motor','IE2-260803',10,0,0,0,'common',true),
('motor-ie2-2-6','2BM2-6','IE2','2BM',2,6,'2HP 6Pole IE2 Motor','IE2-260803',10,0,0,0,'common',true),
('motor-ie2-2-8','2BM2-8','IE2','2BM',2,8,'2HP 8Pole IE2 Motor','IE2-260803',10,0,0,0,'common',true),
('motor-ie2-3-2','2BM3-2','IE2','2BM',3,2,'3HP 2Pole IE2 Motor','IE2-260803',11,0,0,0,'common',true),
('motor-ie2-3-4','2BM3-4','IE2','2BM',3,4,'3HP 4Pole IE2 Motor','IE2-260803',11,0,0,0,'common',true),
('motor-ie2-3-6','2BM3-6','IE2','2BM',3,6,'3HP 6Pole IE2 Motor','IE2-260803',11,0,0,0,'common',true),
('motor-ie2-3-8','2BM3-8','IE2','2BM',3,8,'3HP 8Pole IE2 Motor','IE2-260803',11,0,0,0,'common',true),
('motor-ie2-4-2','2BM4-2','IE2','2BM',4,2,'4HP 2Pole IE2 Motor','IE2-260803',12,0,0,0,'common',true),
('motor-ie2-4-4','2BM4-4','IE2','2BM',4,4,'4HP 4Pole IE2 Motor','IE2-260803',12,0,0,0,'common',true),
('motor-ie2-4-6','2BM4-6','IE2','2BM',4,6,'4HP 6Pole IE2 Motor','IE2-260803',12,0,0,0,'common',true),
('motor-ie2-4-8','2BM4-8','IE2','2BM',4,8,'4HP 8Pole IE2 Motor','IE2-260803',12,0,0,0,'common',true),
('motor-ie2-5_5-2','2BM5.5-2','IE2','2BM',5.5,2,'5.5HP 2Pole IE2 Motor','IE2-260803',13,0,0,0,'common',true),
('motor-ie2-5_5-4','2BM5.5-4','IE2','2BM',5.5,4,'5.5HP 4Pole IE2 Motor','IE2-260803',13,0,0,0,'common',true),
('motor-ie2-5_5-6','2BM5.5-6','IE2','2BM',5.5,6,'5.5HP 6Pole IE2 Motor','IE2-260803',13,0,0,0,'common',true),
('motor-ie2-5_5-8','2BM5.5-8','IE2','2BM',5.5,8,'5.5HP 8Pole IE2 Motor','IE2-260803',13,0,0,0,'common',true),
('motor-ie2-7_5-2','2BM7.5-2','IE2','2BM',7.5,2,'7.5HP 2Pole IE2 Motor','IE2-260803',14,0,0,0,'common',true),
('motor-ie2-7_5-4','2BM7.5-4','IE2','2BM',7.5,4,'7.5HP 4Pole IE2 Motor','IE2-260803',14,0,0,0,'common',true),
('motor-ie2-7_5-6','2BM7.5-6','IE2','2BM',7.5,6,'7.5HP 6Pole IE2 Motor','IE2-260803',14,0,0,0,'common',true),
('motor-ie2-7_5-8','2BM7.5-8','IE2','2BM',7.5,8,'7.5HP 8Pole IE2 Motor','IE2-260803',14,0,0,0,'common',true),
('motor-ie2-10-2','2BM10-2','IE2','2BM',10,2,'10HP 2Pole IE2 Motor','IE2-260803',15,0,0,0,'common',true),
('motor-ie2-10-4','2BM10-4','IE2','2BM',10,4,'10HP 4Pole IE2 Motor','IE2-260803',15,0,0,0,'common',true),
('motor-ie2-10-6','2BM10-6','IE2','2BM',10,6,'10HP 6Pole IE2 Motor','IE2-260803',15,0,0,0,'common',true),
('motor-ie2-10-8','2BM10-8','IE2','2BM',10,8,'10HP 8Pole IE2 Motor','IE2-260803',15,0,0,0,'common',true),
('motor-ie2-15-2','2BM15-2','IE2','2BM',15,2,'15HP 2Pole IE2 Motor','IE2-260803',16,0,0,0,'common',true),
('motor-ie2-15-4','2BM15-4','IE2','2BM',15,4,'15HP 4Pole IE2 Motor','IE2-260803',16,0,0,0,'common',true),
('motor-ie2-15-6','2BM15-6','IE2','2BM',15,6,'15HP 6Pole IE2 Motor','IE2-260803',16,0,0,0,'common',true),
('motor-ie2-15-8','2BM15-8','IE2','2BM',15,8,'15HP 8Pole IE2 Motor','IE2-260803',16,0,0,0,'common',true),
('motor-ie2-20-2','2BM20-2','IE2','2BM',20,2,'20HP 2Pole IE2 Motor','IE2-260803',17,0,0,0,'common',true),
('motor-ie2-20-4','2BM20-4','IE2','2BM',20,4,'20HP 4Pole IE2 Motor','IE2-260803',17,0,0,0,'common',true),
('motor-ie2-20-6','2BM20-6','IE2','2BM',20,6,'20HP 6Pole IE2 Motor','IE2-260803',17,0,0,0,'common',true),
('motor-ie2-20-8','2BM20-8','IE2','2BM',20,8,'20HP 8Pole IE2 Motor','IE2-260803',17,0,0,0,'common',true),
('motor-ie2-25-2','2BM25-2','IE2','2BM',25,2,'25HP 2Pole IE2 Motor','IE2-260803',18,0,0,0,'common',true),
('motor-ie2-25-4','2BM25-4','IE2','2BM',25,4,'25HP 4Pole IE2 Motor','IE2-260803',18,0,0,0,'common',true),
('motor-ie2-25-6','2BM25-6','IE2','2BM',25,6,'25HP 6Pole IE2 Motor','IE2-260803',18,0,0,0,'common',true),
('motor-ie2-25-8','2BM25-8','IE2','2BM',25,8,'25HP 8Pole IE2 Motor','IE2-260803',18,0,0,0,'common',true),
('motor-ie2-30-2','2BM30-2','IE2','2BM',30,2,'30HP 2Pole IE2 Motor','IE2-260803',19,0,0,0,'common',true),
('motor-ie2-30-4','2BM30-4','IE2','2BM',30,4,'30HP 4Pole IE2 Motor','IE2-260803',19,0,0,0,'common',true),
('motor-ie2-30-6','2BM30-6','IE2','2BM',30,6,'30HP 6Pole IE2 Motor','IE2-260803',19,0,0,0,'common',true),
('motor-ie2-30-8','2BM30-8','IE2','2BM',30,8,'30HP 8Pole IE2 Motor','IE2-260803',19,0,0,0,'common',true),
('motor-ie2-40-2','2BM40-2','IE2','2BM',40,2,'40HP 2Pole IE2 Motor','IE2-260803',20,0,0,0,'common',true),
('motor-ie2-40-4','2BM40-4','IE2','2BM',40,4,'40HP 4Pole IE2 Motor','IE2-260803',20,0,0,0,'common',true),
('motor-ie2-40-6','2BM40-6','IE2','2BM',40,6,'40HP 6Pole IE2 Motor','IE2-260803',20,0,0,0,'common',true),
('motor-ie2-40-8','2BM40-8','IE2','2BM',40,8,'40HP 8Pole IE2 Motor','IE2-260803',20,0,0,0,'common',true),
('motor-ie2-50-2','2BM50-2','IE2','2BM',50,2,'50HP 2Pole IE2 Motor','IE2-260803',21,0,0,0,'common',true),
('motor-ie2-50-4','2BM50-4','IE2','2BM',50,4,'50HP 4Pole IE2 Motor','IE2-260803',21,0,0,0,'common',true),
('motor-ie2-50-6','2BM50-6','IE2','2BM',50,6,'50HP 6Pole IE2 Motor','IE2-260803',21,0,0,0,'common',true),
('motor-ie2-50-8','2BM50-8','IE2','2BM',50,8,'50HP 8Pole IE2 Motor','IE2-260803',21,0,0,0,'common',true),
('motor-ie2-60-2','2BM60-2','IE2','2BM',60,2,'60HP 2Pole IE2 Motor','IE2-260803',22,0,0,0,'common',true),
('motor-ie2-60-4','2BM60-4','IE2','2BM',60,4,'60HP 4Pole IE2 Motor','IE2-260803',22,0,0,0,'common',true),
('motor-ie2-60-6','2BM60-6','IE2','2BM',60,6,'60HP 6Pole IE2 Motor','IE2-260803',22,0,0,0,'common',true),
('motor-ie2-60-8','2BM60-8','IE2','2BM',60,8,'60HP 8Pole IE2 Motor','IE2-260803',22,0,0,0,'common',true),
('motor-ie2-75-2','2BM75-2','IE2','2BM',75,2,'75HP 2Pole IE2 Motor','IE2-260803',23,0,0,0,'common',true),
('motor-ie2-75-4','2BM75-4','IE2','2BM',75,4,'75HP 4Pole IE2 Motor','IE2-260803',23,0,0,0,'common',true),
('motor-ie2-75-6','2BM75-6','IE2','2BM',75,6,'75HP 6Pole IE2 Motor','IE2-260803',23,0,0,0,'common',true),
('motor-ie2-75-8','2BM75-8','IE2','2BM',75,8,'75HP 8Pole IE2 Motor','IE2-260803',23,0,0,0,'common',true),
('motor-ie2-100-2','2BM100-2','IE2','2BM',100,2,'100HP 2Pole IE2 Motor','IE2-260803',24,0,0,0,'common',true),
('motor-ie2-100-4','2BM100-4','IE2','2BM',100,4,'100HP 4Pole IE2 Motor','IE2-260803',24,0,0,0,'common',true),
('motor-ie2-100-6','2BM100-6','IE2','2BM',100,6,'100HP 6Pole IE2 Motor','IE2-260803',24,0,0,0,'common',true),
('motor-ie2-100-8','2BM100-8','IE2','2BM',100,8,'100HP 8Pole IE2 Motor','IE2-260803',24,0,0,0,'common',true),
('motor-ie2-125-2','2BM125-2','IE2','2BM',125,2,'125HP 2Pole IE2 Motor','IE2-260803',25,0,0,0,'common',true),
('motor-ie2-125-4','2BM125-4','IE2','2BM',125,4,'125HP 4Pole IE2 Motor','IE2-260803',25,0,0,0,'common',true),
('motor-ie2-125-6','2BM125-6','IE2','2BM',125,6,'125HP 6Pole IE2 Motor','IE2-260803',25,0,0,0,'common',true),
('motor-ie2-125-8','2BM125-8','IE2','2BM',125,8,'125HP 8Pole IE2 Motor','IE2-260803',25,0,0,0,'common',true),
('motor-ie2-150-2','2BM150-2','IE2','2BM',150,2,'150HP 2Pole IE2 Motor','IE2-260803',26,0,0,0,'common',true),
('motor-ie2-150-4','2BM150-4','IE2','2BM',150,4,'150HP 4Pole IE2 Motor','IE2-260803',26,0,0,0,'common',true),
('motor-ie2-150-6','2BM150-6','IE2','2BM',150,6,'150HP 6Pole IE2 Motor','IE2-260803',26,0,0,0,'common',true),
('motor-ie2-150-8','2BM150-8','IE2','2BM',150,8,'150HP 8Pole IE2 Motor','IE2-260803',26,0,0,0,'common',true),
('motor-ie2-175-2','2BM175-2','IE2','2BM',175,2,'175HP 2Pole IE2 Motor','IE2-260803',27,0,0,0,'common',true),
('motor-ie2-175-4','2BM175-4','IE2','2BM',175,4,'175HP 4Pole IE2 Motor','IE2-260803',27,0,0,0,'common',true),
('motor-ie2-175-6','2BM175-6','IE2','2BM',175,6,'175HP 6Pole IE2 Motor','IE2-260803',27,0,0,0,'common',true),
('motor-ie2-175-8','2BM175-8','IE2','2BM',175,8,'175HP 8Pole IE2 Motor','IE2-260803',27,0,0,0,'common',true),
('motor-ie2-200-2','2BM200-2','IE2','2BM',200,2,'200HP 2Pole IE2 Motor','IE2-260803',28,0,0,0,'common',true),
('motor-ie2-200-4','2BM200-4','IE2','2BM',200,4,'200HP 4Pole IE2 Motor','IE2-260803',28,0,0,0,'common',true),
('motor-ie2-200-6','2BM200-6','IE2','2BM',200,6,'200HP 6Pole IE2 Motor','IE2-260803',28,0,0,0,'common',true),
('motor-ie2-200-8','2BM200-8','IE2','2BM',200,8,'200HP 8Pole IE2 Motor','IE2-260803',28,0,0,0,'common',true),
('motor-ie2-215-2','2BM215-2','IE2','2BM',215,2,'215HP 2Pole IE2 Motor','IE2-260803',29,0,0,0,'common',true),
('motor-ie2-215-4','2BM215-4','IE2','2BM',215,4,'215HP 4Pole IE2 Motor','IE2-260803',29,0,0,0,'common',true),
('motor-ie2-215-6','2BM215-6','IE2','2BM',215,6,'215HP 6Pole IE2 Motor','IE2-260803',29,0,0,0,'common',true),
('motor-ie2-215-8','2BM215-8','IE2','2BM',215,8,'215HP 8Pole IE2 Motor','IE2-260803',29,0,0,0,'common',true),
('motor-ie2-250-2','2BM250-2','IE2','2BM',250,2,'250HP 2Pole IE2 Motor','IE2-260803',30,0,0,0,'common',true),
('motor-ie2-250-4','2BM250-4','IE2','2BM',250,4,'250HP 4Pole IE2 Motor','IE2-260803',30,0,0,0,'common',true),
('motor-ie2-250-6','2BM250-6','IE2','2BM',250,6,'250HP 6Pole IE2 Motor','IE2-260803',30,0,0,0,'common',true),
('motor-ie2-250-8','2BM250-8','IE2','2BM',250,8,'250HP 8Pole IE2 Motor','IE2-260803',30,0,0,0,'common',true),
('motor-ie2-270-2','2BM270-2','IE2','2BM',270,2,'270HP 2Pole IE2 Motor','IE2-260803',31,0,0,0,'common',true),
('motor-ie2-270-4','2BM270-4','IE2','2BM',270,4,'270HP 4Pole IE2 Motor','IE2-260803',31,0,0,0,'common',true),
('motor-ie2-270-6','2BM270-6','IE2','2BM',270,6,'270HP 6Pole IE2 Motor','IE2-260803',31,0,0,0,'common',true),
('motor-ie2-270-8','2BM270-8','IE2','2BM',270,8,'270HP 8Pole IE2 Motor','IE2-260803',31,0,0,0,'common',true),
('motor-ie2-300-2','2BM300-2','IE2','2BM',300,2,'300HP 2Pole IE2 Motor','IE2-260803',32,0,0,0,'common',true),
('motor-ie2-300-4','2BM300-4','IE2','2BM',300,4,'300HP 4Pole IE2 Motor','IE2-260803',32,0,0,0,'common',true),
('motor-ie2-300-6','2BM300-6','IE2','2BM',300,6,'300HP 6Pole IE2 Motor','IE2-260803',32,0,0,0,'common',true),
('motor-ie2-300-8','2BM300-8','IE2','2BM',300,8,'300HP 8Pole IE2 Motor','IE2-260803',32,0,0,0,'common',true),
('motor-ie2-335-2','2BM335-2','IE2','2BM',335,2,'335HP 2Pole IE2 Motor','IE2-260803',33,0,0,0,'common',true),
('motor-ie2-335-4','2BM335-4','IE2','2BM',335,4,'335HP 4Pole IE2 Motor','IE2-260803',33,0,0,0,'common',true),
('motor-ie2-335-6','2BM335-6','IE2','2BM',335,6,'335HP 6Pole IE2 Motor','IE2-260803',33,0,0,0,'common',true),
('motor-ie2-335-8','2BM335-8','IE2','2BM',335,8,'335HP 8Pole IE2 Motor','IE2-260803',33,0,0,0,'common',true),
('motor-ie2-375-2','2BM375-2','IE2','2BM',375,2,'375HP 2Pole IE2 Motor','IE2-260803',34,0,0,0,'common',true),
('motor-ie2-375-4','2BM375-4','IE2','2BM',375,4,'375HP 4Pole IE2 Motor','IE2-260803',34,0,0,0,'common',true),
('motor-ie2-375-6','2BM375-6','IE2','2BM',375,6,'375HP 6Pole IE2 Motor','IE2-260803',34,0,0,0,'common',true),
('motor-ie2-375-8','2BM375-8','IE2','2BM',375,8,'375HP 8Pole IE2 Motor','IE2-260803',34,0,0,0,'common',true),
('motor-ie2-420-2','2BM420-2','IE2','2BM',420,2,'420HP 2Pole IE2 Motor','IE2-260803',35,0,0,0,'common',true),
('motor-ie2-420-4','2BM420-4','IE2','2BM',420,4,'420HP 4Pole IE2 Motor','IE2-260803',35,0,0,0,'common',true),
('motor-ie2-420-6','2BM420-6','IE2','2BM',420,6,'420HP 6Pole IE2 Motor','IE2-260803',35,0,0,0,'common',true),
('motor-ie2-420-8','2BM420-8','IE2','2BM',420,8,'420HP 8Pole IE2 Motor','IE2-260803',35,0,0,0,'common',true),
('motor-ie2-500-2','2BM500-2','IE2','2BM',500,2,'500HP 2Pole IE2 Motor','IE2-260803',36,0,0,0,'common',true),
('motor-ie2-500-4','2BM500-4','IE2','2BM',500,4,'500HP 4Pole IE2 Motor','IE2-260803',36,0,0,0,'common',true),
('motor-ie2-500-6','2BM500-6','IE2','2BM',500,6,'500HP 6Pole IE2 Motor','IE2-260803',36,0,0,0,'common',true),
('motor-ie2-500-8','2BM500-8','IE2','2BM',500,8,'500HP 8Pole IE2 Motor','IE2-260803',36,0,0,0,'common',true),
('motor-ie2-600-2','2BM600-2','IE2','2BM',600,2,'600HP 2Pole IE2 Motor','IE2-260803',37,0,0,0,'common',true),
('motor-ie2-600-4','2BM600-4','IE2','2BM',600,4,'600HP 4Pole IE2 Motor','IE2-260803',37,0,0,0,'common',true),
('motor-ie2-600-6','2BM600-6','IE2','2BM',600,6,'600HP 6Pole IE2 Motor','IE2-260803',37,0,0,0,'common',true),
('motor-ie2-600-8','2BM600-8','IE2','2BM',600,8,'600HP 8Pole IE2 Motor','IE2-260803',37,0,0,0,'common',true),
('motor-ie3-0_25-2','3BM0.25-2','IE3','3BM',0.25,2,'0.25HP 2Pole IE3 Motor','IE3-260803',4,0,0,0,'common',true),
('motor-ie3-0_25-4','3BM0.25-4','IE3','3BM',0.25,4,'0.25HP 4Pole IE3 Motor','IE3-260803',4,0,0,0,'common',true),
('motor-ie3-0_25-6','3BM0.25-6','IE3','3BM',0.25,6,'0.25HP 6Pole IE3 Motor','IE3-260803',4,0,0,0,'common',true),
('motor-ie3-0_25-8','3BM0.25-8','IE3','3BM',0.25,8,'0.25HP 8Pole IE3 Motor','IE3-260803',4,0,0,0,'common',true),
('motor-ie3-0_33-2','3BM0.33-2','IE3','3BM',0.33,2,'0.33HP 2Pole IE3 Motor','IE3-260803',5,0,0,0,'common',true),
('motor-ie3-0_33-4','3BM0.33-4','IE3','3BM',0.33,4,'0.33HP 4Pole IE3 Motor','IE3-260803',5,0,0,0,'common',true),
('motor-ie3-0_33-6','3BM0.33-6','IE3','3BM',0.33,6,'0.33HP 6Pole IE3 Motor','IE3-260803',5,0,0,0,'common',true),
('motor-ie3-0_33-8','3BM0.33-8','IE3','3BM',0.33,8,'0.33HP 8Pole IE3 Motor','IE3-260803',5,0,0,0,'common',true),
('motor-ie3-0_5-2','3BM0.5-2','IE3','3BM',0.5,2,'0.5HP 2Pole IE3 Motor','IE3-260803',6,0,0,0,'common',true),
('motor-ie3-0_5-4','3BM0.5-4','IE3','3BM',0.5,4,'0.5HP 4Pole IE3 Motor','IE3-260803',6,0,0,0,'common',true),
('motor-ie3-0_5-6','3BM0.5-6','IE3','3BM',0.5,6,'0.5HP 6Pole IE3 Motor','IE3-260803',6,0,0,0,'common',true),
('motor-ie3-0_5-8','3BM0.5-8','IE3','3BM',0.5,8,'0.5HP 8Pole IE3 Motor','IE3-260803',6,0,0,0,'common',true),
('motor-ie3-0_75-2','3BM0.75-2','IE3','3BM',0.75,2,'0.75HP 2Pole IE3 Motor','IE3-260803',7,0,0,0,'common',true),
('motor-ie3-0_75-4','3BM0.75-4','IE3','3BM',0.75,4,'0.75HP 4Pole IE3 Motor','IE3-260803',7,0,0,0,'common',true),
('motor-ie3-0_75-6','3BM0.75-6','IE3','3BM',0.75,6,'0.75HP 6Pole IE3 Motor','IE3-260803',7,0,0,0,'common',true),
('motor-ie3-0_75-8','3BM0.75-8','IE3','3BM',0.75,8,'0.75HP 8Pole IE3 Motor','IE3-260803',7,0,0,0,'common',true),
('motor-ie3-1-2','3BM1-2','IE3','3BM',1,2,'1HP 2Pole IE3 Motor','IE3-260803',8,0,0,0,'common',true),
('motor-ie3-1-4','3BM1-4','IE3','3BM',1,4,'1HP 4Pole IE3 Motor','IE3-260803',8,0,0,0,'common',true),
('motor-ie3-1-6','3BM1-6','IE3','3BM',1,6,'1HP 6Pole IE3 Motor','IE3-260803',8,0,0,0,'common',true),
('motor-ie3-1-8','3BM1-8','IE3','3BM',1,8,'1HP 8Pole IE3 Motor','IE3-260803',8,0,0,0,'common',true),
('motor-ie3-1_5-2','3BM1.5-2','IE3','3BM',1.5,2,'1.5HP 2Pole IE3 Motor','IE3-260803',9,0,0,0,'common',true),
('motor-ie3-1_5-4','3BM1.5-4','IE3','3BM',1.5,4,'1.5HP 4Pole IE3 Motor','IE3-260803',9,0,0,0,'common',true),
('motor-ie3-1_5-6','3BM1.5-6','IE3','3BM',1.5,6,'1.5HP 6Pole IE3 Motor','IE3-260803',9,0,0,0,'common',true),
('motor-ie3-1_5-8','3BM1.5-8','IE3','3BM',1.5,8,'1.5HP 8Pole IE3 Motor','IE3-260803',9,0,0,0,'common',true),
('motor-ie3-2-2','3BM2-2','IE3','3BM',2,2,'2HP 2Pole IE3 Motor','IE3-260803',10,0,0,0,'common',true),
('motor-ie3-2-4','3BM2-4','IE3','3BM',2,4,'2HP 4Pole IE3 Motor','IE3-260803',10,0,0,0,'common',true),
('motor-ie3-2-6','3BM2-6','IE3','3BM',2,6,'2HP 6Pole IE3 Motor','IE3-260803',10,0,0,0,'common',true),
('motor-ie3-2-8','3BM2-8','IE3','3BM',2,8,'2HP 8Pole IE3 Motor','IE3-260803',10,0,0,0,'common',true),
('motor-ie3-3-2','3BM3-2','IE3','3BM',3,2,'3HP 2Pole IE3 Motor','IE3-260803',11,0,0,0,'common',true),
('motor-ie3-3-4','3BM3-4','IE3','3BM',3,4,'3HP 4Pole IE3 Motor','IE3-260803',11,0,0,0,'common',true),
('motor-ie3-3-6','3BM3-6','IE3','3BM',3,6,'3HP 6Pole IE3 Motor','IE3-260803',11,0,0,0,'common',true),
('motor-ie3-3-8','3BM3-8','IE3','3BM',3,8,'3HP 8Pole IE3 Motor','IE3-260803',11,0,0,0,'common',true),
('motor-ie3-4-2','3BM4-2','IE3','3BM',4,2,'4HP 2Pole IE3 Motor','IE3-260803',12,0,0,0,'common',true),
('motor-ie3-4-4','3BM4-4','IE3','3BM',4,4,'4HP 4Pole IE3 Motor','IE3-260803',12,0,0,0,'common',true),
('motor-ie3-4-6','3BM4-6','IE3','3BM',4,6,'4HP 6Pole IE3 Motor','IE3-260803',12,0,0,0,'common',true),
('motor-ie3-4-8','3BM4-8','IE3','3BM',4,8,'4HP 8Pole IE3 Motor','IE3-260803',12,0,0,0,'common',true),
('motor-ie3-5_5-2','3BM5.5-2','IE3','3BM',5.5,2,'5.5HP 2Pole IE3 Motor','IE3-260803',13,0,0,0,'common',true),
('motor-ie3-5_5-4','3BM5.5-4','IE3','3BM',5.5,4,'5.5HP 4Pole IE3 Motor','IE3-260803',13,0,0,0,'common',true),
('motor-ie3-5_5-6','3BM5.5-6','IE3','3BM',5.5,6,'5.5HP 6Pole IE3 Motor','IE3-260803',13,0,0,0,'common',true),
('motor-ie3-5_5-8','3BM5.5-8','IE3','3BM',5.5,8,'5.5HP 8Pole IE3 Motor','IE3-260803',13,0,0,0,'common',true),
('motor-ie3-7_5-2','3BM7.5-2','IE3','3BM',7.5,2,'7.5HP 2Pole IE3 Motor','IE3-260803',14,0,0,0,'common',true),
('motor-ie3-7_5-4','3BM7.5-4','IE3','3BM',7.5,4,'7.5HP 4Pole IE3 Motor','IE3-260803',14,0,0,0,'common',true),
('motor-ie3-7_5-6','3BM7.5-6','IE3','3BM',7.5,6,'7.5HP 6Pole IE3 Motor','IE3-260803',14,0,0,0,'common',true),
('motor-ie3-7_5-8','3BM7.5-8','IE3','3BM',7.5,8,'7.5HP 8Pole IE3 Motor','IE3-260803',14,0,0,0,'common',true),
('motor-ie3-10-2','3BM10-2','IE3','3BM',10,2,'10HP 2Pole IE3 Motor','IE3-260803',15,0,0,0,'common',true),
('motor-ie3-10-4','3BM10-4','IE3','3BM',10,4,'10HP 4Pole IE3 Motor','IE3-260803',15,0,0,0,'common',true),
('motor-ie3-10-6','3BM10-6','IE3','3BM',10,6,'10HP 6Pole IE3 Motor','IE3-260803',15,0,0,0,'common',true),
('motor-ie3-10-8','3BM10-8','IE3','3BM',10,8,'10HP 8Pole IE3 Motor','IE3-260803',15,0,0,0,'common',true),
('motor-ie3-15-2','3BM15-2','IE3','3BM',15,2,'15HP 2Pole IE3 Motor','IE3-260803',16,0,0,0,'common',true),
('motor-ie3-15-4','3BM15-4','IE3','3BM',15,4,'15HP 4Pole IE3 Motor','IE3-260803',16,0,0,0,'common',true),
('motor-ie3-15-6','3BM15-6','IE3','3BM',15,6,'15HP 6Pole IE3 Motor','IE3-260803',16,0,0,0,'common',true),
('motor-ie3-15-8','3BM15-8','IE3','3BM',15,8,'15HP 8Pole IE3 Motor','IE3-260803',16,0,0,0,'common',true),
('motor-ie3-20-2','3BM20-2','IE3','3BM',20,2,'20HP 2Pole IE3 Motor','IE3-260803',17,0,0,0,'common',true),
('motor-ie3-20-4','3BM20-4','IE3','3BM',20,4,'20HP 4Pole IE3 Motor','IE3-260803',17,0,0,0,'common',true),
('motor-ie3-20-6','3BM20-6','IE3','3BM',20,6,'20HP 6Pole IE3 Motor','IE3-260803',17,0,0,0,'common',true),
('motor-ie3-20-8','3BM20-8','IE3','3BM',20,8,'20HP 8Pole IE3 Motor','IE3-260803',17,0,0,0,'common',true),
('motor-ie3-25-2','3BM25-2','IE3','3BM',25,2,'25HP 2Pole IE3 Motor','IE3-260803',18,0,0,0,'common',true),
('motor-ie3-25-4','3BM25-4','IE3','3BM',25,4,'25HP 4Pole IE3 Motor','IE3-260803',18,0,0,0,'common',true),
('motor-ie3-25-6','3BM25-6','IE3','3BM',25,6,'25HP 6Pole IE3 Motor','IE3-260803',18,0,0,0,'common',true),
('motor-ie3-25-8','3BM25-8','IE3','3BM',25,8,'25HP 8Pole IE3 Motor','IE3-260803',18,0,0,0,'common',true),
('motor-ie3-30-2','3BM30-2','IE3','3BM',30,2,'30HP 2Pole IE3 Motor','IE3-260803',19,0,0,0,'common',true),
('motor-ie3-30-4','3BM30-4','IE3','3BM',30,4,'30HP 4Pole IE3 Motor','IE3-260803',19,0,0,0,'common',true),
('motor-ie3-30-6','3BM30-6','IE3','3BM',30,6,'30HP 6Pole IE3 Motor','IE3-260803',19,0,0,0,'common',true),
('motor-ie3-30-8','3BM30-8','IE3','3BM',30,8,'30HP 8Pole IE3 Motor','IE3-260803',19,0,0,0,'common',true),
('motor-ie3-40-2','3BM40-2','IE3','3BM',40,2,'40HP 2Pole IE3 Motor','IE3-260803',20,0,0,0,'common',true),
('motor-ie3-40-4','3BM40-4','IE3','3BM',40,4,'40HP 4Pole IE3 Motor','IE3-260803',20,0,0,0,'common',true),
('motor-ie3-40-6','3BM40-6','IE3','3BM',40,6,'40HP 6Pole IE3 Motor','IE3-260803',20,0,0,0,'common',true),
('motor-ie3-40-8','3BM40-8','IE3','3BM',40,8,'40HP 8Pole IE3 Motor','IE3-260803',20,0,0,0,'common',true),
('motor-ie3-50-2','3BM50-2','IE3','3BM',50,2,'50HP 2Pole IE3 Motor','IE3-260803',21,0,0,0,'common',true),
('motor-ie3-50-4','3BM50-4','IE3','3BM',50,4,'50HP 4Pole IE3 Motor','IE3-260803',21,0,0,0,'common',true),
('motor-ie3-50-6','3BM50-6','IE3','3BM',50,6,'50HP 6Pole IE3 Motor','IE3-260803',21,0,0,0,'common',true),
('motor-ie3-50-8','3BM50-8','IE3','3BM',50,8,'50HP 8Pole IE3 Motor','IE3-260803',21,0,0,0,'common',true),
('motor-ie3-60-2','3BM60-2','IE3','3BM',60,2,'60HP 2Pole IE3 Motor','IE3-260803',22,0,0,0,'common',true),
('motor-ie3-60-4','3BM60-4','IE3','3BM',60,4,'60HP 4Pole IE3 Motor','IE3-260803',22,0,0,0,'common',true),
('motor-ie3-60-6','3BM60-6','IE3','3BM',60,6,'60HP 6Pole IE3 Motor','IE3-260803',22,0,0,0,'common',true),
('motor-ie3-60-8','3BM60-8','IE3','3BM',60,8,'60HP 8Pole IE3 Motor','IE3-260803',22,0,0,0,'common',true),
('motor-ie3-75-2','3BM75-2','IE3','3BM',75,2,'75HP 2Pole IE3 Motor','IE3-260803',23,0,0,0,'common',true),
('motor-ie3-75-4','3BM75-4','IE3','3BM',75,4,'75HP 4Pole IE3 Motor','IE3-260803',23,0,0,0,'common',true),
('motor-ie3-75-6','3BM75-6','IE3','3BM',75,6,'75HP 6Pole IE3 Motor','IE3-260803',23,0,0,0,'common',true),
('motor-ie3-75-8','3BM75-8','IE3','3BM',75,8,'75HP 8Pole IE3 Motor','IE3-260803',23,0,0,0,'common',true),
('motor-ie3-100-2','3BM100-2','IE3','3BM',100,2,'100HP 2Pole IE3 Motor','IE3-260803',24,0,0,0,'common',true),
('motor-ie3-100-4','3BM100-4','IE3','3BM',100,4,'100HP 4Pole IE3 Motor','IE3-260803',24,0,0,0,'common',true),
('motor-ie3-100-6','3BM100-6','IE3','3BM',100,6,'100HP 6Pole IE3 Motor','IE3-260803',24,0,0,0,'common',true),
('motor-ie3-100-8','3BM100-8','IE3','3BM',100,8,'100HP 8Pole IE3 Motor','IE3-260803',24,0,0,0,'common',true),
('motor-ie3-125-2','3BM125-2','IE3','3BM',125,2,'125HP 2Pole IE3 Motor','IE3-260803',25,0,0,0,'common',true),
('motor-ie3-125-4','3BM125-4','IE3','3BM',125,4,'125HP 4Pole IE3 Motor','IE3-260803',25,0,0,0,'common',true),
('motor-ie3-125-6','3BM125-6','IE3','3BM',125,6,'125HP 6Pole IE3 Motor','IE3-260803',25,0,0,0,'common',true),
('motor-ie3-125-8','3BM125-8','IE3','3BM',125,8,'125HP 8Pole IE3 Motor','IE3-260803',25,0,0,0,'common',true),
('motor-ie3-150-2','3BM150-2','IE3','3BM',150,2,'150HP 2Pole IE3 Motor','IE3-260803',26,0,0,0,'common',true),
('motor-ie3-150-4','3BM150-4','IE3','3BM',150,4,'150HP 4Pole IE3 Motor','IE3-260803',26,0,0,0,'common',true),
('motor-ie3-150-6','3BM150-6','IE3','3BM',150,6,'150HP 6Pole IE3 Motor','IE3-260803',26,0,0,0,'common',true),
('motor-ie3-150-8','3BM150-8','IE3','3BM',150,8,'150HP 8Pole IE3 Motor','IE3-260803',26,0,0,0,'common',true),
('motor-ie3-175-2','3BM175-2','IE3','3BM',175,2,'175HP 2Pole IE3 Motor','IE3-260803',27,0,0,0,'common',true),
('motor-ie3-175-4','3BM175-4','IE3','3BM',175,4,'175HP 4Pole IE3 Motor','IE3-260803',27,0,0,0,'common',true),
('motor-ie3-175-6','3BM175-6','IE3','3BM',175,6,'175HP 6Pole IE3 Motor','IE3-260803',27,0,0,0,'common',true),
('motor-ie3-175-8','3BM175-8','IE3','3BM',175,8,'175HP 8Pole IE3 Motor','IE3-260803',27,0,0,0,'common',true),
('motor-ie3-200-2','3BM200-2','IE3','3BM',200,2,'200HP 2Pole IE3 Motor','IE3-260803',28,0,0,0,'common',true),
('motor-ie3-200-4','3BM200-4','IE3','3BM',200,4,'200HP 4Pole IE3 Motor','IE3-260803',28,0,0,0,'common',true),
('motor-ie3-200-6','3BM200-6','IE3','3BM',200,6,'200HP 6Pole IE3 Motor','IE3-260803',28,0,0,0,'common',true),
('motor-ie3-200-8','3BM200-8','IE3','3BM',200,8,'200HP 8Pole IE3 Motor','IE3-260803',28,0,0,0,'common',true),
('motor-ie3-215-2','3BM215-2','IE3','3BM',215,2,'215HP 2Pole IE3 Motor','IE3-260803',29,0,0,0,'common',true),
('motor-ie3-215-4','3BM215-4','IE3','3BM',215,4,'215HP 4Pole IE3 Motor','IE3-260803',29,0,0,0,'common',true),
('motor-ie3-215-6','3BM215-6','IE3','3BM',215,6,'215HP 6Pole IE3 Motor','IE3-260803',29,0,0,0,'common',true),
('motor-ie3-215-8','3BM215-8','IE3','3BM',215,8,'215HP 8Pole IE3 Motor','IE3-260803',29,0,0,0,'common',true),
('motor-ie3-250-2','3BM250-2','IE3','3BM',250,2,'250HP 2Pole IE3 Motor','IE3-260803',30,0,0,0,'common',true),
('motor-ie3-250-4','3BM250-4','IE3','3BM',250,4,'250HP 4Pole IE3 Motor','IE3-260803',30,0,0,0,'common',true),
('motor-ie3-250-6','3BM250-6','IE3','3BM',250,6,'250HP 6Pole IE3 Motor','IE3-260803',30,0,0,0,'common',true),
('motor-ie3-250-8','3BM250-8','IE3','3BM',250,8,'250HP 8Pole IE3 Motor','IE3-260803',30,0,0,0,'common',true),
('motor-ie3-270-2','3BM270-2','IE3','3BM',270,2,'270HP 2Pole IE3 Motor','IE3-260803',31,0,0,0,'common',true),
('motor-ie3-270-4','3BM270-4','IE3','3BM',270,4,'270HP 4Pole IE3 Motor','IE3-260803',31,0,0,0,'common',true),
('motor-ie3-270-6','3BM270-6','IE3','3BM',270,6,'270HP 6Pole IE3 Motor','IE3-260803',31,0,0,0,'common',true),
('motor-ie3-270-8','3BM270-8','IE3','3BM',270,8,'270HP 8Pole IE3 Motor','IE3-260803',31,0,0,0,'common',true),
('motor-ie3-300-2','3BM300-2','IE3','3BM',300,2,'300HP 2Pole IE3 Motor','IE3-260803',32,0,0,0,'common',true),
('motor-ie3-300-4','3BM300-4','IE3','3BM',300,4,'300HP 4Pole IE3 Motor','IE3-260803',32,0,0,0,'common',true),
('motor-ie3-300-6','3BM300-6','IE3','3BM',300,6,'300HP 6Pole IE3 Motor','IE3-260803',32,0,0,0,'common',true),
('motor-ie3-300-8','3BM300-8','IE3','3BM',300,8,'300HP 8Pole IE3 Motor','IE3-260803',32,0,0,0,'common',true),
('motor-ie3-335-2','3BM335-2','IE3','3BM',335,2,'335HP 2Pole IE3 Motor','IE3-260803',33,0,0,0,'common',true),
('motor-ie3-335-4','3BM335-4','IE3','3BM',335,4,'335HP 4Pole IE3 Motor','IE3-260803',33,0,0,0,'common',true),
('motor-ie3-335-6','3BM335-6','IE3','3BM',335,6,'335HP 6Pole IE3 Motor','IE3-260803',33,0,0,0,'common',true),
('motor-ie3-335-8','3BM335-8','IE3','3BM',335,8,'335HP 8Pole IE3 Motor','IE3-260803',33,0,0,0,'common',true),
('motor-ie3-375-2','3BM375-2','IE3','3BM',375,2,'375HP 2Pole IE3 Motor','IE3-260803',34,0,0,0,'common',true),
('motor-ie3-375-4','3BM375-4','IE3','3BM',375,4,'375HP 4Pole IE3 Motor','IE3-260803',34,0,0,0,'common',true),
('motor-ie3-375-6','3BM375-6','IE3','3BM',375,6,'375HP 6Pole IE3 Motor','IE3-260803',34,0,0,0,'common',true),
('motor-ie3-375-8','3BM375-8','IE3','3BM',375,8,'375HP 8Pole IE3 Motor','IE3-260803',34,0,0,0,'common',true),
('motor-ie3-420-2','3BM420-2','IE3','3BM',420,2,'420HP 2Pole IE3 Motor','IE3-260803',35,0,0,0,'common',true),
('motor-ie3-420-4','3BM420-4','IE3','3BM',420,4,'420HP 4Pole IE3 Motor','IE3-260803',35,0,0,0,'common',true),
('motor-ie3-420-6','3BM420-6','IE3','3BM',420,6,'420HP 6Pole IE3 Motor','IE3-260803',35,0,0,0,'common',true),
('motor-ie3-420-8','3BM420-8','IE3','3BM',420,8,'420HP 8Pole IE3 Motor','IE3-260803',35,0,0,0,'common',true),
('motor-ie3-500-2','3BM500-2','IE3','3BM',500,2,'500HP 2Pole IE3 Motor','IE3-260803',36,0,0,0,'common',true),
('motor-ie3-500-4','3BM500-4','IE3','3BM',500,4,'500HP 4Pole IE3 Motor','IE3-260803',36,0,0,0,'common',true),
('motor-ie3-500-6','3BM500-6','IE3','3BM',500,6,'500HP 6Pole IE3 Motor','IE3-260803',36,0,0,0,'common',true),
('motor-ie3-500-8','3BM500-8','IE3','3BM',500,8,'500HP 8Pole IE3 Motor','IE3-260803',36,0,0,0,'common',true),
('motor-ie3-600-2','3BM600-2','IE3','3BM',600,2,'600HP 2Pole IE3 Motor','IE3-260803',37,0,0,0,'common',true),
('motor-ie3-600-4','3BM600-4','IE3','3BM',600,4,'600HP 4Pole IE3 Motor','IE3-260803',37,0,0,0,'common',true),
('motor-ie3-600-6','3BM600-6','IE3','3BM',600,6,'600HP 6Pole IE3 Motor','IE3-260803',37,0,0,0,'common',true),
('motor-ie3-600-8','3BM600-8','IE3','3BM',600,8,'600HP 8Pole IE3 Motor','IE3-260803',37,0,0,0,'common',true),
('motor-ie4-0_25-2','4BM0.25-2','IE4','4BM',0.25,2,'0.25HP 2Pole IE4 Motor','IE4-260803',4,0,0,0,'common',true),
('motor-ie4-0_25-4','4BM0.25-4','IE4','4BM',0.25,4,'0.25HP 4Pole IE4 Motor','IE4-260803',4,0,0,0,'common',true),
('motor-ie4-0_25-6','4BM0.25-6','IE4','4BM',0.25,6,'0.25HP 6Pole IE4 Motor','IE4-260803',4,0,0,0,'common',true),
('motor-ie4-0_25-8','4BM0.25-8','IE4','4BM',0.25,8,'0.25HP 8Pole IE4 Motor','IE4-260803',4,0,0,0,'common',true),
('motor-ie4-0_33-2','4BM0.33-2','IE4','4BM',0.33,2,'0.33HP 2Pole IE4 Motor','IE4-260803',5,0,0,0,'common',true),
('motor-ie4-0_33-4','4BM0.33-4','IE4','4BM',0.33,4,'0.33HP 4Pole IE4 Motor','IE4-260803',5,0,0,0,'common',true),
('motor-ie4-0_33-6','4BM0.33-6','IE4','4BM',0.33,6,'0.33HP 6Pole IE4 Motor','IE4-260803',5,0,0,0,'common',true),
('motor-ie4-0_33-8','4BM0.33-8','IE4','4BM',0.33,8,'0.33HP 8Pole IE4 Motor','IE4-260803',5,0,0,0,'common',true),
('motor-ie4-0_5-2','4BM0.5-2','IE4','4BM',0.5,2,'0.5HP 2Pole IE4 Motor','IE4-260803',6,0,0,0,'common',true),
('motor-ie4-0_5-4','4BM0.5-4','IE4','4BM',0.5,4,'0.5HP 4Pole IE4 Motor','IE4-260803',6,0,0,0,'common',true),
('motor-ie4-0_5-6','4BM0.5-6','IE4','4BM',0.5,6,'0.5HP 6Pole IE4 Motor','IE4-260803',6,0,0,0,'common',true),
('motor-ie4-0_5-8','4BM0.5-8','IE4','4BM',0.5,8,'0.5HP 8Pole IE4 Motor','IE4-260803',6,0,0,0,'common',true),
('motor-ie4-0_75-2','4BM0.75-2','IE4','4BM',0.75,2,'0.75HP 2Pole IE4 Motor','IE4-260803',7,0,0,0,'common',true),
('motor-ie4-0_75-4','4BM0.75-4','IE4','4BM',0.75,4,'0.75HP 4Pole IE4 Motor','IE4-260803',7,0,0,0,'common',true),
('motor-ie4-0_75-6','4BM0.75-6','IE4','4BM',0.75,6,'0.75HP 6Pole IE4 Motor','IE4-260803',7,0,0,0,'common',true),
('motor-ie4-0_75-8','4BM0.75-8','IE4','4BM',0.75,8,'0.75HP 8Pole IE4 Motor','IE4-260803',7,0,0,0,'common',true),
('motor-ie4-1-2','4BM1-2','IE4','4BM',1,2,'1HP 2Pole IE4 Motor','IE4-260803',8,0,0,0,'common',true),
('motor-ie4-1-4','4BM1-4','IE4','4BM',1,4,'1HP 4Pole IE4 Motor','IE4-260803',8,0,0,0,'common',true),
('motor-ie4-1-6','4BM1-6','IE4','4BM',1,6,'1HP 6Pole IE4 Motor','IE4-260803',8,0,0,0,'common',true),
('motor-ie4-1-8','4BM1-8','IE4','4BM',1,8,'1HP 8Pole IE4 Motor','IE4-260803',8,0,0,0,'common',true),
('motor-ie4-1_5-2','4BM1.5-2','IE4','4BM',1.5,2,'1.5HP 2Pole IE4 Motor','IE4-260803',9,0,0,0,'common',true),
('motor-ie4-1_5-4','4BM1.5-4','IE4','4BM',1.5,4,'1.5HP 4Pole IE4 Motor','IE4-260803',9,0,0,0,'common',true),
('motor-ie4-1_5-6','4BM1.5-6','IE4','4BM',1.5,6,'1.5HP 6Pole IE4 Motor','IE4-260803',9,0,0,0,'common',true),
('motor-ie4-1_5-8','4BM1.5-8','IE4','4BM',1.5,8,'1.5HP 8Pole IE4 Motor','IE4-260803',9,0,0,0,'common',true),
('motor-ie4-2-2','4BM2-2','IE4','4BM',2,2,'2HP 2Pole IE4 Motor','IE4-260803',10,0,0,0,'common',true),
('motor-ie4-2-4','4BM2-4','IE4','4BM',2,4,'2HP 4Pole IE4 Motor','IE4-260803',10,0,0,0,'common',true),
('motor-ie4-2-6','4BM2-6','IE4','4BM',2,6,'2HP 6Pole IE4 Motor','IE4-260803',10,0,0,0,'common',true),
('motor-ie4-2-8','4BM2-8','IE4','4BM',2,8,'2HP 8Pole IE4 Motor','IE4-260803',10,0,0,0,'common',true),
('motor-ie4-3-2','4BM3-2','IE4','4BM',3,2,'3HP 2Pole IE4 Motor','IE4-260803',11,0,0,0,'common',true),
('motor-ie4-3-4','4BM3-4','IE4','4BM',3,4,'3HP 4Pole IE4 Motor','IE4-260803',11,0,0,0,'common',true),
('motor-ie4-3-6','4BM3-6','IE4','4BM',3,6,'3HP 6Pole IE4 Motor','IE4-260803',11,0,0,0,'common',true),
('motor-ie4-3-8','4BM3-8','IE4','4BM',3,8,'3HP 8Pole IE4 Motor','IE4-260803',11,0,0,0,'common',true),
('motor-ie4-4-2','4BM4-2','IE4','4BM',4,2,'4HP 2Pole IE4 Motor','IE4-260803',12,0,0,0,'common',true),
('motor-ie4-4-4','4BM4-4','IE4','4BM',4,4,'4HP 4Pole IE4 Motor','IE4-260803',12,0,0,0,'common',true),
('motor-ie4-4-6','4BM4-6','IE4','4BM',4,6,'4HP 6Pole IE4 Motor','IE4-260803',12,0,0,0,'common',true),
('motor-ie4-4-8','4BM4-8','IE4','4BM',4,8,'4HP 8Pole IE4 Motor','IE4-260803',12,0,0,0,'common',true),
('motor-ie4-5_5-2','4BM5.5-2','IE4','4BM',5.5,2,'5.5HP 2Pole IE4 Motor','IE4-260803',13,0,0,0,'common',true),
('motor-ie4-5_5-4','4BM5.5-4','IE4','4BM',5.5,4,'5.5HP 4Pole IE4 Motor','IE4-260803',13,0,0,0,'common',true),
('motor-ie4-5_5-6','4BM5.5-6','IE4','4BM',5.5,6,'5.5HP 6Pole IE4 Motor','IE4-260803',13,0,0,0,'common',true),
('motor-ie4-5_5-8','4BM5.5-8','IE4','4BM',5.5,8,'5.5HP 8Pole IE4 Motor','IE4-260803',13,0,0,0,'common',true),
('motor-ie4-7_5-2','4BM7.5-2','IE4','4BM',7.5,2,'7.5HP 2Pole IE4 Motor','IE4-260803',14,0,0,0,'common',true),
('motor-ie4-7_5-4','4BM7.5-4','IE4','4BM',7.5,4,'7.5HP 4Pole IE4 Motor','IE4-260803',14,0,0,0,'common',true),
('motor-ie4-7_5-6','4BM7.5-6','IE4','4BM',7.5,6,'7.5HP 6Pole IE4 Motor','IE4-260803',14,0,0,0,'common',true),
('motor-ie4-7_5-8','4BM7.5-8','IE4','4BM',7.5,8,'7.5HP 8Pole IE4 Motor','IE4-260803',14,0,0,0,'common',true),
('motor-ie4-10-2','4BM10-2','IE4','4BM',10,2,'10HP 2Pole IE4 Motor','IE4-260803',15,0,0,0,'common',true),
('motor-ie4-10-4','4BM10-4','IE4','4BM',10,4,'10HP 4Pole IE4 Motor','IE4-260803',15,0,0,0,'common',true),
('motor-ie4-10-6','4BM10-6','IE4','4BM',10,6,'10HP 6Pole IE4 Motor','IE4-260803',15,0,0,0,'common',true),
('motor-ie4-10-8','4BM10-8','IE4','4BM',10,8,'10HP 8Pole IE4 Motor','IE4-260803',15,0,0,0,'common',true),
('motor-ie4-15-2','4BM15-2','IE4','4BM',15,2,'15HP 2Pole IE4 Motor','IE4-260803',16,0,0,0,'common',true),
('motor-ie4-15-4','4BM15-4','IE4','4BM',15,4,'15HP 4Pole IE4 Motor','IE4-260803',16,0,0,0,'common',true),
('motor-ie4-15-6','4BM15-6','IE4','4BM',15,6,'15HP 6Pole IE4 Motor','IE4-260803',16,0,0,0,'common',true),
('motor-ie4-15-8','4BM15-8','IE4','4BM',15,8,'15HP 8Pole IE4 Motor','IE4-260803',16,0,0,0,'common',true),
('motor-ie4-20-2','4BM20-2','IE4','4BM',20,2,'20HP 2Pole IE4 Motor','IE4-260803',17,0,0,0,'common',true),
('motor-ie4-20-4','4BM20-4','IE4','4BM',20,4,'20HP 4Pole IE4 Motor','IE4-260803',17,0,0,0,'common',true),
('motor-ie4-20-6','4BM20-6','IE4','4BM',20,6,'20HP 6Pole IE4 Motor','IE4-260803',17,0,0,0,'common',true),
('motor-ie4-20-8','4BM20-8','IE4','4BM',20,8,'20HP 8Pole IE4 Motor','IE4-260803',17,0,0,0,'common',true),
('motor-ie4-25-2','4BM25-2','IE4','4BM',25,2,'25HP 2Pole IE4 Motor','IE4-260803',18,0,0,0,'common',true),
('motor-ie4-25-4','4BM25-4','IE4','4BM',25,4,'25HP 4Pole IE4 Motor','IE4-260803',18,0,0,0,'common',true),
('motor-ie4-25-6','4BM25-6','IE4','4BM',25,6,'25HP 6Pole IE4 Motor','IE4-260803',18,0,0,0,'common',true),
('motor-ie4-25-8','4BM25-8','IE4','4BM',25,8,'25HP 8Pole IE4 Motor','IE4-260803',18,0,0,0,'common',true),
('motor-ie4-30-2','4BM30-2','IE4','4BM',30,2,'30HP 2Pole IE4 Motor','IE4-260803',19,0,0,0,'common',true),
('motor-ie4-30-4','4BM30-4','IE4','4BM',30,4,'30HP 4Pole IE4 Motor','IE4-260803',19,0,0,0,'common',true),
('motor-ie4-30-6','4BM30-6','IE4','4BM',30,6,'30HP 6Pole IE4 Motor','IE4-260803',19,0,0,0,'common',true),
('motor-ie4-30-8','4BM30-8','IE4','4BM',30,8,'30HP 8Pole IE4 Motor','IE4-260803',19,0,0,0,'common',true),
('motor-ie4-40-2','4BM40-2','IE4','4BM',40,2,'40HP 2Pole IE4 Motor','IE4-260803',20,0,0,0,'common',true),
('motor-ie4-40-4','4BM40-4','IE4','4BM',40,4,'40HP 4Pole IE4 Motor','IE4-260803',20,0,0,0,'common',true),
('motor-ie4-40-6','4BM40-6','IE4','4BM',40,6,'40HP 6Pole IE4 Motor','IE4-260803',20,0,0,0,'common',true),
('motor-ie4-40-8','4BM40-8','IE4','4BM',40,8,'40HP 8Pole IE4 Motor','IE4-260803',20,0,0,0,'common',true),
('motor-ie4-50-2','4BM50-2','IE4','4BM',50,2,'50HP 2Pole IE4 Motor','IE4-260803',21,0,0,0,'common',true),
('motor-ie4-50-4','4BM50-4','IE4','4BM',50,4,'50HP 4Pole IE4 Motor','IE4-260803',21,0,0,0,'common',true),
('motor-ie4-50-6','4BM50-6','IE4','4BM',50,6,'50HP 6Pole IE4 Motor','IE4-260803',21,0,0,0,'common',true),
('motor-ie4-50-8','4BM50-8','IE4','4BM',50,8,'50HP 8Pole IE4 Motor','IE4-260803',21,0,0,0,'common',true),
('motor-ie4-60-2','4BM60-2','IE4','4BM',60,2,'60HP 2Pole IE4 Motor','IE4-260803',22,0,0,0,'common',true),
('motor-ie4-60-4','4BM60-4','IE4','4BM',60,4,'60HP 4Pole IE4 Motor','IE4-260803',22,0,0,0,'common',true),
('motor-ie4-60-6','4BM60-6','IE4','4BM',60,6,'60HP 6Pole IE4 Motor','IE4-260803',22,0,0,0,'common',true),
('motor-ie4-60-8','4BM60-8','IE4','4BM',60,8,'60HP 8Pole IE4 Motor','IE4-260803',22,0,0,0,'common',true),
('motor-ie4-75-2','4BM75-2','IE4','4BM',75,2,'75HP 2Pole IE4 Motor','IE4-260803',23,0,0,0,'common',true),
('motor-ie4-75-4','4BM75-4','IE4','4BM',75,4,'75HP 4Pole IE4 Motor','IE4-260803',23,0,0,0,'common',true),
('motor-ie4-75-6','4BM75-6','IE4','4BM',75,6,'75HP 6Pole IE4 Motor','IE4-260803',23,0,0,0,'common',true),
('motor-ie4-75-8','4BM75-8','IE4','4BM',75,8,'75HP 8Pole IE4 Motor','IE4-260803',23,0,0,0,'common',true),
('motor-ie4-100-2','4BM100-2','IE4','4BM',100,2,'100HP 2Pole IE4 Motor','IE4-260803',24,0,0,0,'common',true),
('motor-ie4-100-4','4BM100-4','IE4','4BM',100,4,'100HP 4Pole IE4 Motor','IE4-260803',24,0,0,0,'common',true),
('motor-ie4-100-6','4BM100-6','IE4','4BM',100,6,'100HP 6Pole IE4 Motor','IE4-260803',24,0,0,0,'common',true),
('motor-ie4-100-8','4BM100-8','IE4','4BM',100,8,'100HP 8Pole IE4 Motor','IE4-260803',24,0,0,0,'common',true),
('motor-ie4-125-2','4BM125-2','IE4','4BM',125,2,'125HP 2Pole IE4 Motor','IE4-260803',25,0,0,0,'common',true),
('motor-ie4-125-4','4BM125-4','IE4','4BM',125,4,'125HP 4Pole IE4 Motor','IE4-260803',25,0,0,0,'common',true),
('motor-ie4-125-6','4BM125-6','IE4','4BM',125,6,'125HP 6Pole IE4 Motor','IE4-260803',25,0,0,0,'common',true),
('motor-ie4-125-8','4BM125-8','IE4','4BM',125,8,'125HP 8Pole IE4 Motor','IE4-260803',25,0,0,0,'common',true),
('motor-ie4-150-2','4BM150-2','IE4','4BM',150,2,'150HP 2Pole IE4 Motor','IE4-260803',26,0,0,0,'common',true),
('motor-ie4-150-4','4BM150-4','IE4','4BM',150,4,'150HP 4Pole IE4 Motor','IE4-260803',26,0,0,0,'common',true),
('motor-ie4-150-6','4BM150-6','IE4','4BM',150,6,'150HP 6Pole IE4 Motor','IE4-260803',26,0,0,0,'common',true),
('motor-ie4-150-8','4BM150-8','IE4','4BM',150,8,'150HP 8Pole IE4 Motor','IE4-260803',26,0,0,0,'common',true),
('motor-ie4-175-2','4BM175-2','IE4','4BM',175,2,'175HP 2Pole IE4 Motor','IE4-260803',27,0,0,0,'common',true),
('motor-ie4-175-4','4BM175-4','IE4','4BM',175,4,'175HP 4Pole IE4 Motor','IE4-260803',27,0,0,0,'common',true),
('motor-ie4-175-6','4BM175-6','IE4','4BM',175,6,'175HP 6Pole IE4 Motor','IE4-260803',27,0,0,0,'common',true),
('motor-ie4-175-8','4BM175-8','IE4','4BM',175,8,'175HP 8Pole IE4 Motor','IE4-260803',27,0,0,0,'common',true),
('motor-ie4-200-2','4BM200-2','IE4','4BM',200,2,'200HP 2Pole IE4 Motor','IE4-260803',28,0,0,0,'common',true),
('motor-ie4-200-4','4BM200-4','IE4','4BM',200,4,'200HP 4Pole IE4 Motor','IE4-260803',28,0,0,0,'common',true),
('motor-ie4-200-6','4BM200-6','IE4','4BM',200,6,'200HP 6Pole IE4 Motor','IE4-260803',28,0,0,0,'common',true),
('motor-ie4-200-8','4BM200-8','IE4','4BM',200,8,'200HP 8Pole IE4 Motor','IE4-260803',28,0,0,0,'common',true),
('motor-ie4-215-2','4BM215-2','IE4','4BM',215,2,'215HP 2Pole IE4 Motor','IE4-260803',29,0,0,0,'common',true),
('motor-ie4-215-4','4BM215-4','IE4','4BM',215,4,'215HP 4Pole IE4 Motor','IE4-260803',29,0,0,0,'common',true),
('motor-ie4-215-6','4BM215-6','IE4','4BM',215,6,'215HP 6Pole IE4 Motor','IE4-260803',29,0,0,0,'common',true),
('motor-ie4-215-8','4BM215-8','IE4','4BM',215,8,'215HP 8Pole IE4 Motor','IE4-260803',29,0,0,0,'common',true),
('motor-ie4-250-2','4BM250-2','IE4','4BM',250,2,'250HP 2Pole IE4 Motor','IE4-260803',30,0,0,0,'common',true),
('motor-ie4-250-4','4BM250-4','IE4','4BM',250,4,'250HP 4Pole IE4 Motor','IE4-260803',30,0,0,0,'common',true),
('motor-ie4-250-6','4BM250-6','IE4','4BM',250,6,'250HP 6Pole IE4 Motor','IE4-260803',30,0,0,0,'common',true),
('motor-ie4-250-8','4BM250-8','IE4','4BM',250,8,'250HP 8Pole IE4 Motor','IE4-260803',30,0,0,0,'common',true),
('motor-ie4-270-2','4BM270-2','IE4','4BM',270,2,'270HP 2Pole IE4 Motor','IE4-260803',31,0,0,0,'common',true),
('motor-ie4-270-4','4BM270-4','IE4','4BM',270,4,'270HP 4Pole IE4 Motor','IE4-260803',31,0,0,0,'common',true),
('motor-ie4-270-6','4BM270-6','IE4','4BM',270,6,'270HP 6Pole IE4 Motor','IE4-260803',31,0,0,0,'common',true),
('motor-ie4-270-8','4BM270-8','IE4','4BM',270,8,'270HP 8Pole IE4 Motor','IE4-260803',31,0,0,0,'common',true),
('motor-ie4-300-2','4BM300-2','IE4','4BM',300,2,'300HP 2Pole IE4 Motor','IE4-260803',32,0,0,0,'common',true),
('motor-ie4-300-4','4BM300-4','IE4','4BM',300,4,'300HP 4Pole IE4 Motor','IE4-260803',32,0,0,0,'common',true),
('motor-ie4-300-6','4BM300-6','IE4','4BM',300,6,'300HP 6Pole IE4 Motor','IE4-260803',32,0,0,0,'common',true),
('motor-ie4-300-8','4BM300-8','IE4','4BM',300,8,'300HP 8Pole IE4 Motor','IE4-260803',32,0,0,0,'common',true),
('motor-ie4-335-2','4BM335-2','IE4','4BM',335,2,'335HP 2Pole IE4 Motor','IE4-260803',33,0,0,0,'common',true),
('motor-ie4-335-4','4BM335-4','IE4','4BM',335,4,'335HP 4Pole IE4 Motor','IE4-260803',33,0,0,0,'common',true),
('motor-ie4-335-6','4BM335-6','IE4','4BM',335,6,'335HP 6Pole IE4 Motor','IE4-260803',33,0,0,0,'common',true),
('motor-ie4-335-8','4BM335-8','IE4','4BM',335,8,'335HP 8Pole IE4 Motor','IE4-260803',33,0,0,0,'common',true),
('motor-ie4-375-2','4BM375-2','IE4','4BM',375,2,'375HP 2Pole IE4 Motor','IE4-260803',34,0,0,0,'common',true),
('motor-ie4-375-4','4BM375-4','IE4','4BM',375,4,'375HP 4Pole IE4 Motor','IE4-260803',34,0,0,0,'common',true),
('motor-ie4-375-6','4BM375-6','IE4','4BM',375,6,'375HP 6Pole IE4 Motor','IE4-260803',34,0,0,0,'common',true),
('motor-ie4-375-8','4BM375-8','IE4','4BM',375,8,'375HP 8Pole IE4 Motor','IE4-260803',34,0,0,0,'common',true),
('motor-ie4-420-2','4BM420-2','IE4','4BM',420,2,'420HP 2Pole IE4 Motor','IE4-260803',35,0,0,0,'common',true),
('motor-ie4-420-4','4BM420-4','IE4','4BM',420,4,'420HP 4Pole IE4 Motor','IE4-260803',35,0,0,0,'common',true),
('motor-ie4-420-6','4BM420-6','IE4','4BM',420,6,'420HP 6Pole IE4 Motor','IE4-260803',35,0,0,0,'common',true),
('motor-ie4-420-8','4BM420-8','IE4','4BM',420,8,'420HP 8Pole IE4 Motor','IE4-260803',35,0,0,0,'common',true),
('motor-ie4-500-2','4BM500-2','IE4','4BM',500,2,'500HP 2Pole IE4 Motor','IE4-260803',36,0,0,0,'common',true),
('motor-ie4-500-4','4BM500-4','IE4','4BM',500,4,'500HP 4Pole IE4 Motor','IE4-260803',36,0,0,0,'common',true),
('motor-ie4-500-6','4BM500-6','IE4','4BM',500,6,'500HP 6Pole IE4 Motor','IE4-260803',36,0,0,0,'common',true),
('motor-ie4-500-8','4BM500-8','IE4','4BM',500,8,'500HP 8Pole IE4 Motor','IE4-260803',36,0,0,0,'common',true),
('motor-ie4-600-2','4BM600-2','IE4','4BM',600,2,'600HP 2Pole IE4 Motor','IE4-260803',37,0,0,0,'common',true),
('motor-ie4-600-4','4BM600-4','IE4','4BM',600,4,'600HP 4Pole IE4 Motor','IE4-260803',37,0,0,0,'common',true),
('motor-ie4-600-6','4BM600-6','IE4','4BM',600,6,'600HP 6Pole IE4 Motor','IE4-260803',37,0,0,0,'common',true),
('motor-ie4-600-8','4BM600-8','IE4','4BM',600,8,'600HP 8Pole IE4 Motor','IE4-260803',37,0,0,0,'common',true),
('motor-ie5-0_25-2','5BM0.25-2','IE5','5BM',0.25,2,'0.25HP 2Pole IE5 Motor','IE5-260803',4,0,0,0,'common',true),
('motor-ie5-0_25-4','5BM0.25-4','IE5','5BM',0.25,4,'0.25HP 4Pole IE5 Motor','IE5-260803',4,0,0,0,'common',true),
('motor-ie5-0_25-6','5BM0.25-6','IE5','5BM',0.25,6,'0.25HP 6Pole IE5 Motor','IE5-260803',4,0,0,0,'common',true),
('motor-ie5-0_25-8','5BM0.25-8','IE5','5BM',0.25,8,'0.25HP 8Pole IE5 Motor','IE5-260803',4,0,0,0,'common',true),
('motor-ie5-0_33-2','5BM0.33-2','IE5','5BM',0.33,2,'0.33HP 2Pole IE5 Motor','IE5-260803',5,0,0,0,'common',true),
('motor-ie5-0_33-4','5BM0.33-4','IE5','5BM',0.33,4,'0.33HP 4Pole IE5 Motor','IE5-260803',5,0,0,0,'common',true),
('motor-ie5-0_33-6','5BM0.33-6','IE5','5BM',0.33,6,'0.33HP 6Pole IE5 Motor','IE5-260803',5,0,0,0,'common',true),
('motor-ie5-0_33-8','5BM0.33-8','IE5','5BM',0.33,8,'0.33HP 8Pole IE5 Motor','IE5-260803',5,0,0,0,'common',true),
('motor-ie5-0_5-2','5BM0.5-2','IE5','5BM',0.5,2,'0.5HP 2Pole IE5 Motor','IE5-260803',6,0,0,0,'common',true),
('motor-ie5-0_5-4','5BM0.5-4','IE5','5BM',0.5,4,'0.5HP 4Pole IE5 Motor','IE5-260803',6,0,0,0,'common',true),
('motor-ie5-0_5-6','5BM0.5-6','IE5','5BM',0.5,6,'0.5HP 6Pole IE5 Motor','IE5-260803',6,0,0,0,'common',true),
('motor-ie5-0_5-8','5BM0.5-8','IE5','5BM',0.5,8,'0.5HP 8Pole IE5 Motor','IE5-260803',6,0,0,0,'common',true),
('motor-ie5-0_75-2','5BM0.75-2','IE5','5BM',0.75,2,'0.75HP 2Pole IE5 Motor','IE5-260803',7,0,0,0,'common',true),
('motor-ie5-0_75-4','5BM0.75-4','IE5','5BM',0.75,4,'0.75HP 4Pole IE5 Motor','IE5-260803',7,0,0,0,'common',true),
('motor-ie5-0_75-6','5BM0.75-6','IE5','5BM',0.75,6,'0.75HP 6Pole IE5 Motor','IE5-260803',7,0,0,0,'common',true),
('motor-ie5-0_75-8','5BM0.75-8','IE5','5BM',0.75,8,'0.75HP 8Pole IE5 Motor','IE5-260803',7,0,0,0,'common',true),
('motor-ie5-1-2','5BM1-2','IE5','5BM',1,2,'1HP 2Pole IE5 Motor','IE5-260803',8,0,0,0,'common',true),
('motor-ie5-1-4','5BM1-4','IE5','5BM',1,4,'1HP 4Pole IE5 Motor','IE5-260803',8,0,0,0,'common',true),
('motor-ie5-1-6','5BM1-6','IE5','5BM',1,6,'1HP 6Pole IE5 Motor','IE5-260803',8,0,0,0,'common',true),
('motor-ie5-1-8','5BM1-8','IE5','5BM',1,8,'1HP 8Pole IE5 Motor','IE5-260803',8,0,0,0,'common',true),
('motor-ie5-1_5-2','5BM1.5-2','IE5','5BM',1.5,2,'1.5HP 2Pole IE5 Motor','IE5-260803',9,0,0,0,'common',true),
('motor-ie5-1_5-4','5BM1.5-4','IE5','5BM',1.5,4,'1.5HP 4Pole IE5 Motor','IE5-260803',9,0,0,0,'common',true),
('motor-ie5-1_5-6','5BM1.5-6','IE5','5BM',1.5,6,'1.5HP 6Pole IE5 Motor','IE5-260803',9,0,0,0,'common',true),
('motor-ie5-1_5-8','5BM1.5-8','IE5','5BM',1.5,8,'1.5HP 8Pole IE5 Motor','IE5-260803',9,0,0,0,'common',true),
('motor-ie5-2-2','5BM2-2','IE5','5BM',2,2,'2HP 2Pole IE5 Motor','IE5-260803',10,0,0,0,'common',true),
('motor-ie5-2-4','5BM2-4','IE5','5BM',2,4,'2HP 4Pole IE5 Motor','IE5-260803',10,0,0,0,'common',true),
('motor-ie5-2-6','5BM2-6','IE5','5BM',2,6,'2HP 6Pole IE5 Motor','IE5-260803',10,0,0,0,'common',true),
('motor-ie5-2-8','5BM2-8','IE5','5BM',2,8,'2HP 8Pole IE5 Motor','IE5-260803',10,0,0,0,'common',true),
('motor-ie5-3-2','5BM3-2','IE5','5BM',3,2,'3HP 2Pole IE5 Motor','IE5-260803',11,0,0,0,'common',true),
('motor-ie5-3-4','5BM3-4','IE5','5BM',3,4,'3HP 4Pole IE5 Motor','IE5-260803',11,0,0,0,'common',true),
('motor-ie5-3-6','5BM3-6','IE5','5BM',3,6,'3HP 6Pole IE5 Motor','IE5-260803',11,0,0,0,'common',true),
('motor-ie5-3-8','5BM3-8','IE5','5BM',3,8,'3HP 8Pole IE5 Motor','IE5-260803',11,0,0,0,'common',true),
('motor-ie5-4-2','5BM4-2','IE5','5BM',4,2,'4HP 2Pole IE5 Motor','IE5-260803',12,0,0,0,'common',true),
('motor-ie5-4-4','5BM4-4','IE5','5BM',4,4,'4HP 4Pole IE5 Motor','IE5-260803',12,0,0,0,'common',true),
('motor-ie5-4-6','5BM4-6','IE5','5BM',4,6,'4HP 6Pole IE5 Motor','IE5-260803',12,0,0,0,'common',true),
('motor-ie5-4-8','5BM4-8','IE5','5BM',4,8,'4HP 8Pole IE5 Motor','IE5-260803',12,0,0,0,'common',true),
('motor-ie5-5_5-2','5BM5.5-2','IE5','5BM',5.5,2,'5.5HP 2Pole IE5 Motor','IE5-260803',13,0,0,0,'common',true),
('motor-ie5-5_5-4','5BM5.5-4','IE5','5BM',5.5,4,'5.5HP 4Pole IE5 Motor','IE5-260803',13,0,0,0,'common',true),
('motor-ie5-5_5-6','5BM5.5-6','IE5','5BM',5.5,6,'5.5HP 6Pole IE5 Motor','IE5-260803',13,0,0,0,'common',true),
('motor-ie5-5_5-8','5BM5.5-8','IE5','5BM',5.5,8,'5.5HP 8Pole IE5 Motor','IE5-260803',13,0,0,0,'common',true),
('motor-ie5-7_5-2','5BM7.5-2','IE5','5BM',7.5,2,'7.5HP 2Pole IE5 Motor','IE5-260803',14,0,0,0,'common',true),
('motor-ie5-7_5-4','5BM7.5-4','IE5','5BM',7.5,4,'7.5HP 4Pole IE5 Motor','IE5-260803',14,0,0,0,'common',true),
('motor-ie5-7_5-6','5BM7.5-6','IE5','5BM',7.5,6,'7.5HP 6Pole IE5 Motor','IE5-260803',14,0,0,0,'common',true),
('motor-ie5-7_5-8','5BM7.5-8','IE5','5BM',7.5,8,'7.5HP 8Pole IE5 Motor','IE5-260803',14,0,0,0,'common',true),
('motor-ie5-10-2','5BM10-2','IE5','5BM',10,2,'10HP 2Pole IE5 Motor','IE5-260803',15,0,0,0,'common',true),
('motor-ie5-10-4','5BM10-4','IE5','5BM',10,4,'10HP 4Pole IE5 Motor','IE5-260803',15,0,0,0,'common',true),
('motor-ie5-10-6','5BM10-6','IE5','5BM',10,6,'10HP 6Pole IE5 Motor','IE5-260803',15,0,0,0,'common',true),
('motor-ie5-10-8','5BM10-8','IE5','5BM',10,8,'10HP 8Pole IE5 Motor','IE5-260803',15,0,0,0,'common',true),
('motor-ie5-15-2','5BM15-2','IE5','5BM',15,2,'15HP 2Pole IE5 Motor','IE5-260803',16,0,0,0,'common',true),
('motor-ie5-15-4','5BM15-4','IE5','5BM',15,4,'15HP 4Pole IE5 Motor','IE5-260803',16,0,0,0,'common',true),
('motor-ie5-15-6','5BM15-6','IE5','5BM',15,6,'15HP 6Pole IE5 Motor','IE5-260803',16,0,0,0,'common',true),
('motor-ie5-15-8','5BM15-8','IE5','5BM',15,8,'15HP 8Pole IE5 Motor','IE5-260803',16,0,0,0,'common',true),
('motor-ie5-20-2','5BM20-2','IE5','5BM',20,2,'20HP 2Pole IE5 Motor','IE5-260803',17,0,0,0,'common',true),
('motor-ie5-20-4','5BM20-4','IE5','5BM',20,4,'20HP 4Pole IE5 Motor','IE5-260803',17,0,0,0,'common',true),
('motor-ie5-20-6','5BM20-6','IE5','5BM',20,6,'20HP 6Pole IE5 Motor','IE5-260803',17,0,0,0,'common',true),
('motor-ie5-20-8','5BM20-8','IE5','5BM',20,8,'20HP 8Pole IE5 Motor','IE5-260803',17,0,0,0,'common',true),
('motor-ie5-25-2','5BM25-2','IE5','5BM',25,2,'25HP 2Pole IE5 Motor','IE5-260803',18,0,0,0,'common',true),
('motor-ie5-25-4','5BM25-4','IE5','5BM',25,4,'25HP 4Pole IE5 Motor','IE5-260803',18,0,0,0,'common',true),
('motor-ie5-25-6','5BM25-6','IE5','5BM',25,6,'25HP 6Pole IE5 Motor','IE5-260803',18,0,0,0,'common',true),
('motor-ie5-25-8','5BM25-8','IE5','5BM',25,8,'25HP 8Pole IE5 Motor','IE5-260803',18,0,0,0,'common',true),
('motor-ie5-30-2','5BM30-2','IE5','5BM',30,2,'30HP 2Pole IE5 Motor','IE5-260803',19,0,0,0,'common',true),
('motor-ie5-30-4','5BM30-4','IE5','5BM',30,4,'30HP 4Pole IE5 Motor','IE5-260803',19,0,0,0,'common',true),
('motor-ie5-30-6','5BM30-6','IE5','5BM',30,6,'30HP 6Pole IE5 Motor','IE5-260803',19,0,0,0,'common',true),
('motor-ie5-30-8','5BM30-8','IE5','5BM',30,8,'30HP 8Pole IE5 Motor','IE5-260803',19,0,0,0,'common',true),
('motor-ie5-40-2','5BM40-2','IE5','5BM',40,2,'40HP 2Pole IE5 Motor','IE5-260803',20,0,0,0,'common',true),
('motor-ie5-40-4','5BM40-4','IE5','5BM',40,4,'40HP 4Pole IE5 Motor','IE5-260803',20,0,0,0,'common',true),
('motor-ie5-40-6','5BM40-6','IE5','5BM',40,6,'40HP 6Pole IE5 Motor','IE5-260803',20,0,0,0,'common',true),
('motor-ie5-40-8','5BM40-8','IE5','5BM',40,8,'40HP 8Pole IE5 Motor','IE5-260803',20,0,0,0,'common',true),
('motor-ie5-50-2','5BM50-2','IE5','5BM',50,2,'50HP 2Pole IE5 Motor','IE5-260803',21,0,0,0,'common',true),
('motor-ie5-50-4','5BM50-4','IE5','5BM',50,4,'50HP 4Pole IE5 Motor','IE5-260803',21,0,0,0,'common',true),
('motor-ie5-50-6','5BM50-6','IE5','5BM',50,6,'50HP 6Pole IE5 Motor','IE5-260803',21,0,0,0,'common',true),
('motor-ie5-50-8','5BM50-8','IE5','5BM',50,8,'50HP 8Pole IE5 Motor','IE5-260803',21,0,0,0,'common',true),
('motor-ie5-60-2','5BM60-2','IE5','5BM',60,2,'60HP 2Pole IE5 Motor','IE5-260803',22,0,0,0,'common',true),
('motor-ie5-60-4','5BM60-4','IE5','5BM',60,4,'60HP 4Pole IE5 Motor','IE5-260803',22,0,0,0,'common',true),
('motor-ie5-60-6','5BM60-6','IE5','5BM',60,6,'60HP 6Pole IE5 Motor','IE5-260803',22,0,0,0,'common',true),
('motor-ie5-60-8','5BM60-8','IE5','5BM',60,8,'60HP 8Pole IE5 Motor','IE5-260803',22,0,0,0,'common',true),
('motor-ie5-75-2','5BM75-2','IE5','5BM',75,2,'75HP 2Pole IE5 Motor','IE5-260803',23,0,0,0,'common',true),
('motor-ie5-75-4','5BM75-4','IE5','5BM',75,4,'75HP 4Pole IE5 Motor','IE5-260803',23,0,0,0,'common',true),
('motor-ie5-75-6','5BM75-6','IE5','5BM',75,6,'75HP 6Pole IE5 Motor','IE5-260803',23,0,0,0,'common',true),
('motor-ie5-75-8','5BM75-8','IE5','5BM',75,8,'75HP 8Pole IE5 Motor','IE5-260803',23,0,0,0,'common',true),
('motor-ie5-100-2','5BM100-2','IE5','5BM',100,2,'100HP 2Pole IE5 Motor','IE5-260803',24,0,0,0,'common',true),
('motor-ie5-100-4','5BM100-4','IE5','5BM',100,4,'100HP 4Pole IE5 Motor','IE5-260803',24,0,0,0,'common',true),
('motor-ie5-100-6','5BM100-6','IE5','5BM',100,6,'100HP 6Pole IE5 Motor','IE5-260803',24,0,0,0,'common',true),
('motor-ie5-100-8','5BM100-8','IE5','5BM',100,8,'100HP 8Pole IE5 Motor','IE5-260803',24,0,0,0,'common',true),
('motor-ie5-125-2','5BM125-2','IE5','5BM',125,2,'125HP 2Pole IE5 Motor','IE5-260803',25,0,0,0,'common',true),
('motor-ie5-125-4','5BM125-4','IE5','5BM',125,4,'125HP 4Pole IE5 Motor','IE5-260803',25,0,0,0,'common',true),
('motor-ie5-125-6','5BM125-6','IE5','5BM',125,6,'125HP 6Pole IE5 Motor','IE5-260803',25,0,0,0,'common',true),
('motor-ie5-125-8','5BM125-8','IE5','5BM',125,8,'125HP 8Pole IE5 Motor','IE5-260803',25,0,0,0,'common',true),
('motor-ie5-150-2','5BM150-2','IE5','5BM',150,2,'150HP 2Pole IE5 Motor','IE5-260803',26,0,0,0,'common',true),
('motor-ie5-150-4','5BM150-4','IE5','5BM',150,4,'150HP 4Pole IE5 Motor','IE5-260803',26,0,0,0,'common',true),
('motor-ie5-150-6','5BM150-6','IE5','5BM',150,6,'150HP 6Pole IE5 Motor','IE5-260803',26,0,0,0,'common',true),
('motor-ie5-150-8','5BM150-8','IE5','5BM',150,8,'150HP 8Pole IE5 Motor','IE5-260803',26,0,0,0,'common',true),
('motor-ie5-175-2','5BM175-2','IE5','5BM',175,2,'175HP 2Pole IE5 Motor','IE5-260803',27,0,0,0,'common',true),
('motor-ie5-175-4','5BM175-4','IE5','5BM',175,4,'175HP 4Pole IE5 Motor','IE5-260803',27,0,0,0,'common',true),
('motor-ie5-175-6','5BM175-6','IE5','5BM',175,6,'175HP 6Pole IE5 Motor','IE5-260803',27,0,0,0,'common',true),
('motor-ie5-175-8','5BM175-8','IE5','5BM',175,8,'175HP 8Pole IE5 Motor','IE5-260803',27,0,0,0,'common',true),
('motor-ie5-200-2','5BM200-2','IE5','5BM',200,2,'200HP 2Pole IE5 Motor','IE5-260803',28,0,0,0,'common',true),
('motor-ie5-200-4','5BM200-4','IE5','5BM',200,4,'200HP 4Pole IE5 Motor','IE5-260803',28,0,0,0,'common',true),
('motor-ie5-200-6','5BM200-6','IE5','5BM',200,6,'200HP 6Pole IE5 Motor','IE5-260803',28,0,0,0,'common',true),
('motor-ie5-200-8','5BM200-8','IE5','5BM',200,8,'200HP 8Pole IE5 Motor','IE5-260803',28,0,0,0,'common',true),
('motor-ie5-215-2','5BM215-2','IE5','5BM',215,2,'215HP 2Pole IE5 Motor','IE5-260803',29,0,0,0,'common',true),
('motor-ie5-215-4','5BM215-4','IE5','5BM',215,4,'215HP 4Pole IE5 Motor','IE5-260803',29,0,0,0,'common',true),
('motor-ie5-215-6','5BM215-6','IE5','5BM',215,6,'215HP 6Pole IE5 Motor','IE5-260803',29,0,0,0,'common',true),
('motor-ie5-215-8','5BM215-8','IE5','5BM',215,8,'215HP 8Pole IE5 Motor','IE5-260803',29,0,0,0,'common',true),
('motor-ie5-250-2','5BM250-2','IE5','5BM',250,2,'250HP 2Pole IE5 Motor','IE5-260803',30,0,0,0,'common',true),
('motor-ie5-250-4','5BM250-4','IE5','5BM',250,4,'250HP 4Pole IE5 Motor','IE5-260803',30,0,0,0,'common',true),
('motor-ie5-250-6','5BM250-6','IE5','5BM',250,6,'250HP 6Pole IE5 Motor','IE5-260803',30,0,0,0,'common',true),
('motor-ie5-250-8','5BM250-8','IE5','5BM',250,8,'250HP 8Pole IE5 Motor','IE5-260803',30,0,0,0,'common',true),
('motor-ie5-270-2','5BM270-2','IE5','5BM',270,2,'270HP 2Pole IE5 Motor','IE5-260803',31,0,0,0,'common',true),
('motor-ie5-270-4','5BM270-4','IE5','5BM',270,4,'270HP 4Pole IE5 Motor','IE5-260803',31,0,0,0,'common',true),
('motor-ie5-270-6','5BM270-6','IE5','5BM',270,6,'270HP 6Pole IE5 Motor','IE5-260803',31,0,0,0,'common',true),
('motor-ie5-270-8','5BM270-8','IE5','5BM',270,8,'270HP 8Pole IE5 Motor','IE5-260803',31,0,0,0,'common',true),
('motor-ie5-300-2','5BM300-2','IE5','5BM',300,2,'300HP 2Pole IE5 Motor','IE5-260803',32,0,0,0,'common',true),
('motor-ie5-300-4','5BM300-4','IE5','5BM',300,4,'300HP 4Pole IE5 Motor','IE5-260803',32,0,0,0,'common',true),
('motor-ie5-300-6','5BM300-6','IE5','5BM',300,6,'300HP 6Pole IE5 Motor','IE5-260803',32,0,0,0,'common',true),
('motor-ie5-300-8','5BM300-8','IE5','5BM',300,8,'300HP 8Pole IE5 Motor','IE5-260803',32,0,0,0,'common',true),
('motor-ie5-335-2','5BM335-2','IE5','5BM',335,2,'335HP 2Pole IE5 Motor','IE5-260803',33,0,0,0,'common',true),
('motor-ie5-335-4','5BM335-4','IE5','5BM',335,4,'335HP 4Pole IE5 Motor','IE5-260803',33,0,0,0,'common',true),
('motor-ie5-335-6','5BM335-6','IE5','5BM',335,6,'335HP 6Pole IE5 Motor','IE5-260803',33,0,0,0,'common',true),
('motor-ie5-335-8','5BM335-8','IE5','5BM',335,8,'335HP 8Pole IE5 Motor','IE5-260803',33,0,0,0,'common',true),
('motor-ie5-375-2','5BM375-2','IE5','5BM',375,2,'375HP 2Pole IE5 Motor','IE5-260803',34,0,0,0,'common',true),
('motor-ie5-375-4','5BM375-4','IE5','5BM',375,4,'375HP 4Pole IE5 Motor','IE5-260803',34,0,0,0,'common',true),
('motor-ie5-375-6','5BM375-6','IE5','5BM',375,6,'375HP 6Pole IE5 Motor','IE5-260803',34,0,0,0,'common',true),
('motor-ie5-375-8','5BM375-8','IE5','5BM',375,8,'375HP 8Pole IE5 Motor','IE5-260803',34,0,0,0,'common',true),
('motor-ie5-420-2','5BM420-2','IE5','5BM',420,2,'420HP 2Pole IE5 Motor','IE5-260803',35,0,0,0,'common',true),
('motor-ie5-420-4','5BM420-4','IE5','5BM',420,4,'420HP 4Pole IE5 Motor','IE5-260803',35,0,0,0,'common',true),
('motor-ie5-420-6','5BM420-6','IE5','5BM',420,6,'420HP 6Pole IE5 Motor','IE5-260803',35,0,0,0,'common',true),
('motor-ie5-420-8','5BM420-8','IE5','5BM',420,8,'420HP 8Pole IE5 Motor','IE5-260803',35,0,0,0,'common',true),
('motor-ie5-500-2','5BM500-2','IE5','5BM',500,2,'500HP 2Pole IE5 Motor','IE5-260803',36,0,0,0,'common',true),
('motor-ie5-500-4','5BM500-4','IE5','5BM',500,4,'500HP 4Pole IE5 Motor','IE5-260803',36,0,0,0,'common',true),
('motor-ie5-500-6','5BM500-6','IE5','5BM',500,6,'500HP 6Pole IE5 Motor','IE5-260803',36,0,0,0,'common',true),
('motor-ie5-500-8','5BM500-8','IE5','5BM',500,8,'500HP 8Pole IE5 Motor','IE5-260803',36,0,0,0,'common',true),
('motor-ie5-600-2','5BM600-2','IE5','5BM',600,2,'600HP 2Pole IE5 Motor','IE5-260803',37,0,0,0,'common',true),
('motor-ie5-600-4','5BM600-4','IE5','5BM',600,4,'600HP 4Pole IE5 Motor','IE5-260803',37,0,0,0,'common',true),
('motor-ie5-600-6','5BM600-6','IE5','5BM',600,6,'600HP 6Pole IE5 Motor','IE5-260803',37,0,0,0,'common',true),
('motor-ie5-600-8','5BM600-8','IE5','5BM',600,8,'600HP 8Pole IE5 Motor','IE5-260803',37,0,0,0,'common',true)
on conflict(id) do update set
  model=excluded.model,
  efficiency_class=excluded.efficiency_class,
  model_prefix=excluded.model_prefix,
  hp=excluded.hp,
  pole=excluded.pole,
  description=excluded.description,
  source_sheet=excluded.source_sheet,
  source_row=excluded.source_row,
  active=excluded.active;

-- Seed MOTOR rules without replacing an existing MOTOR setup.
update public.ks_pricing_categories pc
set product_rules=jsonb_set(
  coalesce(pc.product_rules,'{}'::jsonb),
  '{MOTOR}',
  coalesce(
    pc.product_rules->'MOTOR',
    pc.product_rules->'CHC',
    jsonb_build_object(
      'margin',0,'normal',0,'rare',0,'transport',0,
      'useCommission',true,'useSetDiscount',true,
      'useFinalDiscount',true,'useFuelCharge',true
    )
  ),true
);

create or replace function public.keysuite_decode_motor_model_v223(p_model text)
returns table(
  model text,
  efficiency_class text,
  model_prefix text,
  hp numeric,
  pole smallint,
  description text
)
language plpgsql
immutable
set search_path=public
as $$
declare
  v_model text:=upper(trim(coalesce(p_model,'')));
  v_match text[];
  v_efficiency text;
begin
  v_match:=regexp_match(v_model,'^(BM|2BM|3BM|4BM|5BM)([0-9]+(?:\.[0-9]+)?)-([0-9]+)$');
  if v_match is null then
    raise exception 'Motor model must follow BM20-2, 2BM20-2, 3BM50-5, 4BM20-4 or 5BM20-4.';
  end if;
  v_efficiency:=case v_match[1]
    when 'BM' then 'IE1' when '2BM' then 'IE2' when '3BM' then 'IE3'
    when '4BM' then 'IE4' else 'IE5' end;
  return query select v_model,v_efficiency,v_match[1],v_match[2]::numeric,v_match[3]::smallint,
    format('%sHP %sPole %s Motor',
      case when position('.' in v_match[2])>0 then rtrim(rtrim(v_match[2],'0'),'.') else v_match[2] end,
      v_match[3],v_efficiency);
end;
$$;

create or replace function public.keysuite_save_motor_price_v223(
  p_product_id text,
  p_currency text,
  p_price numeric,
  p_rarity text
)
returns table(product_id text,currency text,price numeric,rarity text)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_currency,'')));
  v_rarity text:=lower(trim(coalesce(p_rarity,'common')));
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then
    raise exception 'Your role is not allowed to maintain Motor prices.';
  end if;
  if v_currency not in ('USD','RMB','MYR') then raise exception 'Currency must be USD, RMB or MYR.'; end if;
  if p_price is null or p_price<0 then raise exception 'Motor price must be zero or more.'; end if;
  if v_rarity not in ('common','many','rare') then raise exception 'Rarity must be Common, Many or Rare.'; end if;

  update public.ks_products_motor p set
    price_usd=case when v_currency='USD' then p_price else p.price_usd end,
    price_rmb=case when v_currency='RMB' then p_price else p.price_rmb end,
    price_myr=case when v_currency='MYR' then p_price else p.price_myr end,
    rarity=v_rarity,
    updated_at=now()
  where p.id=p_product_id;
  if not found then raise exception 'Motor model was not found.'; end if;

  return query select p.id,v_currency,
    case v_currency when 'USD' then p.price_usd when 'RMB' then p.price_rmb else p.price_myr end,
    p.rarity
  from public.ks_products_motor p where p.id=p_product_id;
end;
$$;

create or replace function public.keysuite_save_motor_multiplier_v223(
  p_currency text,p_multiplier numeric
)
returns table(currency text,multiplier numeric)
language plpgsql
security definer
set search_path=public
as $$
declare v_currency text:=upper(trim(coalesce(p_currency,'')));
begin
  if public.keysuite_permission_level('manage_price_list')<>'full' then
    raise exception 'Your role is not allowed to maintain Motor currency rates.';
  end if;
  if v_currency not in ('USD','RMB') then raise exception 'Currency must be USD or RMB.'; end if;
  if p_multiplier is null or p_multiplier<=0 then raise exception 'Currency rate must be greater than zero.'; end if;

  update public.ks_app_settings s set
    motor_usd_multiplier=case when v_currency='USD' then p_multiplier else s.motor_usd_multiplier end,
    motor_rmb_multiplier=case when v_currency='RMB' then p_multiplier else s.motor_rmb_multiplier end
  where s.id='default';
  if not found then raise exception 'KeySuite application settings were not found.'; end if;
  return query select v_currency,p_multiplier;
end;
$$;

create or replace function public.keysuite_save_motor_category_rule_v223(
  p_category_id text,p_margin numeric,p_normal numeric,p_rare numeric,p_transport numeric,
  p_use_commission boolean,p_use_set_discount boolean,p_use_final_discount boolean,p_use_fuel_charge boolean
)
returns table(category_id text,product_rule jsonb)
language plpgsql
security definer
set search_path=public
as $$
declare v_rule jsonb;
begin
  if public.keysuite_permission_level('manage_categories')<>'full' then
    raise exception 'Your role is not allowed to edit Motor category rules.';
  end if;
  if p_margin is null or p_margin<0 or p_margin>=1
     or p_normal is null or p_normal<0 or p_normal>=1
     or p_rare is null or p_rare<0 or p_rare>=1 then
    raise exception 'Motor percentages must be from 0%% to below 100%%.';
  end if;
  if p_transport is null or p_transport<0 then raise exception 'Motor transport must be RM0.00 or more.'; end if;

  v_rule:=jsonb_build_object(
    'margin',p_margin,'normal',p_normal,'rare',p_rare,'transport',p_transport,
    'useCommission',coalesce(p_use_commission,false),
    'useSetDiscount',coalesce(p_use_set_discount,false),
    'useFinalDiscount',coalesce(p_use_final_discount,false),
    'useFuelCharge',coalesce(p_use_fuel_charge,false)
  );
  update public.ks_pricing_categories pc
  set product_rules=jsonb_set(coalesce(pc.product_rules,'{}'::jsonb),'{MOTOR}',v_rule,true)
  where pc.id=p_category_id;
  if not found then raise exception 'Pricing Category was not found.'; end if;
  return query select p_category_id,v_rule;
end;
$$;


-- V2.23 extends the standard Category editor to MOTOR.
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
  if v_product not in ('CHC','ES','GWS','KEYPLC','MANIFOLD','MOTOR') then raise exception 'Invalid product family.'; end if;
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
      jsonb_build_object('CHC',case when v_product='CHC' then v_rule else v_defaults end,'ES',case when v_product='ES' then v_rule else v_defaults end,'GWS',case when v_product='GWS' then v_rule else v_defaults end,'KEYPLC',case when v_product='KEYPLC' then v_rule else v_defaults end,'MANIFOLD',case when v_product='MANIFOLD' then v_rule else v_defaults end,'MOTOR',case when v_product='MOTOR' then v_rule else v_defaults end));
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


revoke all on function public.keysuite_get_quotation_prefix_v223() from public;
revoke all on function public.keysuite_save_quotation_prefix_v223(text) from public;
revoke all on function public.keysuite_next_quotation_reference_v223(timestamptz,integer) from public;
revoke all on function public.keysuite_decode_motor_model_v223(text) from public;
revoke all on function public.keysuite_save_motor_price_v223(text,text,numeric,text) from public;
revoke all on function public.keysuite_save_motor_multiplier_v223(text,numeric) from public;
revoke all on function public.keysuite_save_motor_category_rule_v223(text,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;

grant execute on function public.keysuite_get_quotation_prefix_v223() to authenticated;
grant execute on function public.keysuite_save_quotation_prefix_v223(text) to authenticated;
grant execute on function public.keysuite_next_quotation_reference_v223(timestamptz,integer) to authenticated;
grant execute on function public.keysuite_decode_motor_model_v223(text) to authenticated;
grant execute on function public.keysuite_save_motor_price_v223(text,text,numeric,text) to authenticated;
grant execute on function public.keysuite_save_motor_multiplier_v223(text,numeric) to authenticated;
grant execute on function public.keysuite_save_motor_category_rule_v223(text,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

revoke all on function public.keysuite_manage_pricing_category_v221(text,text,text,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) from public;
grant execute on function public.keysuite_manage_pricing_category_v221(text,text,text,numeric,numeric,numeric,numeric,boolean,boolean,boolean,boolean) to authenticated;

notify pgrst,'reload schema';
commit;

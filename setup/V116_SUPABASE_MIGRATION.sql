-- KeySuite V1.16
-- Global CHC Price List currency/multipliers, owner-managed source prices,
-- simplified pricing categories, and reliable per-user signatory/profile saving.
-- Run after V1.15.

begin;

-- ---------------------------------------------------------------------------
-- Global CHC Price List settings
-- ---------------------------------------------------------------------------
alter table public.ks_app_settings
  add column if not exists chc_source_currency text not null default 'USD';

alter table public.ks_app_settings
  add column if not exists usd_multiplier numeric not null default 5.8000;

alter table public.ks_app_settings
  add column if not exists rmb_multiplier numeric not null default 0.6500;

update public.ks_app_settings
set chc_source_currency = case
      when upper(coalesce(nullif(trim(chc_source_currency),''),nullif(trim(source_currency),''),'USD'))='RMB' then 'RMB'
      else 'USD'
    end,
    usd_multiplier = case
      when usd_multiplier is null or usd_multiplier<=0 then
        case when upper(coalesce(source_currency,'USD'))='USD' and currency_multiplier>0 then currency_multiplier else 5.8000 end
      else usd_multiplier
    end,
    rmb_multiplier = case
      when rmb_multiplier is null or rmb_multiplier<=0 then
        case when upper(coalesce(source_currency,'USD'))='RMB' and currency_multiplier>0 then currency_multiplier else 0.6500 end
      else rmb_multiplier
    end;

alter table public.ks_app_settings
  drop constraint if exists ks_app_settings_chc_source_currency_check;
alter table public.ks_app_settings
  add constraint ks_app_settings_chc_source_currency_check
  check (chc_source_currency in ('USD','RMB'));

alter table public.ks_app_settings
  drop constraint if exists ks_app_settings_usd_multiplier_check;
alter table public.ks_app_settings
  add constraint ks_app_settings_usd_multiplier_check check (usd_multiplier>0);

alter table public.ks_app_settings
  drop constraint if exists ks_app_settings_rmb_multiplier_check;
alter table public.ks_app_settings
  add constraint ks_app_settings_rmb_multiplier_check check (rmb_multiplier>0);

create or replace function public.keysuite_save_chc_pricelist_settings(
  p_source_currency text,
  p_usd_multiplier numeric,
  p_rmb_multiplier numeric
)
returns table (
  source_currency text,
  usd_multiplier numeric,
  rmb_multiplier numeric,
  active_multiplier numeric
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_currency text:=upper(trim(coalesce(p_source_currency,'')));
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can maintain Price List settings.';
  end if;
  if v_currency not in ('USD','RMB') then raise exception 'Currency must be USD or RMB.'; end if;
  if p_usd_multiplier is null or p_usd_multiplier<=0 then raise exception 'USD Multiply must be greater than zero.'; end if;
  if p_rmb_multiplier is null or p_rmb_multiplier<=0 then raise exception 'RMB Multiply must be greater than zero.'; end if;

  update public.ks_app_settings
  set chc_source_currency=v_currency,
      usd_multiplier=p_usd_multiplier,
      rmb_multiplier=p_rmb_multiplier,
      source_currency=v_currency,
      currency_multiplier=case when v_currency='RMB' then p_rmb_multiplier else p_usd_multiplier end
  where id='default';

  if not found then
    raise exception 'KeySuite application settings were not found.';
  end if;

  return query
  select s.chc_source_currency,s.usd_multiplier,s.rmb_multiplier,
         case when s.chc_source_currency='RMB' then s.rmb_multiplier else s.usd_multiplier end
  from public.ks_app_settings s where s.id='default';
end;
$$;

revoke all on function public.keysuite_save_chc_pricelist_settings(text,numeric,numeric) from public;
grant execute on function public.keysuite_save_chc_pricelist_settings(text,numeric,numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Owner-managed CHC / CHCS / CHCN source prices
-- Existing legacy *_usd columns are retained internally for compatibility.
-- Their values are interpreted using the selected global CHC currency.
-- ---------------------------------------------------------------------------
create or replace function public.keysuite_save_chc_product_price(
  p_product_id text,
  p_chc_price numeric,
  p_chcs_price numeric,
  p_chcn_price numeric
)
returns table (
  product_id text,
  chc_price numeric,
  chcs_price numeric,
  chcn_price numeric
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can maintain product prices.';
  end if;
  if trim(coalesce(p_product_id,''))='' then raise exception 'Product is required.'; end if;
  if p_chc_price is not null and p_chc_price<0 then raise exception 'CHC Price cannot be negative.'; end if;
  if p_chcs_price is not null and p_chcs_price<0 then raise exception 'CHCS Price cannot be negative.'; end if;
  if p_chcn_price is not null and p_chcn_price<0 then raise exception 'CHCN Price cannot be negative.'; end if;

  update public.ks_products_chc p
  set chc_usd=p_chc_price,
      chcs_usd=p_chcs_price,
      chcn_usd=p_chcn_price
  where p.id=p_product_id;

  if not found then raise exception 'CHC model was not found.'; end if;

  return query
  select p.id,p.chc_usd,p.chcs_usd,p.chcn_usd
  from public.ks_products_chc p where p.id=p_product_id;
end;
$$;

revoke all on function public.keysuite_save_chc_product_price(text,numeric,numeric,numeric) from public;
grant execute on function public.keysuite_save_chc_product_price(text,numeric,numeric,numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Pricing Categories no longer contain Currency or Multiply in the UI.
-- The old columns remain for backwards compatibility but are not used.
-- ---------------------------------------------------------------------------
drop function if exists public.keysuite_manage_pricing_category(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric);
drop function if exists public.keysuite_manage_pricing_category(text,text,numeric,numeric,numeric,numeric,numeric);

create function public.keysuite_manage_pricing_category(
  p_category_id text,
  p_category_name text,
  p_chc_margin numeric,
  p_transport numeric,
  p_commission numeric,
  p_set_discount numeric,
  p_final_discount numeric
)
returns table (
  category_id text,
  category_name text,
  chc_margin numeric,
  transport numeric,
  commission numeric,
  set_discount numeric,
  final_discount numeric
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id text:=trim(coalesce(p_category_id,''));
  v_name text:=trim(coalesce(p_category_name,''));
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can manage pricing categories.';
  end if;
  if v_name='' then raise exception 'Category Name is required.'; end if;
  if p_chc_margin is null or p_chc_margin<0 or p_chc_margin>=1 then raise exception 'CHC Margin must be from 0%% to below 100%%.'; end if;
  if p_transport is null or p_transport<0 then raise exception 'Transport must be zero or more.'; end if;
  if p_commission is null or p_commission<0 or p_commission>=1 then raise exception 'Commission must be from 0%% to below 100%%.'; end if;
  if p_set_discount is null or p_set_discount<0 or p_set_discount>=1 then raise exception 'Set Discount must be from 0%% to below 100%%.'; end if;
  if p_final_discount is null or p_final_discount<0 or p_final_discount>=1 then raise exception 'Final Discount must be from 0%% to below 100%%.'; end if;

  if exists(
    select 1 from public.ks_pricing_categories pc
    where lower(pc.category_name)=lower(v_name)
      and (v_id='' or pc.id<>v_id)
  ) then
    raise exception 'A pricing category with this name already exists.';
  end if;

  if v_id='' then
    v_id:='CCID'||upper(substr(md5(clock_timestamp()::text||random()::text||v_name),1,12));
    insert into public.ks_pricing_categories(
      id,category_name,final_discount,set_discount,commission,chc_factor,transport,chc_margin
    ) values (
      v_id,v_name,p_final_discount,p_set_discount,p_commission,p_chc_margin,p_transport,p_chc_margin
    );
  else
    update public.ks_pricing_categories pc set
      category_name=v_name,
      final_discount=p_final_discount,
      set_discount=p_set_discount,
      commission=p_commission,
      chc_factor=p_chc_margin,
      chc_margin=p_chc_margin,
      transport=p_transport
    where pc.id=v_id;
    if not found then raise exception 'Pricing category was not found.'; end if;
  end if;

  return query
  select pc.id,pc.category_name,pc.chc_margin,pc.transport,
         pc.commission,pc.set_discount,pc.final_discount
  from public.ks_pricing_categories pc
  where pc.id=v_id;
end;
$$;

revoke all on function public.keysuite_manage_pricing_category(text,text,numeric,numeric,numeric,numeric,numeric) from public;
grant execute on function public.keysuite_manage_pricing_category(text,text,numeric,numeric,numeric,numeric,numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- Reliable own-profile / signatory saving.
-- This avoids relying solely on auth.updateUser metadata and stores the
-- signature against the currently authenticated email.
-- ---------------------------------------------------------------------------
create or replace function public.keysuite_save_my_profile(
  p_display_name text,
  p_designation text,
  p_phone text,
  p_signatory_name text,
  p_signature_image text
)
returns table (
  email text,
  company_id text,
  display_name text,
  designation text,
  phone text,
  signatory_name text,
  signature_image text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_email text:=public.keysuite_current_email();
  v_company text:=public.keysuite_current_company_id();
  v_name text:=trim(coalesce(p_display_name,''));
begin
  if not public.keysuite_has_access() or v_email='' then
    raise exception 'Your login session is not active. Please sign in again.';
  end if;
  if v_name='' then raise exception 'Display Name is required.'; end if;

  insert into public.ks_user_profiles(
    email,company_id,display_name,designation,phone,signatory_name,signature_image,updated_at
  ) values (
    v_email,v_company,v_name,trim(coalesce(p_designation,'')),trim(coalesce(p_phone,'')),
    coalesce(nullif(trim(coalesce(p_signatory_name,'')),''),v_name),coalesce(p_signature_image,''),now()
  )
  on conflict on constraint ks_user_profiles_pkey do update set
    company_id=excluded.company_id,
    display_name=excluded.display_name,
    designation=excluded.designation,
    phone=excluded.phone,
    signatory_name=excluded.signatory_name,
    signature_image=excluded.signature_image,
    updated_at=excluded.updated_at;

  return query
  select p.email,p.company_id,p.display_name,p.designation,p.phone,p.signatory_name,p.signature_image,p.updated_at
  from public.ks_user_profiles p where lower(p.email)=v_email;
end;
$$;

revoke all on function public.keysuite_save_my_profile(text,text,text,text,text) from public;
grant execute on function public.keysuite_save_my_profile(text,text,text,text,text) to authenticated;

notify pgrst,'reload schema';
commit;

-- Verification:
-- select id,chc_source_currency,usd_multiplier,rmb_multiplier,currency_multiplier
-- from public.ks_app_settings where id='default';

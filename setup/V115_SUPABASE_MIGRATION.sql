-- KeySuite V1.15
-- Adds source currency and per-category currency multiplier.
-- Also replaces the category save function used by the V1.15 Category page.
-- Run after the V1.14 migration.

begin;

alter table public.ks_pricing_categories
  add column if not exists source_currency text not null default 'USD';

alter table public.ks_pricing_categories
  add column if not exists currency_multiplier numeric not null default 5.8000;

update public.ks_pricing_categories
set source_currency=upper(coalesce(nullif(trim(source_currency),''),'USD')),
    currency_multiplier=case
      when currency_multiplier is null or currency_multiplier<=0 then 5.8000
      else currency_multiplier
    end;

alter table public.ks_pricing_categories
  drop constraint if exists ks_pricing_categories_source_currency_check;

alter table public.ks_pricing_categories
  add constraint ks_pricing_categories_source_currency_check
  check (source_currency in ('USD','RMB'));

alter table public.ks_pricing_categories
  drop constraint if exists ks_pricing_categories_currency_multiplier_check;

alter table public.ks_pricing_categories
  add constraint ks_pricing_categories_currency_multiplier_check
  check (currency_multiplier>0);

-- Remove the earlier overload so PostgREST exposes only the current save function.
drop function if exists public.keysuite_manage_pricing_category(text,text,numeric,numeric,numeric,numeric,numeric);
drop function if exists public.keysuite_manage_pricing_category(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric);

create function public.keysuite_manage_pricing_category(
  p_category_id text,
  p_category_name text,
  p_source_currency text,
  p_currency_multiplier numeric,
  p_chc_margin numeric,
  p_transport numeric,
  p_commission numeric,
  p_set_discount numeric,
  p_final_discount numeric
)
returns table (
  category_id text,
  category_name text,
  source_currency text,
  currency_multiplier numeric,
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
  v_currency text:=upper(trim(coalesce(p_source_currency,'')));
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can manage pricing categories.';
  end if;
  if v_name='' then raise exception 'Category Name is required.'; end if;
  if v_currency not in ('USD','RMB') then raise exception 'Source Currency must be USD or RMB.'; end if;
  if p_currency_multiplier is null or p_currency_multiplier<=0 then raise exception 'Multiply must be greater than zero.'; end if;
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
      id,category_name,source_currency,currency_multiplier,
      final_discount,set_discount,commission,chc_factor,transport,chc_margin
    ) values (
      v_id,v_name,v_currency,p_currency_multiplier,
      p_final_discount,p_set_discount,p_commission,p_chc_margin,p_transport,p_chc_margin
    );
  else
    update public.ks_pricing_categories pc set
      category_name=v_name,
      source_currency=v_currency,
      currency_multiplier=p_currency_multiplier,
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
  select pc.id,pc.category_name,pc.source_currency,pc.currency_multiplier,
         pc.chc_margin,pc.transport,pc.commission,pc.set_discount,pc.final_discount
  from public.ks_pricing_categories pc
  where pc.id=v_id;
end;
$$;

revoke all on function public.keysuite_manage_pricing_category(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric) from public;
grant execute on function public.keysuite_manage_pricing_category(text,text,text,numeric,numeric,numeric,numeric,numeric,numeric) to authenticated;

notify pgrst,'reload schema';
commit;

-- Verification:
-- select category_name,source_currency,currency_multiplier,chc_margin,transport,
--        commission,set_discount,final_discount
-- from public.ks_pricing_categories order by category_name;

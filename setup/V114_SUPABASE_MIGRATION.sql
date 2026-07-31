-- KeySuite V1.14
-- Owner-only pricing category creation/editing and owner-only Fuel Price updates.
-- Run after the V1.13 migration.

begin;

-- Keep the correct margin field available for all categories.
alter table public.ks_pricing_categories
  add column if not exists chc_margin numeric;

update public.ks_pricing_categories
set chc_margin=coalesce(chc_margin,chc_factor,0)
where chc_margin is null;

alter table public.ks_pricing_categories
  drop constraint if exists ks_pricing_categories_chc_margin_check;

alter table public.ks_pricing_categories
  add constraint ks_pricing_categories_chc_margin_check
  check (chc_margin>=0 and chc_margin<1);

-- Owner-only create/update function. Internal Category IDs are generated and
-- returned to the application, but are never displayed in the dashboard.
create or replace function public.keysuite_manage_pricing_category(
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

-- Fuel Price is now maintained only through the Owner-only Key dashboard.
drop policy if exists keysuite_settings_admin_update on public.ks_app_settings;
drop policy if exists keysuite_settings_owner_update on public.ks_app_settings;
create policy keysuite_settings_owner_update
on public.ks_app_settings for update
to authenticated
using (
  public.keysuite_has_access()
  and public.keysuite_current_role()='owner'
)
with check (
  public.keysuite_has_access()
  and public.keysuite_current_role()='owner'
);

grant update (fuel_price) on table public.ks_app_settings to authenticated;

notify pgrst,'reload schema';
commit;

-- Verification:
-- select category_name,chc_margin,transport,commission,set_discount,final_discount
-- from public.ks_pricing_categories order by category_name;

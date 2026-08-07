-- KeySuite V3.1 / KeyAI OpenAI owner settings
-- Run in the SAME Supabase project used by KeySuite before deploying/testing keyai-openai.
begin;

alter table public.ks_app_settings
  add column if not exists keyai_openai_enabled boolean not null default false,
  add column if not exists keyai_openai_model text not null default 'gpt-5-mini',
  add column if not exists keyai_monthly_request_limit integer not null default 0,
  add column if not exists keyai_updated_at timestamptz,
  add column if not exists keyai_updated_by text;

create table if not exists public.ks_keyai_usage (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  provider text not null default 'openai',
  model text not null,
  purpose text not null default 'keyai',
  requested_by text,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0
);

alter table public.ks_keyai_usage enable row level security;
-- No direct browser table policies are created. Owner reads aggregated usage through the RPC below.

create or replace function public.keysuite_get_keyai_settings_v310()
returns table(
  openai_enabled boolean,
  openai_model text,
  monthly_request_limit integer,
  requests bigint,
  input_tokens bigint,
  output_tokens bigint
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can view KeyAI settings.';
  end if;
  return query
  select coalesce(s.keyai_openai_enabled,false),
         coalesce(nullif(s.keyai_openai_model,''),'gpt-5-mini'),
         greatest(0,coalesce(s.keyai_monthly_request_limit,0)),
         coalesce(u.requests,0),coalesce(u.input_tokens,0),coalesce(u.output_tokens,0)
  from public.ks_app_settings s
  left join lateral (
    select count(*)::bigint requests,
           coalesce(sum(k.input_tokens),0)::bigint input_tokens,
           coalesce(sum(k.output_tokens),0)::bigint output_tokens
    from public.ks_keyai_usage k
    where k.created_at>=date_trunc('month',now())
  ) u on true
  where s.id='default'
  limit 1;
end;
$$;

create or replace function public.keysuite_save_keyai_settings_v310(
  p_enabled boolean,
  p_model text,
  p_monthly_request_limit integer default 0
)
returns table(openai_enabled boolean,openai_model text,monthly_request_limit integer)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_model text:=trim(coalesce(p_model,''));
  v_count integer;
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can change KeyAI settings.';
  end if;
  if v_model='' or length(v_model)>100 then
    raise exception 'Enter a valid OpenAI model name.';
  end if;
  update public.ks_app_settings
     set keyai_openai_enabled=coalesce(p_enabled,false),
         keyai_openai_model=v_model,
         keyai_monthly_request_limit=greatest(0,coalesce(p_monthly_request_limit,0)),
         keyai_updated_at=now(),
         keyai_updated_by=public.keysuite_current_email()
   where id='default';
  get diagnostics v_count=row_count;
  if v_count=0 then raise exception 'Default KeySuite app settings row is missing.'; end if;
  return query select s.keyai_openai_enabled,s.keyai_openai_model,s.keyai_monthly_request_limit from public.ks_app_settings s where s.id='default';
end;
$$;

grant execute on function public.keysuite_get_keyai_settings_v310() to authenticated;
grant execute on function public.keysuite_save_keyai_settings_v310(boolean,text,integer) to authenticated;

notify pgrst,'reload schema';
commit;

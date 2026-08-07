-- KeySuite V3.4 / KeyAI conversation, persistent status and usage-cost improvements
-- Run AFTER V310_SUPABASE_MIGRATION.sql and V330_SUPABASE_MIGRATION.sql.
begin;

alter table public.ks_app_settings
  add column if not exists keyai_openai_last_test_at timestamptz,
  add column if not exists keyai_openai_last_test_ok boolean,
  add column if not exists keyai_openai_last_test_model text,
  add column if not exists keyai_openai_last_test_error text;

-- V3.4 starts with a conservative KeySuite-side guard. The Owner can change it later.
update public.ks_app_settings
   set keyai_monthly_request_limit=500
 where id='default' and coalesce(keyai_monthly_request_limit,0)=0;

alter table public.ks_keyai_usage
  add column if not exists cached_input_tokens integer not null default 0,
  add column if not exists estimated_cost_usd numeric(18,8);

-- Backfill V3.3 gpt-5-mini usage using the pricing known at the V3.4 build:
-- input $0.25 / 1M, cached input $0.025 / 1M, output $2.00 / 1M.
update public.ks_keyai_usage
   set estimated_cost_usd=(greatest(input_tokens-coalesce(cached_input_tokens,0),0)*0.25
                         +coalesce(cached_input_tokens,0)*0.025
                         +output_tokens*2.00)/1000000.0
 where estimated_cost_usd is null
   and lower(model) like 'gpt-5-mini%';

alter table public.ks_keyai_enquiries
  add column if not exists parent_enquiry_id uuid references public.ks_keyai_enquiries(id) on delete set null,
  add column if not exists conversation_id uuid,
  add column if not exists clarification_questions jsonb not null default '[]'::jsonb,
  add column if not exists clarification_question text;

update public.ks_keyai_enquiries
   set conversation_id=id
 where conversation_id is null and parent_enquiry_id is null;

create index if not exists ks_keyai_enquiries_parent_idx
  on public.ks_keyai_enquiries(parent_enquiry_id,created_at);
create index if not exists ks_keyai_enquiries_chat_status_idx
  on public.ks_keyai_enquiries(external_chat_id,status,updated_at desc);
create index if not exists ks_keyai_enquiries_conversation_idx
  on public.ks_keyai_enquiries(conversation_id,created_at);

create or replace function public.keysuite_get_keyai_settings_v340()
returns table(
  openai_enabled boolean,
  openai_model text,
  monthly_request_limit integer,
  requests bigint,
  input_tokens bigint,
  cached_input_tokens bigint,
  output_tokens bigint,
  estimated_cost_usd numeric,
  last_usage_at timestamptz,
  last_test_at timestamptz,
  last_test_ok boolean,
  last_test_model text,
  last_test_error text
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
         greatest(0,coalesce(s.keyai_monthly_request_limit,500)),
         coalesce(u.requests,0),
         coalesce(u.input_tokens,0),
         coalesce(u.cached_input_tokens,0),
         coalesce(u.output_tokens,0),
         coalesce(u.estimated_cost_usd,0),
         u.last_usage_at,
         s.keyai_openai_last_test_at,
         s.keyai_openai_last_test_ok,
         s.keyai_openai_last_test_model,
         s.keyai_openai_last_test_error
    from public.ks_app_settings s
    left join lateral (
      select count(*)::bigint requests,
             coalesce(sum(k.input_tokens),0)::bigint input_tokens,
             coalesce(sum(k.cached_input_tokens),0)::bigint cached_input_tokens,
             coalesce(sum(k.output_tokens),0)::bigint output_tokens,
             coalesce(sum(k.estimated_cost_usd),0)::numeric estimated_cost_usd,
             max(k.created_at) last_usage_at
        from public.ks_keyai_usage k
       where k.created_at>=date_trunc('month',now())
    ) u on true
   where s.id='default'
   limit 1;
end;
$$;

create or replace function public.keysuite_save_keyai_settings_v340(
  p_enabled boolean,
  p_model text,
  p_monthly_request_limit integer default 500
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
         keyai_monthly_request_limit=greatest(0,coalesce(p_monthly_request_limit,500)),
         keyai_updated_at=now(),
         keyai_updated_by=public.keysuite_current_email()
   where id='default';
  get diagnostics v_count=row_count;
  if v_count=0 then raise exception 'Default KeySuite app settings row is missing.'; end if;
  return query
  select s.keyai_openai_enabled,s.keyai_openai_model,s.keyai_monthly_request_limit
    from public.ks_app_settings s where s.id='default';
end;
$$;

create or replace function public.keysuite_list_keyai_enquiries_v340(p_limit integer default 50)
returns table(
  id uuid,
  source text,
  sender_username text,
  sender_name text,
  raw_message text,
  status text,
  ai_enabled boolean,
  ai_model text,
  ai_summary text,
  ai_result jsonb,
  ai_error text,
  clarification_questions jsonb,
  clarification_question text,
  conversation_id uuid,
  followups jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if public.keysuite_current_role()<>'owner' then
    raise exception 'Only the Owner can view the KeyAI Inbox.';
  end if;
  return query
  select e.id,e.source,e.sender_username,e.sender_name,e.raw_message,e.status,
         e.ai_enabled,e.ai_model,e.ai_summary,e.ai_result,e.ai_error,
         coalesce(e.clarification_questions,'[]'::jsonb),e.clarification_question,
         coalesce(e.conversation_id,e.id),
         coalesce((
           select jsonb_agg(jsonb_build_object(
             'id',c.id,
             'message',c.raw_message,
             'status',c.status,
             'created_at',c.created_at
           ) order by c.created_at)
             from public.ks_keyai_enquiries c
            where c.parent_enquiry_id=e.id
         ),'[]'::jsonb) as followups,
         e.created_at,e.updated_at
    from public.ks_keyai_enquiries e
   where e.parent_enquiry_id is null
   order by e.updated_at desc,e.created_at desc
   limit greatest(1,least(coalesce(p_limit,50),200));
end;
$$;

grant execute on function public.keysuite_get_keyai_settings_v340() to authenticated;
grant execute on function public.keysuite_save_keyai_settings_v340(boolean,text,integer) to authenticated;
grant execute on function public.keysuite_list_keyai_enquiries_v340(integer) to authenticated;

notify pgrst,'reload schema';
commit;

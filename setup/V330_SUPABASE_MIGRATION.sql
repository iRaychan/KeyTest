-- KeySuite V3.3 / KeyAI Telegram + OpenAI integration
-- Run AFTER V310_SUPABASE_MIGRATION.sql in the same Supabase project used by KeySuite.
begin;

create table if not exists public.ks_keyai_enquiries (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'telegram',
  external_update_id bigint,
  external_message_id bigint,
  external_chat_id text,
  sender_username text,
  sender_name text,
  raw_message text not null,
  status text not null default 'received',
  ai_enabled boolean not null default false,
  ai_model text,
  ai_summary text,
  ai_result jsonb,
  ai_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ks_keyai_enquiries_source_update_uq
  on public.ks_keyai_enquiries(source, external_update_id);
create index if not exists ks_keyai_enquiries_created_idx
  on public.ks_keyai_enquiries(created_at desc);

alter table public.ks_keyai_enquiries enable row level security;
-- No direct browser policies. The Owner reads the inbox only through the RPC below.

create or replace function public.keysuite_list_keyai_enquiries_v330(p_limit integer default 50)
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
         e.ai_enabled,e.ai_model,e.ai_summary,e.ai_result,e.ai_error,e.created_at,e.updated_at
    from public.ks_keyai_enquiries e
   order by e.created_at desc
   limit greatest(1,least(coalesce(p_limit,50),200));
end;
$$;

grant execute on function public.keysuite_list_keyai_enquiries_v330(integer) to authenticated;

notify pgrst,'reload schema';
commit;

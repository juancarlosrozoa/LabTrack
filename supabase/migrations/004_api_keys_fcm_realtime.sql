-- ============================================================
-- LabTrack — API Keys, FCM Tokens, Realtime
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- API KEYS  (for external REST API access, scoped per lab)
-- ────────────────────────────────────────────────────────────
create table api_keys (
  id         uuid primary key default gen_random_uuid(),
  lab_id     uuid not null references laboratories(id) on delete cascade,
  name       text not null,               -- e.g. "ERP integration"
  key_hash   text not null unique,        -- sha256 of the actual key
  created_by uuid not null references auth.users(id) on delete restrict,
  last_used_at timestamptz,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create index idx_api_keys_lab_id   on api_keys(lab_id);
create index idx_api_keys_key_hash on api_keys(key_hash);

alter table api_keys enable row level security;

create policy "admins can manage api keys"
  on api_keys for all
  using (get_lab_role(lab_id) = 'admin');

create policy "members can view api keys"
  on api_keys for select
  using (is_lab_member(lab_id));

-- ────────────────────────────────────────────────────────────
-- FCM TOKENS  (push notification device tokens)
-- ────────────────────────────────────────────────────────────
create table fcm_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  token      text not null,
  created_at timestamptz not null default now(),
  unique (user_id, token)
);

create index idx_fcm_tokens_user_id on fcm_tokens(user_id);

alter table fcm_tokens enable row level security;

-- Users can only manage their own tokens
create policy "users manage own fcm tokens"
  on fcm_tokens for all
  using (user_id = auth.uid());

-- ────────────────────────────────────────────────────────────
-- REALTIME — enable on tables the app subscribes to
-- ────────────────────────────────────────────────────────────
alter publication supabase_realtime add table lots;
alter publication supabase_realtime add table movements;
alter publication supabase_realtime add table restock_requests;
alter publication supabase_realtime add table alert_config;

-- ────────────────────────────────────────────────────────────
-- Helper: verify API key and return lab_id
-- Called from Edge Functions to authenticate external requests.
-- ────────────────────────────────────────────────────────────
create or replace function verify_api_key(p_key_hash text)
returns uuid
language plpgsql
security definer
as $$
declare
  v_lab_id uuid;
begin
  select lab_id into v_lab_id
  from api_keys
  where key_hash  = p_key_hash
    and is_active = true;

  if v_lab_id is null then
    raise exception 'Invalid or inactive API key';
  end if;

  -- Update last used timestamp
  update api_keys
     set last_used_at = now()
   where key_hash = p_key_hash;

  return v_lab_id;
end;
$$;

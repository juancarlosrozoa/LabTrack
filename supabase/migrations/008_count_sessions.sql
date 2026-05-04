-- Count session history (created by Scan & Count and Weekly Count flows)

create table if not exists count_sessions (
  id                uuid primary key default gen_random_uuid(),
  lab_id            uuid not null references laboratories(id) on delete cascade,
  counted_at        timestamptz not null,
  total_counted     int not null default 0,
  discrepancy_count int not null default 0,
  created_at        timestamptz not null default now()
);

create table if not exists count_session_items (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null references count_sessions(id) on delete cascade,
  product_id   uuid not null,
  product_name text not null,
  unit         text not null,
  expected     numeric not null,
  counted      numeric not null
);

-- Row-level security
alter table count_sessions      enable row level security;
alter table count_session_items enable row level security;

create policy "lab members can manage count sessions"
  on count_sessions for all
  using (
    lab_id in (
      select lab_id from lab_members
      where user_id = auth.uid()
    )
  );

create policy "lab members can manage count session items"
  on count_session_items for all
  using (
    session_id in (
      select id from count_sessions
      where lab_id in (
        select lab_id from lab_members
        where user_id = auth.uid()
      )
    )
  );

-- Performance indexes
create index if not exists count_sessions_lab_id_idx
  on count_sessions(lab_id, counted_at desc);

create index if not exists count_session_items_session_id_idx
  on count_session_items(session_id);

-- ============================================================
-- LabTrack — User Profiles + Lab Invitations
-- ============================================================

-- ── Profiles (public mirror of auth.users) ────────────────

create table profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  email        text,
  updated_at   timestamptz default now()
);

-- Populate from existing users
insert into profiles (id, email, display_name)
select
  id,
  email,
  coalesce(
    raw_user_meta_data->>'full_name',
    split_part(email, '@', 1)
  )
from auth.users
on conflict (id) do nothing;

-- Trigger: create profile on new signup
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- RLS
alter table profiles enable row level security;

create policy "users can see own or lab-member profiles"
  on profiles for select
  using (
    id = auth.uid()
    or id in (
      select lm.user_id from lab_members lm
      where lm.lab_id in (
        select lab_id from lab_members where user_id = auth.uid()
      )
    )
  );

create policy "users can update own profile"
  on profiles for update
  using (id = auth.uid());

-- ── Lab invitations ───────────────────────────────────────

create table lab_invitations (
  id         uuid primary key default gen_random_uuid(),
  lab_id     uuid not null references laboratories(id) on delete cascade,
  role       lab_role not null default 'viewer',
  code       text not null unique,
  invited_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  used_by    uuid references auth.users(id),
  used_at    timestamptz
);

create index idx_invitations_lab_id on lab_invitations(lab_id);
create index idx_invitations_code   on lab_invitations(code);

alter table lab_invitations enable row level security;

-- Admins/managers of a lab can manage its invitations
create policy "managers can manage lab invitations"
  on lab_invitations for all
  using (
    lab_id in (
      select lab_id from lab_members
      where user_id = auth.uid()
        and role in ('admin', 'manager')
    )
  );

-- ── RPC: validate an invitation code ─────────────────────

create or replace function validate_invitation(p_code text)
returns json language plpgsql security definer as $$
declare
  v_inv lab_invitations%rowtype;
  v_lab laboratories%rowtype;
begin
  select * into v_inv
  from lab_invitations
  where code = upper(p_code)
    and used_at is null
    and expires_at > now();

  if not found then
    return json_build_object('error', 'Invalid or expired code');
  end if;

  -- Already a member?
  if exists (
    select 1 from lab_members
    where lab_id = v_inv.lab_id and user_id = auth.uid()
  ) then
    return json_build_object('error', 'You are already a member of this laboratory');
  end if;

  select * into v_lab from laboratories where id = v_inv.lab_id;

  return json_build_object(
    'valid',    true,
    'lab_id',   v_inv.lab_id,
    'lab_name', v_lab.name,
    'role',     v_inv.role::text
  );
end;
$$;

-- ── RPC: redeem an invitation code ───────────────────────

create or replace function redeem_invitation(p_code text)
returns json language plpgsql security definer as $$
declare
  v_inv lab_invitations%rowtype;
  v_lab laboratories%rowtype;
begin
  select * into v_inv
  from lab_invitations
  where code = upper(p_code)
    and used_at is null
    and expires_at > now();

  if not found then
    return json_build_object('error', 'Invalid or expired code');
  end if;

  if exists (
    select 1 from lab_members
    where lab_id = v_inv.lab_id and user_id = auth.uid()
  ) then
    return json_build_object('error', 'You are already a member of this laboratory');
  end if;

  -- Join the lab
  insert into lab_members (lab_id, user_id, role)
  values (v_inv.lab_id, auth.uid(), v_inv.role);

  -- Mark invitation used
  update lab_invitations
  set used_by = auth.uid(), used_at = now()
  where id = v_inv.id;

  select * into v_lab from laboratories where id = v_inv.lab_id;

  return json_build_object(
    'success',  true,
    'lab_id',   v_inv.lab_id,
    'lab_name', v_lab.name,
    'lab_slug', v_lab.slug,
    'role',     v_inv.role::text
  );
end;
$$;

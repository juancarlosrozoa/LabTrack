-- ============================================================
-- LabTrack — Row Level Security
-- ============================================================
-- Strategy:
--   • All tables are scoped to lab_id.
--   • Access is granted only to authenticated users who are
--     members of that lab (via lab_members).
--   • Write operations require role >= analyst (for movements)
--     or role >= manager (for products, lots, config).
--     Admins can do everything including managing members.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- Helper: current user's role in a given lab
-- ────────────────────────────────────────────────────────────
create or replace function get_lab_role(p_lab_id uuid)
returns lab_role
language sql
security definer
stable
as $$
  select role
  from lab_members
  where lab_id = p_lab_id
    and user_id = auth.uid()
  limit 1;
$$;

-- Helper: is the current user a member of a lab?
create or replace function is_lab_member(p_lab_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from lab_members
    where lab_id = p_lab_id
      and user_id = auth.uid()
  );
$$;

-- ────────────────────────────────────────────────────────────
-- LABORATORIES
-- ────────────────────────────────────────────────────────────
alter table laboratories enable row level security;

-- Any member can view their lab
create policy "members can view their lab"
  on laboratories for select
  using (is_lab_member(id));

-- Only admins can update lab info
create policy "admins can update lab"
  on laboratories for update
  using (get_lab_role(id) = 'admin');

-- ────────────────────────────────────────────────────────────
-- LAB MEMBERS
-- ────────────────────────────────────────────────────────────
alter table lab_members enable row level security;

create policy "members can view lab roster"
  on lab_members for select
  using (is_lab_member(lab_id));

create policy "admins can manage members"
  on lab_members for all
  using (get_lab_role(lab_id) = 'admin');

-- ────────────────────────────────────────────────────────────
-- CATEGORIES
-- ────────────────────────────────────────────────────────────
alter table categories enable row level security;

create policy "members can view categories"
  on categories for select
  using (is_lab_member(lab_id));

create policy "managers and admins can manage categories"
  on categories for all
  using (get_lab_role(lab_id) in ('admin', 'manager'));

-- ────────────────────────────────────────────────────────────
-- STORAGE CONDITIONS
-- ────────────────────────────────────────────────────────────
alter table storage_conditions enable row level security;

create policy "members can view storage conditions"
  on storage_conditions for select
  using (is_lab_member(lab_id));

create policy "managers and admins can manage storage conditions"
  on storage_conditions for all
  using (get_lab_role(lab_id) in ('admin', 'manager'));

-- ────────────────────────────────────────────────────────────
-- LOCATIONS
-- ────────────────────────────────────────────────────────────
alter table locations enable row level security;

create policy "members can view locations"
  on locations for select
  using (is_lab_member(lab_id));

create policy "managers and admins can manage locations"
  on locations for all
  using (get_lab_role(lab_id) in ('admin', 'manager'));

-- ────────────────────────────────────────────────────────────
-- SUPPLIERS
-- ────────────────────────────────────────────────────────────
alter table suppliers enable row level security;

create policy "members can view suppliers"
  on suppliers for select
  using (is_lab_member(lab_id));

create policy "managers and admins can manage suppliers"
  on suppliers for all
  using (get_lab_role(lab_id) in ('admin', 'manager'));

-- ────────────────────────────────────────────────────────────
-- PRODUCTS
-- ────────────────────────────────────────────────────────────
alter table products enable row level security;

create policy "members can view products"
  on products for select
  using (is_lab_member(lab_id));

create policy "managers and admins can manage products"
  on products for all
  using (get_lab_role(lab_id) in ('admin', 'manager'));

-- ────────────────────────────────────────────────────────────
-- LOTS
-- ────────────────────────────────────────────────────────────
alter table lots enable row level security;

-- Lots don't have lab_id directly — join through products
create policy "members can view lots"
  on lots for select
  using (
    exists (
      select 1 from products p
      where p.id = lots.product_id
        and is_lab_member(p.lab_id)
    )
  );

create policy "analysts, managers and admins can manage lots"
  on lots for all
  using (
    exists (
      select 1 from products p
      where p.id = lots.product_id
        and get_lab_role(p.lab_id) in ('admin', 'manager', 'analyst')
    )
  );

-- ────────────────────────────────────────────────────────────
-- MOVEMENTS
-- ────────────────────────────────────────────────────────────
alter table movements enable row level security;

create policy "members can view movements"
  on movements for select
  using (is_lab_member(lab_id));

-- Analysts, managers, admins can register movements
create policy "analysts and above can insert movements"
  on movements for insert
  with check (
    get_lab_role(lab_id) in ('admin', 'manager', 'analyst')
    and user_id = auth.uid()
  );

-- Only admins/managers can delete movements (audit trail protection)
create policy "managers and admins can delete movements"
  on movements for delete
  using (get_lab_role(lab_id) in ('admin', 'manager'));

-- ────────────────────────────────────────────────────────────
-- RESTOCK REQUESTS
-- ────────────────────────────────────────────────────────────
alter table restock_requests enable row level security;

create policy "members can view restock requests"
  on restock_requests for select
  using (is_lab_member(lab_id));

create policy "analysts and above can create restock requests"
  on restock_requests for insert
  with check (
    get_lab_role(lab_id) in ('admin', 'manager', 'analyst')
    and requested_by = auth.uid()
  );

create policy "managers and admins can update restock requests"
  on restock_requests for update
  using (get_lab_role(lab_id) in ('admin', 'manager'));

-- ────────────────────────────────────────────────────────────
-- ALERT CONFIG
-- ────────────────────────────────────────────────────────────
alter table alert_config enable row level security;

create policy "members can view alert config"
  on alert_config for select
  using (is_lab_member(lab_id));

create policy "managers and admins can manage alert config"
  on alert_config for all
  using (get_lab_role(lab_id) in ('admin', 'manager'));

-- ────────────────────────────────────────────────────────────
-- WEBHOOKS
-- ────────────────────────────────────────────────────────────
alter table webhooks enable row level security;

create policy "members can view webhooks"
  on webhooks for select
  using (is_lab_member(lab_id));

create policy "admins can manage webhooks"
  on webhooks for all
  using (get_lab_role(lab_id) = 'admin');

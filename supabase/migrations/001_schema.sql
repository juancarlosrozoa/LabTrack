-- ============================================================
-- LabTrack — Initial Schema
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- LABORATORIES
-- ────────────────────────────────────────────────────────────
create table laboratories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text not null unique,
  created_at timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────
-- LAB MEMBERS  (users ↔ labs with roles)
-- ────────────────────────────────────────────────────────────
create type lab_role as enum ('admin', 'manager', 'analyst', 'viewer');

create table lab_members (
  id         uuid primary key default gen_random_uuid(),
  lab_id     uuid not null references laboratories(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       lab_role not null default 'viewer',
  created_at timestamptz not null default now(),
  unique (lab_id, user_id)
);

create index idx_lab_members_user_id on lab_members(user_id);
create index idx_lab_members_lab_id  on lab_members(lab_id);

-- ────────────────────────────────────────────────────────────
-- CATEGORIES
-- ────────────────────────────────────────────────────────────
create table categories (
  id         uuid primary key default gen_random_uuid(),
  lab_id     uuid not null references laboratories(id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now(),
  unique (lab_id, name)
);

-- ────────────────────────────────────────────────────────────
-- STORAGE CONDITIONS
-- ────────────────────────────────────────────────────────────
create table storage_conditions (
  id              uuid primary key default gen_random_uuid(),
  lab_id          uuid not null references laboratories(id) on delete cascade,
  name            text not null,             -- e.g. "Refrigerated 2–8 °C"
  temp_min        numeric(5,1),              -- °C
  temp_max        numeric(5,1),              -- °C
  humidity_max    numeric(5,1),              -- %
  light_sensitive boolean not null default false,
  created_at      timestamptz not null default now(),
  unique (lab_id, name)
);

-- ────────────────────────────────────────────────────────────
-- LOCATIONS  (rooms, fridges, shelves)
-- ────────────────────────────────────────────────────────────
create table locations (
  id                   uuid primary key default gen_random_uuid(),
  lab_id               uuid not null references laboratories(id) on delete cascade,
  name                 text not null,        -- e.g. "Fridge A", "Shelf B3"
  storage_condition_id uuid references storage_conditions(id) on delete set null,
  created_at           timestamptz not null default now(),
  unique (lab_id, name)
);

-- ────────────────────────────────────────────────────────────
-- SUPPLIERS
-- ────────────────────────────────────────────────────────────
create table suppliers (
  id            uuid primary key default gen_random_uuid(),
  lab_id        uuid not null references laboratories(id) on delete cascade,
  name          text not null,
  contact_email text,
  contact_phone text,
  created_at    timestamptz not null default now(),
  unique (lab_id, name)
);

-- ────────────────────────────────────────────────────────────
-- PRODUCTS
-- ────────────────────────────────────────────────────────────
create table products (
  id                     uuid primary key default gen_random_uuid(),
  lab_id                 uuid not null references laboratories(id) on delete cascade,
  name                   text not null,
  barcode                text unique,        -- null until assigned
  category_id            uuid references categories(id) on delete set null,
  unit                   text not null,      -- g, mL, units, etc.
  reorder_point          numeric(12,3) not null default 0,
  minimum_stock          numeric(12,3) not null default 0,
  estimated_delivery_days int not null default 7,
  default_location_id    uuid references locations(id) on delete set null,
  supplier_id            uuid references suppliers(id) on delete set null,
  storage_condition_id   uuid references storage_conditions(id) on delete set null,
  is_active              boolean not null default true,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create index idx_products_lab_id  on products(lab_id);
create index idx_products_barcode on products(barcode) where barcode is not null;

-- ────────────────────────────────────────────────────────────
-- LOTS  (FEFO — First Expired, First Out)
-- ────────────────────────────────────────────────────────────
create table lots (
  id              uuid primary key default gen_random_uuid(),
  product_id      uuid not null references products(id) on delete cascade,
  lot_number      text not null,
  quantity        numeric(12,3) not null default 0 check (quantity >= 0),
  expiration_date date not null,
  location_id     uuid references locations(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (product_id, lot_number)
);

create index idx_lots_product_id      on lots(product_id);
create index idx_lots_expiration_date on lots(expiration_date);

-- ────────────────────────────────────────────────────────────
-- MOVEMENTS  (entry | exit | adjustment | return)
-- ────────────────────────────────────────────────────────────
create type movement_type as enum ('entry', 'exit', 'adjustment', 'return');

create table movements (
  id         uuid primary key default gen_random_uuid(),
  lab_id     uuid not null references laboratories(id) on delete cascade,
  product_id uuid not null references products(id) on delete restrict,
  lot_id     uuid references lots(id) on delete set null,
  type       movement_type not null,
  -- For entry/exit/return: positive quantity.
  -- For adjustment: signed delta (negative = stock was lower than expected).
  quantity   numeric(12,3) not null,
  reason     text,
  area       text,
  project    text,
  user_id    uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create index idx_movements_lab_id     on movements(lab_id);
create index idx_movements_product_id on movements(product_id);
create index idx_movements_created_at on movements(created_at desc);

-- ────────────────────────────────────────────────────────────
-- RESTOCK REQUESTS
-- ────────────────────────────────────────────────────────────
create type restock_status as enum ('pending', 'ordered', 'received', 'cancelled');

create table restock_requests (
  id                 uuid primary key default gen_random_uuid(),
  lab_id             uuid not null references laboratories(id) on delete cascade,
  product_id         uuid not null references products(id) on delete restrict,
  requested_quantity numeric(12,3) not null,
  status             restock_status not null default 'pending',
  external_reference text,                   -- ERP / PO number
  requested_by       uuid not null references auth.users(id) on delete restrict,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index idx_restock_lab_id    on restock_requests(lab_id);
create index idx_restock_status    on restock_requests(status);

-- ────────────────────────────────────────────────────────────
-- ALERT CONFIG  (per lab or per product)
-- ────────────────────────────────────────────────────────────
create table alert_config (
  id                             uuid primary key default gen_random_uuid(),
  lab_id                         uuid not null references laboratories(id) on delete cascade,
  product_id                     uuid references products(id) on delete cascade,  -- null = lab-wide
  expiry_alert_days              int[] not null default '{30,60,90}',
  reorder_notifications          boolean not null default true,
  critical_stock_notifications   boolean not null default true,
  recipients                     text[] not null default '{}',
  created_at                     timestamptz not null default now(),
  unique (lab_id, product_id)    -- one config per lab or per product
);

-- ────────────────────────────────────────────────────────────
-- WEBHOOKS  (outbound events to external systems)
-- ────────────────────────────────────────────────────────────
create table webhooks (
  id         uuid primary key default gen_random_uuid(),
  lab_id     uuid not null references laboratories(id) on delete cascade,
  url        text not null,
  events     text[] not null default '{}',
  -- events: critical_stock | expiring_soon | lot_expired |
  --         entry_registered | adjustment_approved
  secret     text,                           -- HMAC signing secret
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- ────────────────────────────────────────────────────────────
-- VIEWS
-- ────────────────────────────────────────────────────────────

-- Current total stock per product (sum of all lots)
create view product_stock as
  select
    p.id            as product_id,
    p.lab_id,
    p.name,
    p.unit,
    p.reorder_point,
    p.minimum_stock,
    coalesce(sum(l.quantity), 0) as total_quantity,
    case
      when coalesce(sum(l.quantity), 0) = 0            then 'out_of_stock'
      when coalesce(sum(l.quantity), 0) <= p.minimum_stock  then 'critical'
      when coalesce(sum(l.quantity), 0) <= p.reorder_point  then 'reorder'
      else 'ok'
    end             as stock_status
  from products p
  left join lots l on l.product_id = p.id and l.quantity > 0
  where p.is_active = true
  group by p.id;

-- Lots expiring within 90 days (FEFO order)
create view lots_expiring_soon as
  select
    l.*,
    p.name          as product_name,
    p.unit,
    p.lab_id,
    (l.expiration_date - current_date) as days_until_expiry
  from lots l
  join products p on p.id = l.product_id
  where l.quantity > 0
    and l.expiration_date <= current_date + interval '90 days'
  order by l.expiration_date asc;

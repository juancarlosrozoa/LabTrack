-- ============================================================
-- LabTrack — Triggers & Functions
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- updated_at auto-maintenance
-- ────────────────────────────────────────────────────────────
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_products_updated_at
  before update on products
  for each row execute function set_updated_at();

create trigger trg_lots_updated_at
  before update on lots
  for each row execute function set_updated_at();

create trigger trg_restock_updated_at
  before update on restock_requests
  for each row execute function set_updated_at();

-- ────────────────────────────────────────────────────────────
-- Apply movement → update lot quantity (FEFO)
-- ────────────────────────────────────────────────────────────
-- When a movement is inserted and has a lot_id, the lot's
-- quantity is adjusted automatically:
--   entry  / return  → quantity += movement.quantity
--   exit             → quantity -= movement.quantity
--   adjustment       → quantity += movement.quantity  (signed delta)
-- ────────────────────────────────────────────────────────────
create or replace function apply_movement_to_lot()
returns trigger
language plpgsql
as $$
begin
  if new.lot_id is null then
    return new;
  end if;

  case new.type
    when 'entry', 'return' then
      update lots
        set quantity = quantity + new.quantity
      where id = new.lot_id;

    when 'exit' then
      update lots
        set quantity = quantity - new.quantity
      where id = new.lot_id;

      -- Prevent negative stock
      if (select quantity from lots where id = new.lot_id) < 0 then
        raise exception
          'Insufficient stock in lot %. Available: %, requested: %',
          new.lot_id,
          (select quantity + new.quantity from lots where id = new.lot_id),
          new.quantity;
      end if;

    when 'adjustment' then
      -- quantity is a signed delta
      update lots
        set quantity = quantity + new.quantity
      where id = new.lot_id;

      if (select quantity from lots where id = new.lot_id) < 0 then
        raise exception
          'Adjustment would result in negative stock for lot %.',
          new.lot_id;
      end if;
  end case;

  return new;
end;
$$;

create trigger trg_apply_movement
  after insert on movements
  for each row execute function apply_movement_to_lot();

-- ────────────────────────────────────────────────────────────
-- Auto-generate restock request on critical stock
-- ────────────────────────────────────────────────────────────
-- After a lot update (triggered by exit/adjustment), check if
-- total product stock has dropped to or below reorder_point.
-- If so, and no pending request exists, create one automatically.
-- ────────────────────────────────────────────────────────────
create or replace function auto_restock_request()
returns trigger
language plpgsql
as $$
declare
  v_product   products%rowtype;
  v_total_qty numeric;
  v_lab_id    uuid;
begin
  -- Get the product for this lot
  select * into v_product from products where id = new.product_id;
  v_lab_id := v_product.lab_id;

  -- Total stock across all lots
  select coalesce(sum(quantity), 0)
    into v_total_qty
    from lots
   where product_id = new.product_id;

  -- Only act if stock is at or below reorder point
  if v_total_qty > v_product.reorder_point then
    return new;
  end if;

  -- Skip if a pending request already exists
  if exists (
    select 1 from restock_requests
    where product_id = new.product_id
      and status = 'pending'
  ) then
    return new;
  end if;

  -- Insert automatic restock request
  -- Uses the lab's first admin as requested_by (fallback)
  insert into restock_requests (
    lab_id, product_id, requested_quantity, status, requested_by
  )
  select
    v_lab_id,
    v_product.id,
    v_product.reorder_point,   -- request up to reorder point
    'pending',
    user_id
  from lab_members
  where lab_id = v_lab_id
    and role = 'admin'
  limit 1;

  return new;
end;
$$;

create trigger trg_auto_restock
  after update on lots
  for each row
  when (new.quantity < old.quantity)   -- only on stock decrease
  execute function auto_restock_request();

-- ────────────────────────────────────────────────────────────
-- Utility function: get current stock for a product
-- ────────────────────────────────────────────────────────────
create or replace function get_product_stock(p_product_id uuid)
returns numeric
language sql
stable
as $$
  select coalesce(sum(quantity), 0)
  from lots
  where product_id = p_product_id;
$$;

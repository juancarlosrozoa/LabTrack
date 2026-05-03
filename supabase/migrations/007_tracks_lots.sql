-- Add tracks_lots and direct_quantity to products.
-- Products with tracks_lots = false use direct_quantity for stock instead of lots.

alter table products
  add column if not exists tracks_lots      boolean not null default true,
  add column if not exists direct_quantity  numeric not null default 0;

-- Recreate product_stock view to include direct_quantity for non-lot products
drop view if exists product_stock;

create view product_stock as
  select
    p.id            as product_id,
    p.lab_id,
    p.name,
    p.unit,
    p.reorder_point,
    p.minimum_stock,
    p.tracks_lots,
    case
      when p.tracks_lots then coalesce(sum(l.quantity), 0)
      else p.direct_quantity
    end as total_quantity,
    case
      when p.tracks_lots then
        case
          when coalesce(sum(l.quantity), 0) = 0           then 'out_of_stock'
          when coalesce(sum(l.quantity), 0) <= p.minimum_stock then 'critical'
          when coalesce(sum(l.quantity), 0) <= p.reorder_point then 'reorder'
          else 'ok'
        end
      else
        case
          when p.direct_quantity = 0           then 'out_of_stock'
          when p.direct_quantity <= p.minimum_stock then 'critical'
          when p.direct_quantity <= p.reorder_point then 'reorder'
          else 'ok'
        end
    end as stock_status
  from products p
  left join lots l on l.product_id = p.id
                   and l.quantity > 0
                   and p.tracks_lots = true
  where p.is_active = true
  group by p.id;

-- Update apply_movement_to_lot trigger to handle non-lot products
create or replace function apply_movement_to_lot()
returns trigger
language plpgsql
as $$
declare
  v_tracks_lots boolean;
begin
  select tracks_lots into v_tracks_lots from products where id = new.product_id;

  -- Non-lot product: update direct_quantity on products table
  if not v_tracks_lots then
    case new.type
      when 'entry', 'return' then
        update products set direct_quantity = direct_quantity + new.quantity
        where id = new.product_id;
      when 'exit' then
        if (select direct_quantity from products where id = new.product_id) < new.quantity then
          raise exception 'Insufficient stock for product %', new.product_id;
        end if;
        update products set direct_quantity = direct_quantity - new.quantity
        where id = new.product_id;
      when 'adjustment' then
        update products set direct_quantity = direct_quantity + new.quantity
        where id = new.product_id;
    end case;
    return new;
  end if;

  -- Lot-tracked product: original logic
  if new.lot_id is null then
    return new;
  end if;

  case new.type
    when 'entry', 'return' then
      update lots set quantity = quantity + new.quantity where id = new.lot_id;
    when 'exit' then
      update lots set quantity = quantity - new.quantity where id = new.lot_id;
      if (select quantity from lots where id = new.lot_id) < 0 then
        raise exception 'Insufficient stock in lot %. Available: %, requested: %',
          new.lot_id,
          (select quantity + new.quantity from lots where id = new.lot_id),
          new.quantity;
      end if;
    when 'adjustment' then
      update lots set quantity = quantity + new.quantity where id = new.lot_id;
      if (select quantity from lots where id = new.lot_id) < 0 then
        raise exception 'Adjustment would result in negative stock for lot %', new.lot_id;
      end if;
  end case;

  return new;
end;
$$;

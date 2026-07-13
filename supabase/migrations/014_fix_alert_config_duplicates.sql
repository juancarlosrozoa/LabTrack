-- Fix: Settings > Alert Config shows "Something went wrong" because
-- upsert(onConflict: 'lab_id,product_id') never matches existing rows
-- where product_id is null — Postgres treats NULL <> NULL in unique
-- constraints, so every save() call inserted a new row instead of
-- updating one. .maybeSingle() then throws client-side once a lab has
-- more than one lab-wide (product_id null) alert_config row.

-- Keep the most recently created row per lab for the lab-wide config,
-- drop the rest.
delete from alert_config a
using alert_config b
where a.lab_id = b.lab_id
  and a.product_id is null
  and b.product_id is null
  and a.created_at < b.created_at;

-- Replace the constraint so NULLs are treated as equal for uniqueness,
-- matching what the upsert's onConflict target expects.
alter table alert_config
  drop constraint alert_config_lab_id_product_id_key;

alter table alert_config
  add constraint alert_config_lab_id_product_id_key
  unique nulls not distinct (lab_id, product_id);

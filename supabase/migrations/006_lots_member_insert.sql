-- Allow any lab member to insert lots (needed when registering entry movements).
-- Update and delete remain restricted to analysts and above.

-- Drop the combined policy and replace with separate per-operation policies.
drop policy if exists "analysts, managers and admins can manage lots" on lots;

create policy "members can insert lots"
  on lots for insert
  with check (
    exists (
      select 1 from products p
      where p.id = lots.product_id
        and is_lab_member(p.lab_id)
    )
  );

create policy "analysts and above can update and delete lots"
  on lots for update
  using (
    exists (
      select 1 from products p
      where p.id = lots.product_id
        and get_lab_role(p.lab_id) in ('admin', 'manager', 'analyst')
    )
  );

create policy "analysts and above can delete lots"
  on lots for delete
  using (
    exists (
      select 1 from products p
      where p.id = lots.product_id
        and get_lab_role(p.lab_id) in ('admin', 'manager', 'analyst')
    )
  );

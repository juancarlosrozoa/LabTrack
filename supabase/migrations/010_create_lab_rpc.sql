-- ============================================================
-- LabTrack — Create Laboratory RPC
-- ============================================================

-- Atomically creates a laboratory and adds the caller as admin.
-- Runs security definer to bypass RLS on laboratories/lab_members.
create or replace function create_laboratory(p_name text)
returns json language plpgsql security definer as $$
declare
  v_base    text;
  v_slug    text;
  v_lab_id  uuid;
  v_counter int := 0;
begin
  if auth.uid() is null then
    return json_build_object('error', 'Not authenticated');
  end if;

  p_name := trim(p_name);
  if length(p_name) < 2 then
    return json_build_object('error', 'Lab name must be at least 2 characters');
  end if;

  -- Derive URL-safe slug from name
  v_base := lower(regexp_replace(p_name, '[^a-zA-Z0-9]+', '-', 'g'));
  v_base := trim(both '-' from v_base);
  v_slug := v_base;

  -- Append counter until slug is unique
  loop
    exit when not exists (select 1 from laboratories where slug = v_slug);
    v_counter := v_counter + 1;
    v_slug    := v_base || '-' || v_counter::text;
  end loop;

  -- Create lab + add creator as admin in one transaction
  insert into laboratories (name, slug)
  values (p_name, v_slug)
  returning id into v_lab_id;

  insert into lab_members (lab_id, user_id, role)
  values (v_lab_id, auth.uid(), 'admin');

  return json_build_object(
    'lab_id',   v_lab_id,
    'lab_name', p_name,
    'lab_slug', v_slug,
    'role',     'admin'
  );
end;
$$;

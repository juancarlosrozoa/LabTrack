-- transfer_admin: current admin hands off the admin role to another member
create or replace function transfer_admin(
  p_lab_id      uuid,
  p_user_id     uuid,
  p_my_new_role lab_role
) returns void language plpgsql security definer as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'Not authenticated'; end if;

  -- caller must be admin of this lab
  if not exists (
    select 1 from lab_members
    where lab_id = p_lab_id and user_id = v_me and role = 'admin'
  ) then raise exception 'Not authorized'; end if;

  -- target must be a member of this lab
  if not exists (
    select 1 from lab_members
    where lab_id = p_lab_id and user_id = p_user_id
  ) then raise exception 'Target user is not a member of this lab'; end if;

  -- promote target to admin
  update lab_members
    set role = 'admin'
  where lab_id = p_lab_id and user_id = p_user_id;

  -- demote caller
  update lab_members
    set role = p_my_new_role
  where lab_id = p_lab_id and user_id = v_me;
end;
$$;

-- delete_own_account: delete auth user after ensuring they're not a sole admin
create or replace function delete_own_account()
returns void language plpgsql security definer as $$
declare
  v_me     uuid := auth.uid();
  v_lab_id uuid;
begin
  if v_me is null then raise exception 'Not authenticated'; end if;

  -- block if sole admin of any lab
  for v_lab_id in
    select lab_id from lab_members
    where user_id = v_me and role = 'admin'
  loop
    if (
      select count(*) from lab_members
      where lab_id = v_lab_id and role = 'admin'
    ) = 1 then
      raise exception 'You are the sole admin of a laboratory. Transfer admin or delete the lab before deleting your account.';
    end if;
  end loop;

  delete from auth.users where id = v_me;
end;
$$;

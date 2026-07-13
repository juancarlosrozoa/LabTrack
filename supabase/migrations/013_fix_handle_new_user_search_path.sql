-- Fix: new user signup fails with "Database error saving new user" /
-- 42P01 "relation profiles does not exist". handle_new_user() is
-- SECURITY DEFINER but never fixed its search_path, so when the trigger
-- fires from auth.users (a different search_path context) the
-- unqualified `profiles` reference can't be resolved.

create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name)
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

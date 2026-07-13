-- Fix: Members screen fails with "Something went wrong" because PostgREST
-- cannot resolve the embedded `profiles(display_name, email)` select on
-- lab_members — there was no FK from lab_members.user_id to profiles.id
-- (only to auth.users.id, which PostgREST does not use for embedding).

alter table lab_members
  add constraint lab_members_user_id_profiles_fkey
  foreign key (user_id) references profiles(id) on delete cascade;

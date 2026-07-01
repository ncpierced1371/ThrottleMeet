-- Reserve an optional profile avatar URL for the controlled beta profile UI.
--
-- This migration does not add uploads or storage policies. Existing profile
-- self-access RLS policies continue to restrict reads and writes to auth.uid().

alter table public.profiles
add column if not exists avatar_url text;

comment on column public.profiles.avatar_url is
  'Optional externally hosted avatar URL. Upload support is intentionally deferred.';

grant insert (avatar_url) on public.profiles to authenticated;
grant update (avatar_url) on public.profiles to authenticated;

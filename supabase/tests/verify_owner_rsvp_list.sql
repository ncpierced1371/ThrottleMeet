-- Verify the authenticated owner-only RSVP list contract.
--
-- Run manually after all migrations with a local/staging database-owner
-- session that may insert auth.users fixtures and SET ROLE. The transaction is
-- rolled back, so no fixture data persists.

begin;

delete from public.events
where id in (
  'owner-rsvp-list-event',
  'owner-rsvp-list-ownerless-event'
);

delete from auth.users
where id in (
  '40000000-0000-4000-8000-000000000001'::uuid,
  '40000000-0000-4000-8000-000000000002'::uuid
);

insert into auth.users (id)
values
  ('40000000-0000-4000-8000-000000000001'::uuid),
  ('40000000-0000-4000-8000-000000000002'::uuid);

insert into public.profiles (id, display_name, avatar_url)
values
  (
    '40000000-0000-4000-8000-000000000001'::uuid,
    'Owner Driver',
    'https://example.com/owner.jpg'
  ),
  (
    '40000000-0000-4000-8000-000000000002'::uuid,
    null,
    null
  );

insert into public.events (
  id,
  title,
  description,
  location_name,
  host_name,
  start_time,
  end_time,
  creator_id
) values
  (
    'owner-rsvp-list-event',
    'Owner RSVP List Fixture',
    'Owner-only RSVP verification',
    'Local Test Garage',
    'Owner Driver',
    pg_catalog.now() + interval '2 days',
    pg_catalog.now() + interval '2 days 2 hours',
    '40000000-0000-4000-8000-000000000001'::uuid
  ),
  (
    'owner-rsvp-list-ownerless-event',
    'Ownerless RSVP List Fixture',
    'Retained legacy ownerless fixture',
    'Legacy Garage',
    'Legacy Host',
    pg_catalog.now() + interval '3 days',
    pg_catalog.now() + interval '3 days 2 hours',
    null
  );

insert into public.event_rsvps (event_id, user_id, status)
values
  (
    'owner-rsvp-list-event',
    '40000000-0000-4000-8000-000000000001'::uuid,
    'going'
  ),
  (
    'owner-rsvp-list-event',
    '40000000-0000-4000-8000-000000000002'::uuid,
    'interested'
  );

-- This retained legacy row must remain stored but never appear in the v1
-- authenticated owner list.
insert into public.event_rsvps (event_id, participant_id, status)
values ('owner-rsvp-list-event', 'legacy-list-participant', 'going');

select pg_catalog.set_config('request.jwt.claim.sub', '', true);
set local role anon;

do $$
declare
  rejected boolean := false;
begin
  begin
    perform public.get_event_rsvps_for_owner_v1('owner-rsvp-list-event');
  exception
    when insufficient_privilege then rejected := true;
  end;

  if not rejected then
    raise exception 'anon unexpectedly executed owner RSVP list RPC';
  end if;
end;
$$;

reset role;

-- A different authenticated user must not read the owner's attendee list.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '40000000-0000-4000-8000-000000000002',
  true
);
set local role authenticated;

do $$
declare
  rejected boolean := false;
begin
  begin
    perform public.get_event_rsvps_for_owner_v1('owner-rsvp-list-event');
  exception
    when insufficient_privilege then rejected := true;
  end;

  if not rejected then
    raise exception 'non-owner unexpectedly read the owner RSVP list';
  end if;
end;
$$;

reset role;

-- The owner may read authenticated RSVP rows, including nullable profile
-- fields, but no legacy identity or auth metadata may be returned.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '40000000-0000-4000-8000-000000000001',
  true
);
set local role authenticated;

do $$
declare
  payload jsonb;
  ownerless_rejected boolean := false;
  missing_rejected boolean := false;
begin
  select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(rsvp_row))
  into payload
  from public.get_event_rsvps_for_owner_v1(
    'owner-rsvp-list-event'
  ) as rsvp_row;

  if pg_catalog.jsonb_array_length(payload) is distinct from 2 then
    raise exception 'owner RSVP list did not return exactly two authenticated rows';
  end if;

  if not payload @> '[{"display_name":"Owner Driver","avatar_url":"https://example.com/owner.jpg","status":"going"}]'::jsonb
    or not payload @> '[{"display_name":null,"avatar_url":null,"status":"interested"}]'::jsonb then
    raise exception 'owner RSVP list profile/status projection is incorrect';
  end if;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(payload) as items(item),
      lateral pg_catalog.jsonb_object_keys(items.item) as keys(key_name)
    where key_name not in (
      'user_id',
      'display_name',
      'avatar_url',
      'status',
      'updated_at'
    )
  ) then
    raise exception 'owner RSVP list exposed unexpected metadata';
  end if;

  begin
    perform public.get_event_rsvps_for_owner_v1(
      'owner-rsvp-list-ownerless-event'
    );
  exception
    when insufficient_privilege then ownerless_rejected := true;
  end;

  if not ownerless_rejected then
    raise exception 'ownerless event unexpectedly exposed an RSVP list';
  end if;

  begin
    perform public.get_event_rsvps_for_owner_v1(
      'owner-rsvp-list-missing-event'
    );
  exception
    when no_data_found then missing_rejected := true;
  end;

  if not missing_rejected then
    raise exception 'missing event did not produce the expected rejection';
  end if;
end;
$$;

reset role;

do $$
declare
  retained_legacy_rows integer;
begin
  select count(*)
  into retained_legacy_rows
  from public.event_rsvps as rsvps
  where rsvps.event_id = 'owner-rsvp-list-event'
    and rsvps.user_id is null
    and rsvps.participant_id = 'legacy-list-participant';

  if retained_legacy_rows is distinct from 1 then
    raise exception 'legacy RSVP fixture was not retained';
  end if;
end;
$$;

rollback;

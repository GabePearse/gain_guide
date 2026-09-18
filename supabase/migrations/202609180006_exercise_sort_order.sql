alter table public.exercises add column if not exists sort_order integer not null default 0;

with ranked as (
  select id, row_number() over (partition by workout_id order by id) - 1 as position
  from public.exercises
)
update public.exercises e set sort_order = ranked.position from ranked where ranked.id = e.id;

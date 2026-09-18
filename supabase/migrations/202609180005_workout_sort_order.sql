alter table public.workouts add column if not exists sort_order integer not null default 0;

with ranked as (
  select id, row_number() over (partition by user_id order by id) - 1 as position
  from public.workouts
)
update public.workouts w set sort_order = ranked.position from ranked where ranked.id = w.id;

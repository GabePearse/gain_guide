-- All health state is separate from workout history. The grant revision also
-- binds a consent decision to one installation, invalidating stale uploads.
create table public.health_connection (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  revision uuid not null default gen_random_uuid(),
  categories text[] not null check (categories <@ array['activity','body','nutrition','recovery']),
  lookback integer not null check (lookback between 1 and 3650),
  zone text not null,
  since timestamptz not null,
  consented_at timestamptz not null default now(),
  last_success timestamptz
);
create table public.health_checkpoint (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  metric text not null, anchor text not null, dirty boolean not null,
  primary key (user_id,metric)
);
create table public.health_sample (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  seen_revision uuid not null, id uuid not null, metric text not null, identifier text not null,
  started timestamptz not null, ended timestamptz not null check (ended >= started),
  source text not null, bundle text not null, zone text not null,
  value double precision not null, unit text not null,
  primary key (user_id,id)
);
create index health_sample_history on public.health_sample(user_id,metric,started);
create index health_sample_export on public.health_sample(user_id,started,id);
create table public.health_stat (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  day date not null, metric text not null, unit text not null,
  value double precision not null, zone text not null,
  primary key(user_id,day,metric)
);
do $$
declare t text;
begin
  foreach t in array array['health_connection','health_checkpoint','health_sample','health_stat'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public, anon, authenticated',t);
    execute format('grant select, insert, update, delete on public.%I to authenticated',t);
    execute format('create policy own on public.%I for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))',t);
  end loop;
end $$;

create function public.health_configure(owner uuid, selected text[], days integer, timezone_name text)
returns uuid language plpgsql security invoker set search_path = public, pg_temp as $$
declare rev uuid := gen_random_uuid();
begin
  if owner is distinct from auth.uid() or owner is null then raise exception 'Account changed'; end if;
  perform pg_advisory_xact_lock(hashtextextended(owner::text,0));
  insert into health_connection(user_id,revision,categories,lookback,zone,since)
  values(owner,rev,selected,days,timezone_name,
    (date_trunc('day',now() at time zone timezone_name) - make_interval(days=>days-1)) at time zone timezone_name)
  on conflict(user_id) do update set revision=rev, categories=selected, lookback=days,
    zone=excluded.zone,since=excluded.since,consented_at=now();
  delete from health_checkpoint where user_id=owner;
  return rev;
end $$;

create function public.health_disconnect(owner uuid, erase boolean)
returns void language plpgsql security invoker set search_path = public, pg_temp as $$
begin
  if owner is distinct from auth.uid() or owner is null then raise exception 'Account changed'; end if;
  perform pg_advisory_xact_lock(hashtextextended(owner::text,0));
  delete from health_connection where user_id=owner;
  delete from health_checkpoint where user_id=owner;
  if erase then
    delete from health_sample where user_id=owner;
    delete from health_stat where user_id=owner;
  end if;
end $$;

create function public.health_apply(owner uuid, grant_id uuid, kind text, previous text,
  next_anchor text, samples jsonb, removed uuid[], totals jsonb, pending boolean)
returns void language plpgsql security invoker set search_path = public, pg_temp as $$
declare cfg health_connection; category text;
begin
  if owner is distinct from auth.uid() or owner is null then raise exception 'Account changed'; end if;
  perform pg_advisory_xact_lock(hashtextextended(owner::text,0));
  select * into cfg from health_connection where user_id=owner and revision=grant_id;
  category := case when kind in ('steps','active_energy','resting_energy','distance','exercise') then 'activity'
    when kind in ('weight','body_fat','lean_mass','bmi') then 'body'
    when kind in ('calories','protein','carbs','fat','fibre','water') then 'nutrition'
    when kind in ('sleep','resting_hr','hrv','respiration') then 'recovery' end;
  if cfg.user_id is null or category is null or not(category=any(cfg.categories)) then raise exception 'Consent changed'; end if;
  if (select anchor from health_checkpoint where user_id=owner and metric=kind) is distinct from previous then raise exception 'Checkpoint changed'; end if;
  insert into health_sample(user_id,seen_revision,id,metric,identifier,started,ended,source,bundle,zone,value,unit)
    select owner,grant_id,s.id,kind,s.identifier,s.started,s.ended,s.source,s.bundle,cfg.zone,s.value,s.unit
    from jsonb_to_recordset(samples) s(id uuid, identifier text, started timestamptz, ended timestamptz, source text,bundle text,value float8,unit text)
    on conflict(user_id,id) do update set seen_revision=excluded.seen_revision,started=excluded.started,ended=excluded.ended,value=excluded.value,
      source=excluded.source,bundle=excluded.bundle,zone=excluded.zone,unit=excluded.unit;
  delete from health_sample where user_id=owner and metric=kind and id=any(removed);
  if not pending then
    -- A new grant starts with a full snapshot. Reconcile only its imported
    -- window, after every page has landed, including samples removed offline.
    delete from health_sample where user_id=owner and metric=kind and started >= cfg.since and seen_revision<>grant_id;
  end if;
  if totals is not null then
    delete from health_stat where user_id=owner and metric=kind and day >= (cfg.since at time zone cfg.zone)::date;
    insert into health_stat(user_id,day,metric,unit,value,zone)
      select owner,s.day,kind,s.unit,s.value,cfg.zone from jsonb_to_recordset(totals) s(day date,unit text,value float8);
  end if;
  insert into health_checkpoint values(owner,kind,next_anchor,pending)
    on conflict(user_id,metric) do update set anchor=excluded.anchor,dirty=excluded.dirty;
end $$;

-- Split asleep intervals at reporting-zone midnight. Union overlapping stages
-- and sources before summing duration (including across DST transitions).
create view public.health_daily with (security_invoker=true) as
select user_id,day,metric,unit,value from public.health_stat
union all
select user_id,(started at time zone zone)::date,metric,unit,
  case when metric in ('weight','lean_mass','body_fat','bmi') then
    (array_agg(value order by started desc,id))[1] else avg(value) end
from public.health_sample where metric in ('weight','lean_mass','body_fat','bmi','resting_hr','hrv','respiration')
group by user_id,(started at time zone zone)::date,metric,unit
union all
select user_id,day,'sleep','h',sum(extract(epoch from upper(r)-lower(r)))/3600
from (
 select user_id,d::date as day,range_agg(tstzrange(greatest(started,d at time zone zone),
    least(ended,(d+interval '1 day') at time zone zone),'[)')) spans
 from public.health_sample cross join lateral generate_series(
    date_trunc('day',started at time zone zone), date_trunc('day',ended at time zone zone),interval '1 day') d
 where metric='sleep' and value in (1,3,4,5) and ended>started group by user_id,d::date
) nights cross join lateral unnest(spans) r group by user_id,day;

create view public.health_periods with (security_invoker=true) as
select user_id,period,date_trunc(period,day::timestamp)::date beginning,metric,unit,
 avg(value) average,count(*) observed_days,(array_agg(value order by day desc))[1]-(array_agg(value order by day))[1] change
from public.health_daily cross join (values ('week'),('month')) p(period)
group by user_id,period,date_trunc(period,day::timestamp)::date,metric,unit;

create view public.health_workout_periods with (security_invoker=true) as
select w.user_id,period,date_trunc(period,w.completed_at at time zone coalesce(c.zone,'UTC'))::date beginning,
 count(distinct w.id) workouts,count(distinct (w.completed_at at time zone coalesce(c.zone,'UTC'))::date) workout_days
from public.completed_workouts w left join public.health_connection c using(user_id)
cross join (values ('week'),('month')) p(period) group by 1,2,3;

create view public.health_exercise_progress with (security_invoker=true) as
select w.user_id,w.id workout_id,w.completed_at,e.name,s.weight,s.reps,
 lag(s.reps) over(partition by w.user_id,e.name,s.weight order by w.completed_at,w.id) previous_best_reps_at_load
from public.completed_workouts w join public.completed_exercises e on e.workout_id=w.id
join lateral (select weight,max(reps) reps from public.completed_set_entries where exercise_id=e.id group by weight) s on true;

revoke all on public.health_daily,public.health_periods,public.health_workout_periods,public.health_exercise_progress from public,anon;
grant select on public.health_daily,public.health_periods,public.health_workout_periods,public.health_exercise_progress to authenticated;
revoke execute on function public.health_apply,public.health_configure,public.health_disconnect from public,anon;
grant execute on function public.health_apply,public.health_configure,public.health_disconnect to authenticated;

create function public.health_finish(owner uuid, grant_id uuid) returns timestamptz
language plpgsql security invoker set search_path = public, pg_temp as $$
declare stamp timestamptz;
begin
  update health_connection set last_success=now()
   where owner=auth.uid() and user_id=owner and revision=grant_id returning last_success into stamp;
  if not found then raise exception 'Consent changed'; end if;
  return stamp;
end $$;
revoke execute on function public.health_finish from public,anon;
grant execute on function public.health_finish to authenticated;

create view public.health_export_samples with (security_invoker=true) as
select user_id,id,metric,identifier,started,ended,source,bundle,zone,value,unit, (started at time zone zone)::date local_day,
 case when metric='sleep' then case value when 0 then 'in bed' when 1 then 'asleep (unspecified)'
 when 2 then 'awake' when 3 then 'core' when 4 then 'deep' when 5 then 'REM' else 'unknown' end end sleep_stage
from public.health_sample s;
create view public.health_sources with (security_invoker=true) as
select user_id,metric,source,bundle,max(started) last_observed from public.health_sample group by user_id,metric,source,bundle;
revoke all on public.health_export_samples,public.health_sources from public,anon;
grant select on public.health_export_samples,public.health_sources to authenticated;

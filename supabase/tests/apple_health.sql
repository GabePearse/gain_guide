-- Run in an isolated migrated Supabase database. All fixtures roll back.
begin;
insert into auth.users(id) values ('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$
declare
 u uuid := auth.uid(); rev uuid; fixture jsonb; n integer; t float8;
begin
 insert into completed_workouts(user_id,name) values(u,'Retained workout');
 rev := health_configure(u,array['recovery','activity'],90,'America/Edmonton',u);
 begin
  perform health_apply(u,rev,'weight',null,'not-granted','[]','{}',null,false);
  raise exception 'Unselected category accepted';
 exception when others then if sqlerrm <> 'Consent changed' then raise; end if; end;
 fixture := jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'identifier','HKCategoryTypeIdentifierSleepAnalysis',
  'started','2026-03-08T07:00:00Z','ended','2026-03-08T15:00:00Z','source','Fixture','bundle','org.example.fixture','value',1,'unit','stage'));
 perform health_apply(u,rev,'sleep',null,'one',fixture,'{}',null,true);
 -- Repeated observer events deliver a UUID only once.
 perform health_apply(u,rev,'sleep','one','two',fixture,'{}',null,true);
 select count(*) into n from health_sample;
 if n<>1 then raise exception 'Duplicate sample'; end if;
 begin
  perform health_apply(u,rev,'sleep','one','stale','[]','{}',null,false);
  raise exception 'Expected stale checkpoint rejection';
 exception when others then if sqlerrm <> 'Checkpoint changed' then raise; end if; end;
 -- A corrected interval and overlapping samples across the DST jump.
 fixture := jsonb_set(fixture,'{0,ended}','"2026-03-08T14:00:00Z"');
 perform health_apply(u,rev,'sleep','two','three',fixture,'{}',null,true);
 perform health_apply(u,rev,'sleep','three','four',jsonb_set(fixture,'{0,id}',to_jsonb(gen_random_uuid())),'{}',null,true);
 select value into strict t from health_daily where day='2026-03-08' and metric='sleep';
 if t<>7 then raise exception 'Incorrect duration or duplicate sources'; end if;
 -- A failed page cannot advance its checkpoint, even when earlier work succeeded.
 begin
  perform health_apply(u,rev,'sleep','four','invalid','[{}]','{}',null,false);
  raise exception 'Invalid sample accepted';
 exception when not_null_violation then null; end;
 if (select anchor from health_checkpoint where metric='sleep')<>'four' then raise exception 'Lost checkpoint'; end if;
 perform health_apply(u,rev,'sleep','four','five','[]',array(select id from health_sample),null,false);
 if exists(select from health_daily) then raise exception 'Deleted samples remained'; end if;
 perform health_apply(u,rev,'steps',null,'s1','[]','{}','[{"day":"2026-11-25","unit":"steps","value":0}]',false);
 if not exists(select from health_daily where metric='steps' and value=0) then raise exception 'Missing observed zero'; end if;
 perform set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
 if exists(select from health_daily) or exists(select from health_connection) or exists(select from health_workout_periods) then raise exception 'Cross-account read'; end if;
 begin
  perform health_disconnect(u,true); raise exception 'Cross-account delete';
 exception when others then if sqlerrm <> 'Account changed' then raise; end if; end;
 perform set_config('request.jwt.claim.sub',u::text,true);
 perform health_disconnect(u,false);
 rev := health_configure(u,array['activity'],90,'America/Edmonton',u);
 if (select anchor from health_checkpoint where metric='steps') is distinct from 's1' then raise exception 'Reconnect lost its cursor'; end if;
 perform health_disconnect(u,true);
 if exists(select from health_stat) or not exists(select from completed_workouts where name='Retained workout') then raise exception 'Deletion isolation failed'; end if;
 begin
  perform health_apply(u,rev,'steps',null,'s2','[]','{}',null,false); raise exception 'Revoked consent accepted';
 exception when others then if sqlerrm <> 'Consent changed' then raise; end if; end;
end $$;
rollback;

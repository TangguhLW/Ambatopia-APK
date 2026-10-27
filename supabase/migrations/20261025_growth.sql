begin;
create table if not exists game_private.growth_rules(
 source_id int primary key,seed_seconds real check(seed_seconds>0),
 single_fruit boolean not null default false,provider_seconds real check(provider_seconds>0),
 rewards jsonb not null default '[]'::jsonb check(jsonb_typeof(rewards)='array')
);
alter table game_private.growth_rules enable row level security;
revoke all on game_private.growth_rules from public,anon,authenticated;

do $$begin
 if to_regprocedure('game_private.command_core_034(jsonb)') is null then
  alter function public.game_command(jsonb) set schema game_private;
  alter function game_private.game_command(jsonb) rename to command_core_034;
 end if;
end $$;
revoke all on function game_private.command_core_034(jsonb) from public,anon,authenticated;

create or replace function game_private.growth_drop(s jsonb,tx int,ty int,item int,amount int)
returns jsonb language plpgsql set search_path='' as $$
declare drops jsonb:=coalesce(s->'drops','[]'::jsonb); n int:=coalesce((s->>'next_drop')::int,0); stack int;
begin
 if item in (0,1,6,7,8,9) or amount<1 or amount>10000 then raise exception 'Invalid source reward'; end if;
 while amount>0 loop
  if jsonb_array_length(drops)>=256 then raise exception 'Collect existing drops before harvesting'; end if;
  n:=n+1;stack:=least(200,amount);amount:=amount-stack;
  drops:=drops||jsonb_build_array(jsonb_build_object('uid',n,'id',item,'amount',stack,'x',tx*32+16,'y',ty*32+12));
 end loop;
 return jsonb_set(jsonb_set(s,'{drops}',drops),'{next_drop}',to_jsonb(n));
end $$;
revoke all on function game_private.growth_drop(jsonb,int,int,int,int) from public,anon,authenticated;

create or replace function public.game_command(p_command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.game_profiles;m game_private.members;w public.game_worlds;
 action text:=p_command->>'type';command text;tx int;ty int;idx int;old_item int;current_item int;
 rule game_private.item_rules;growth game_private.growth_rules;meta jsonb;lock_record jsonb;
 result jsonb;changed boolean:=false;stamp double precision:=extract(epoch from clock_timestamp());
 reward jsonb;item int;amount int;
begin
 if action not in ('place','punch','machine') or action is null then return game_private.command_core_034(p_command); end if;
 p:=game_private.profile();
 select * into m from game_private.members where uid=p.id and seen>now()-interval '35 seconds' for update;
 if not found or m.player_id is distinct from (p_command->>'session')::bigint then raise exception 'Join a world first'; end if;
 select * into w from public.game_worlds where name=m.world for update;
 tx:=(p_command->>'x')::int;ty:=(p_command->>'y')::int;
 if tx is null or ty is null or tx not between 0 and 99 or ty not between 0 and 59 then raise exception 'Out of reach'; end if;
 idx:=ty*100+tx;old_item:=(w.state->'foreground'->>idx)::int;
 if action='machine' then
  if sqrt(power(tx*32+16-m.x,2)+power(ty*32+16-(m.y-16),2))>96 then raise exception 'Out of reach'; end if;
  for lock_record in select value from jsonb_array_elements(w.state->'locks') loop
   if p.role<>'developer' and lock_record->>'owner'<>p.id::text and
    ((lock_record->>'area')::int=0 or (lock_record->'tiles')@>to_jsonb(array[idx])) then raise exception 'World is locked'; end if;
  end loop;
  if m.last_action>now()-interval '200 milliseconds' then return jsonb_build_object('ok',true); end if;
  if coalesce(p_command->'args','{}'::jsonb)<>'{}'::jsonb then raise exception 'Unsupported machine arguments'; end if;
  command:=p_command->>'command';
  if command not in ('grow','harvest') or command is null then raise exception 'This machine command is not available on Supabase yet'; end if;
  select * into rule from game_private.item_rules where id=old_item;
  select * into growth from game_private.growth_rules where source_id=rule.source_id;
  if not found or growth.seed_seconds is null and growth.provider_seconds is null then raise exception 'Only source trees and providers support this command'; end if;
  meta:=coalesce(w.state->'extras'->idx::text,'{}'::jsonb);
  if meta='{}'::jsonb then
   if growth.seed_seconds is not null then meta:=jsonb_build_object('seed',rule.source_id,'planted',stamp,'duration',growth.seed_seconds,'fruit',case when growth.single_fruit then 1 else floor(random()*4)::int+1 end);
   else meta:=jsonb_build_object('ready',stamp+growth.provider_seconds); end if;
  end if;
  if command='grow' then
   if growth.seed_seconds is not null then meta:=jsonb_set(meta,'{planted}',to_jsonb(stamp-growth.seed_seconds));
   else meta:=jsonb_set(meta,'{ready}',to_jsonb(stamp-1)); end if;
  elsif growth.seed_seconds is not null then
   if coalesce((meta->>'planted')::double precision,stamp)+growth.seed_seconds>stamp then raise exception 'Tree is still growing'; end if;
   w.state:=game_private.growth_drop(w.state,tx,ty,rule.source_id-1,floor(random()*4)::int+1);
   w.state:=game_private.growth_drop(w.state,tx,ty,rule.source_id,1);
   w.state:=jsonb_set(w.state,array['foreground',idx::text],'0'::jsonb);meta:='{}'::jsonb;
   perform game_private.emit(m.world,jsonb_build_object('type','tile','x',tx,'y',ty,'layer','foreground','item',0));
  else
   if coalesce((meta->>'ready')::double precision,stamp+growth.provider_seconds)>stamp then raise exception 'Provider is not ready'; end if;
   if jsonb_array_length(growth.rewards)=0 then raise exception 'Source provider reward table is unavailable'; end if;
   reward:=growth.rewards->floor(random()*jsonb_array_length(growth.rewards))::int;
   item:=(reward->>0)::int;amount:=floor(random()*greatest(1,(reward->>1)::int))::int+1;
   w.state:=game_private.growth_drop(w.state,tx,ty,item,amount);
   meta:=jsonb_set(meta,'{ready}',to_jsonb(stamp+growth.provider_seconds));
   if rule.source_id in (7766,7770,7774,7778,8050,9302) then
    w.state:=jsonb_set(w.state,array['foreground',idx::text],'0'::jsonb);meta:='{}'::jsonb;
    perform game_private.emit(m.world,jsonb_build_object('type','tile','x',tx,'y',ty,'layer','foreground','item',0));
   elsif rule.source_id=12680 then
    meta:=jsonb_set(meta,'{harvests}',to_jsonb(coalesce((meta->>'harvests')::int,0)+1));
    if (meta->>'harvests')::int>=8 then
     w.state:=game_private.growth_drop(w.state,tx,ty,12682,1);
     w.state:=jsonb_set(w.state,array['foreground',idx::text],'0'::jsonb);meta:='{}'::jsonb;
     perform game_private.emit(m.world,jsonb_build_object('type','tile','x',tx,'y',ty,'layer','foreground','item',0));
    end if;
   end if;
  end if;
  update game_private.members set last_action=now() where uid=p.id;
  changed:=true;
 else
  select * into rule from game_private.item_rules where id=(p_command->>'item')::int;
  select * into growth from game_private.growth_rules where source_id=rule.source_id;
  if action='place' and growth.seed_seconds is not null and
   (ty=59 or coalesce((w.state->'foreground'->>(idx+100))::int,0)=0) then raise exception 'Plant on a solid block'; end if;
  result:=game_private.command_core_034(p_command);
  select * into w from public.game_worlds where name=m.world;
  current_item:=(w.state->'foreground'->>idx)::int;
  if action='place' and old_item=0 and current_item=(p_command->>'item')::int then
   if growth.seed_seconds is not null then
    meta:=jsonb_build_object('seed',rule.source_id,'planted',stamp,'duration',growth.seed_seconds,'fruit',case when growth.single_fruit then 1 else floor(random()*4)::int+1 end);changed:=true;
   elsif growth.provider_seconds is not null then meta:=jsonb_build_object('ready',stamp+growth.provider_seconds);changed:=true;end if;
  elsif action='punch' and old_item<>0 and current_item=0 and (w.state->'extras')?idx::text then meta:='{}'::jsonb;changed:=true;end if;
 end if;
 if not changed then return result;end if;
 if meta='{}'::jsonb then w.state:=jsonb_set(w.state,'{extras}',(w.state->'extras')-idx::text);
 else w.state:=jsonb_set(w.state,array['extras',idx::text],meta);end if;
 update public.game_worlds set state=w.state,updated_at=now() where name=m.world;
 perform game_private.emit(m.world,jsonb_build_object('type','item_state','x',tx,'y',ty,'data',meta,'drops',coalesce(w.state->'drops','[]'::jsonb)));
 return jsonb_build_object('ok',true,'events',public.game_events(coalesce((p_command->>'cursor')::bigint,0))->'events');
end $$;
revoke all on function public.game_command(jsonb) from public,anon;
grant execute on function public.game_command(jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

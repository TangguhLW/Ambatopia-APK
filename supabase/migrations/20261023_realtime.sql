begin;
create schema if not exists game_private;
revoke all on schema game_private from public,anon,authenticated;
create table game_private.members (
 uid uuid primary key references public.game_profiles(id) on delete cascade,
 player_id bigint generated always as identity unique,
 world text not null references public.game_worlds(name),
 x real not null default 1616, y real not null default 768,
 seen timestamptz not null default now(),
 last_action timestamptz not null default '-infinity',
 last_chat timestamptz not null default '-infinity'
);
create table game_private.item_rules (
 id integer primary key, source_id integer not null, hits integer not null,
 category text not null, lock_area integer, slot text, weather text
);
create table game_private.damage (
 world text not null references public.game_worlds(name) on delete cascade,
 tile integer not null, layer text not null, hits integer not null,
 touched timestamptz not null default now(), primary key(world,tile,layer)
);
alter table game_private.members enable row level security;
alter table game_private.item_rules enable row level security;
alter table game_private.damage enable row level security;

create function game_private.profile() returns public.game_profiles
language plpgsql security definer set search_path='' as $$
declare p public.game_profiles;
begin
 select * into p from public.game_profiles where id=auth.uid();
 if p.id is null or p.banned_until>now() or not exists(select 1 from auth.users u where u.id=p.id and (u.raw_app_meta_data->>'game_provisioned'='true' or u.raw_app_meta_data->>'game_role'='developer')) then raise exception 'Account unavailable'; end if;
 return p;
end $$;

create function game_private.topic(w text) returns text language sql immutable
set search_path='' as $$select 'game:'||w$$;

create function game_private.emit(w text, packet jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin perform realtime.send(packet,'packet',game_private.topic(w),true); end $$;

create function public.game_join(p_world text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.game_profiles; w public.game_worlds; m game_private.members;
 tiles jsonb; backs jsonb;
begin
 p:=game_private.profile(); p_world:=upper(trim(p_world));
 if p_world !~ '^[A-Z0-9]{1,18}$' then raise exception 'Invalid world name'; end if;
 -- Initial terrain comes from the database, never a player-supplied snapshot.
 select jsonb_agg(case when i=2350 then 4 when i=2450 or i/100>=54 then 2
  when i/100>=49 and (abs(hashtextextended(p_world||i,0))%100)<28 then 7
  when i/100>26 and (abs(hashtextextended(p_world||i,0))%100)<9 then 3
  when i/100>=24 then 1 else 0 end order by i),
  jsonb_agg(case when i/100>=24 then 200014 else 0 end order by i)
 into tiles,backs from generate_series(0,5999) i;
 insert into public.game_worlds(name,state) values(p_world,jsonb_build_object(
 'schema_version',1,'name',p_world,'size',jsonb_build_array(100,60),
 'main_door',jsonb_build_array(50,23),'foreground',tiles,'background',backs,
 'extras','{}'::jsonb,'drops','[]'::jsonb,'world_effects','{}'::jsonb,
 'locks','[]'::jsonb,'bans','{}'::jsonb,'weather','sunny','protected_spawn',true))
 on conflict(name) do nothing;
 select * into w from public.game_worlds where name=p_world;
 if coalesce((w.state->'bans'->>p.id::text)::double precision,0)>extract(epoch from now()) and p.role<>'developer' then
  raise exception 'You are banned from this world'; end if;
 insert into game_private.members(uid,world,x,y) values(p.id,p_world,1616,768)
 on conflict(uid) do update set world=excluded.world,x=excluded.x,y=excluded.y,seen=now(),player_id=DEFAULT
 returning * into m;
 return jsonb_build_object('type','welcome','ok',true,'id',m.player_id,'world',w.state,'players','[]'::jsonb);
end $$;

create function public.game_roster(p_world text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.game_profiles; result jsonb;
begin
 p:=game_private.profile();
 if p_world is null or not exists(select 1 from game_private.members where uid=p.id and world=p_world) then raise exception 'Join this world first'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.player_id,'uid',m.uid,'name',
 case when q.role='developer' then '@Thaney' else q.amba_id end,
 'x',m.x,'y',m.y,'vx',0,'vy',0,'facing',1,'grounded',true,'punch',0,
 'equipment',q.outfit,'skin',coalesce((q.settings->>'skin')::int,0))), '[]'::jsonb)
 into result from game_private.members m join public.game_profiles q on q.id=m.uid
 where m.seen>now()-interval '35 seconds' and (p_world is null or m.world=p_world)
 and (q.banned_until is null or q.banned_until<=now());
 return result;
end $$;

create function public.game_world_list() returns jsonb language plpgsql
security definer set search_path='' as $$
begin
 perform game_private.profile();
 return (select coalesce(jsonb_agg(row_to_json(r)),'[]'::jsonb) from (
 select w.name,count(m.uid)::int as count from public.game_worlds w
 left join game_private.members m on m.world=w.name and m.seen>now()-interval '35 seconds'
 group by w.name,w.updated_at order by count(m.uid) desc,w.updated_at desc limit 40) r);
end $$;

create function public.game_heartbeat(p_x real,p_y real,p_player_id bigint) returns jsonb language plpgsql
security definer set search_path='' as $$
declare p public.game_profiles;
begin
 p:=game_private.profile();
 if not (p_x between 0 and 3200 and p_y between 0 and 1920) then raise exception 'Invalid position'; end if;
 update game_private.members set seen=now(),x=p_x,y=p_y where uid=p.id and player_id=p_player_id;
 return jsonb_build_object('ok',found);
end $$;

create function public.game_leave(p_player_id bigint) returns void language plpgsql security definer set search_path='' as $$
begin delete from game_private.members where uid=auth.uid() and player_id=p_player_id; end $$;

create function public.game_command(p_command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.game_profiles; m game_private.members; w public.game_worlds;
 action text; tx int; ty int; idx int; current_item int; next_item int; v_layer text;
 rules game_private.item_rules; total_hits int; packet jsonb; event jsonb;
 lock_record jsonb; locks jsonb; covered jsonb; owner text; text_value text;
begin
 p:=game_private.profile();
 select * into m from game_private.members where uid=p.id and seen>now()-interval '35 seconds' for update;
 if not found or m.player_id is distinct from (p_command->>'session')::bigint then raise exception 'Join a world first'; end if;
 select * into w from public.game_worlds where name=m.world for update;
 action:=p_command->>'type';
 if action='chat' then
  if m.last_chat>now()-interval '700 milliseconds' then raise exception 'Chat cooldown'; end if;
  text_value:=trim(p_command->>'text');
  if text_value is null or length(text_value) not between 1 and 80 or left(text_value,1)='/' then raise exception 'Invalid chat or command unavailable'; end if;
  update game_private.members set last_chat=now() where uid=p.id;
  packet:=jsonb_build_object('type','chat','id',m.player_id,'name',case when p.role='developer' then '@Thaney' else p.amba_id end,'text',text_value);
 elsif action='respawn' then
  update game_private.members set x=1616,y=768 where uid=p.id;
  return jsonb_build_object('type','teleport','x',1616,'y',768);
 elsif action='outfit' then
  if jsonb_typeof(p_command->'equipment')<>'object' or (select count(*) from jsonb_each(p_command->'equipment'))>10 then raise exception 'Invalid outfit'; end if;
  for owner,text_value in select key,value from jsonb_each_text(p_command->'equipment') loop
   if not exists(select 1 from game_private.item_rules where id=text_value::int and slot=owner) then raise exception 'Invalid equipment slot'; end if;
  end loop;
  update public.game_profiles set outfit=p_command->'equipment',settings=jsonb_set(settings,'{skin}',to_jsonb(greatest(0,least(5,coalesce((p_command->>'skin')::int,0))))) where id=p.id;
  return jsonb_build_object('ok',true);
 elsif action in ('punch','place','weather') then
  if m.last_action>now()-interval '200 milliseconds' then return jsonb_build_object('ok',true); end if;
  update game_private.members set last_action=now() where uid=p.id;
  tx:=(p_command->>'x')::int; ty:=(p_command->>'y')::int;
  if action<>'weather' and (tx is null or ty is null or tx not between 0 and 99 or ty not between 0 and 59 or sqrt(power(tx*32+16-m.x,2)+power(ty*32+16-(m.y-16),2))>160) then raise exception 'Out of reach'; end if;
  idx:=ty*100+tx;
  for lock_record in select value from jsonb_array_elements(w.state->'locks') loop
   if p.role<>'developer' and lock_record->>'owner'<>p.id::text and
    ((lock_record->>'area')::int=0 or (lock_record->'tiles')@>to_jsonb(array[idx])) then raise exception 'World is locked'; end if;
  end loop;
  if action='weather' then
   if not exists(select 1 from game_private.item_rules where weather=p_command->>'key') then raise exception 'Unknown weather'; end if;
   if p.role<>'developer' and exists(select 1 from jsonb_array_elements(w.state->'locks') l where l->>'owner'<>p.id::text) then raise exception 'World is locked'; end if;
   w.state:=jsonb_set(w.state,'{weather}',p_command->'key');
   packet:=jsonb_build_object('type','weather','key',p_command->>'key');
  else
   v_layer:='foreground'; current_item:=(w.state->v_layer->>idx)::int;
   next_item:=coalesce((p_command->>'item')::int,0);
   select * into rules from game_private.item_rules where id=next_item;
   if action='place' and rules.category='background' or action='punch' and current_item=0 then v_layer:='background'; current_item:=(w.state->v_layer->>idx)::int; end if;
   if current_item in (2,4,100006,100008,200006,200008) and p.role<>'developer' then
    if current_item in (4,100006,200006) and action='punch' and abs(m.x-(tx*32+16))<=20 and abs(m.y-(ty*32+32))<=32 then return jsonb_build_object('type','world_exit'); end if;
    raise exception 'Main door and bedrock are protected'; end if;
   if action='place' then
    if rules.id is null or rules.category not in ('block','background','lock','seed','other') or current_item<>0 then raise exception 'Cannot place here'; end if;
    if v_layer='foreground' and abs(tx*32+16-m.x)<26 and ty*32+32>m.y-30 and ty*32<m.y then raise exception 'Player occupies this tile'; end if;
    if rules.lock_area is not null then
     if exists(select 1 from jsonb_array_elements(w.state->'locks') l where (l->>'area')::int=0 or rules.lock_area=0 and l->>'owner'<>p.id::text) then raise exception 'World already locked'; end if;
     covered:='[]'::jsonb;
     if rules.lock_area>0 then
      select jsonb_agg(q.i) into covered from (select i from generate_series(0,5999) i
       where not exists(select 1 from jsonb_array_elements(w.state->'locks') l where l->'tiles'@>to_jsonb(array[i]))
       order by abs(i%100-tx)+abs(i/100-ty),i limit rules.lock_area) q;
     end if;
     locks:=(w.state->'locks')||jsonb_build_array(jsonb_build_object('x',tx,'y',ty,'item',next_item,'owner',p.id,'area',rules.lock_area,'tiles',covered));
     w.state:=jsonb_set(w.state,'{locks}',locks);
     if rules.lock_area=0 then w.owner_id:=p.id; end if;
    end if;
   else
    select * into rules from game_private.item_rules where id=current_item;
    if current_item=0 then return jsonb_build_object('ok',true); end if;
    insert into game_private.damage(world,tile,layer,hits) values(m.world,idx,v_layer,1)
    on conflict(world,tile,layer) do update set hits=case when game_private.damage.touched<now()-interval '5 seconds' then 1 else game_private.damage.hits+1 end,touched=now()
    returning hits into total_hits;
    if total_hits<coalesce(rules.hits,3) and p.role<>'developer' then
     packet:=jsonb_build_object('type','effect','id',m.player_id,'event',jsonb_build_object('type','tile_damaged','tile',jsonb_build_array(tx,ty)));
     perform game_private.emit(m.world,packet); return packet;
    end if;
    delete from game_private.damage where world=m.world and tile=idx and game_private.damage.layer=v_layer;
    if current_item in (2,4,100006,100008,200006,200008) then w.state:=jsonb_set(w.state,'{protected_spawn}','false'); end if;
    select coalesce(jsonb_agg(l),'[]'::jsonb) into locks from jsonb_array_elements(w.state->'locks') l where not ((l->>'x')::int=tx and (l->>'y')::int=ty);
    w.state:=jsonb_set(w.state,'{locks}',locks);
    if not exists(select 1 from jsonb_array_elements(locks) l where (l->>'area')::int=0) then w.owner_id:=null; end if;
    next_item:=0;
   end if;
   w.state:=jsonb_set(w.state,array[v_layer,idx::text],to_jsonb(next_item));
   packet:=jsonb_build_object('type','tile','x',tx,'y',ty,'layer',v_layer,'item',next_item);
   perform game_private.emit(m.world,jsonb_build_object('type','effect','id',m.player_id,'event',jsonb_build_object('type',case when action='place' then 'tile_placed' else 'tile_removed' end,'tile',jsonb_build_array(tx,ty),'layer',v_layer)));
  end if;
  update public.game_worlds set state=w.state,owner_id=w.owner_id,updated_at=now() where name=m.world;
 else raise exception 'This command is not yet available on Supabase multiplayer';
 end if;
 perform game_private.emit(m.world,packet);
 return jsonb_build_object('ok',true);
end $$;

-- Each account can send motion only on its own topic. World state comes from SQL.
create function public.game_channel_allowed(topic text,writing boolean) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from game_private.members m join public.game_profiles p on p.id=m.uid
 where m.uid=auth.uid() and m.seen>now()-interval '35 seconds' and (p.banned_until is null or p.banned_until<=now())
 and (topic='game:'||m.world and not writing or topic='motion:'||m.world||':'||m.uid::text
 or not writing and exists(select 1 from game_private.members other where other.world=m.world and topic='motion:'||m.world||':'||other.uid::text and other.seen>now()-interval '35 seconds')))
$$;
create policy godot_channel_read on realtime.messages for select to authenticated using (public.game_channel_allowed(realtime.topic(),false));
create policy godot_motion_write on realtime.messages for insert to authenticated with check (public.game_channel_allowed(realtime.topic(),true));
revoke all on all functions in schema game_private from public,anon,authenticated;
revoke all on function public.game_join(text),public.game_roster(text),public.game_world_list(),public.game_heartbeat(real,real,bigint),public.game_leave(bigint),public.game_command(jsonb),public.game_channel_allowed(text,boolean) from public,anon;
grant execute on function public.game_join(text),public.game_roster(text),public.game_world_list(),public.game_heartbeat(real,real,bigint),public.game_leave(bigint),public.game_command(jsonb),public.game_channel_allowed(text,boolean) to authenticated;
commit;


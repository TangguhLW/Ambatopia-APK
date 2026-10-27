begin;
create table game_private.account_ips (
 uid uuid primary key, ip_hash text not null, confirmed boolean not null default false,
 created_at timestamptz not null default now()
);
create table game_private.secrets (name text primary key,value text not null);
insert into game_private.secrets values('ip-salt',gen_random_uuid()::text||gen_random_uuid()::text);
alter table game_private.account_ips enable row level security;
alter table game_private.secrets enable row level security;

-- Only Supabase Auth can call this hook. The IP is Auth's request metadata,
-- not a value supplied in a client's profile or a custom HTTP header parser.
create function public.game_before_user_created(event jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare name text; email text; v_uid uuid; ip inet; bucket text; salt text; used int;
begin
 name:=event->'user'->'user_metadata'->>'amba_id';
 email:=event->'user'->>'email';
 if name is null or name !~ '^[A-Za-z0-9_]{3,18}$' or email is distinct from lower(name)||'@players.ambatopia.invalid' then
  return jsonb_build_object('error',jsonb_build_object('message','Register using a valid AmbaID.','http_code',403)); end if;
 if lower(name)='thaney' and coalesce(event->'user'->'app_metadata'->>'game_role','')<>'developer' then
  return jsonb_build_object('error',jsonb_build_object('message','This AmbaID is reserved.','http_code',403)); end if;
 -- Admin-provisioned accounts keep working, including isolated synthetic tests.
 if event->'user'->'app_metadata'->>'game_provisioned'='true' or event->'user'->'app_metadata'->>'game_role'='developer' then return '{}'::jsonb; end if;
 if coalesce(event->'metadata'->>'ip_address','') !~ '^[0-9a-fA-F:.]+$' then
  return jsonb_build_object('error',jsonb_build_object('message','Registration origin could not be verified.','http_code',403)); end if;
 ip:=(event->'metadata'->>'ip_address')::inet;
 v_uid:=(event->'user'->>'id')::uuid;
 if v_uid is null then return jsonb_build_object('error',jsonb_build_object('message','Invalid account request.','http_code',403)); end if;
 select value into salt from game_private.secrets where secrets.name='ip-salt';
 bucket:=encode(sha256(convert_to(salt||host(ip),'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended(bucket,0));
 if exists(select 1 from game_private.account_ips a where a.uid=v_uid and a.ip_hash=bucket) then return '{}'::jsonb; end if;
 select count(*) into used from game_private.account_ips where ip_hash=bucket and (confirmed or created_at>now()-interval '15 minutes');
 if used>=2 then return jsonb_build_object('error',jsonb_build_object('message','This IP has reached the limit of two accounts. Existing accounts can still log in.','http_code',429)); end if;
 insert into game_private.account_ips(uid,ip_hash) values(v_uid,bucket);
 return '{}'::jsonb;
end $$;
revoke all on function public.game_before_user_created(jsonb) from public,anon,authenticated;
grant execute on function public.game_before_user_created(jsonb) to supabase_auth_admin;

create or replace function public.create_game_profile() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if lower(new.raw_user_meta_data->>'amba_id')='thaney' and coalesce(new.raw_app_meta_data->>'game_role','player')<>'developer' then raise exception 'Reserved developer identity'; end if;
 insert into public.game_profiles(id,amba_id,role) values(new.id,new.raw_user_meta_data->>'amba_id',case when lower(new.raw_user_meta_data->>'amba_id')='thaney' and new.raw_app_meta_data->>'game_role'='developer' then 'developer' else 'player' end);
 update game_private.account_ips set confirmed=true where uid=new.id;
 return new;
end $$;
create or replace function game_private.profile() returns public.game_profiles
language plpgsql security definer set search_path='' as $$
declare p public.game_profiles;
begin
 select * into p from public.game_profiles where id=auth.uid();
 if p.id is null or p.banned_until>now() or not (
 exists(select 1 from auth.users u where u.id=p.id and (u.raw_app_meta_data->>'game_provisioned'='true' or u.raw_app_meta_data->>'game_role'='developer'))
 or exists(select 1 from game_private.account_ips i where i.uid=p.id and i.confirmed)) then raise exception 'Account unavailable'; end if;
 return p;
end $$;
revoke all on function game_private.profile() from public,anon,authenticated;
create function game_private.release_account_quota() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 delete from game_private.account_ips where uid=old.id;
 return old;
end $$;
revoke all on function game_private.release_account_quota() from public,anon,authenticated;
create trigger game_release_deleted_account_quota after delete on auth.users
for each row execute function game_private.release_account_quota();
commit;

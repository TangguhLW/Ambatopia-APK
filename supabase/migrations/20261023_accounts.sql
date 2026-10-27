-- Dedicated ambatopia-godot project. No migration targets the web game's database.
begin;
create table if not exists public.game_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 amba_id text not null check (amba_id ~ '^[A-Za-z0-9_]{3,18}$'),
 role text not null default 'player' check (role in ('player','developer')),
 created_at timestamptz not null default now(),
 last_seen_at timestamptz,
 played_seconds bigint not null default 0 check (played_seconds >= 0),
 banned_until timestamptz,
 outfit jsonb not null default '{}',
 settings jsonb not null default '{}'
);
create unique index if not exists game_profiles_name on public.game_profiles(lower(amba_id));
create table if not exists public.game_worlds (
 name text primary key check (name ~ '^[A-Z0-9]{1,18}$'),
 owner_id uuid references public.game_profiles(id),
 state jsonb not null,
 updated_at timestamptz not null default now()
);
create table if not exists public.game_audit (
 id bigint generated always as identity primary key,
 actor_id uuid references public.game_profiles(id),
 target_id uuid references public.game_profiles(id),
 action text not null,
 detail jsonb not null default '{}',
 created_at timestamptz not null default now()
);
alter table public.game_profiles enable row level security;
alter table public.game_worlds enable row level security;
alter table public.game_audit enable row level security;
revoke all on public.game_profiles,public.game_worlds,public.game_audit from anon,authenticated;
grant select on public.game_profiles to authenticated;
grant all on public.game_profiles,public.game_worlds,public.game_audit to service_role;
grant usage,select on sequence public.game_audit_id_seq to service_role;
create policy profile_self_read on public.game_profiles for select to authenticated using (id = (select auth.uid()));
create or replace function public.create_game_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 if lower(new.raw_user_meta_data->>'amba_id') = 'thaney'
 and coalesce(new.raw_app_meta_data->>'game_role','player') <> 'developer' then
   raise exception 'Reserved developer identity';
 end if;
 insert into public.game_profiles(id,amba_id,role)
 values (new.id, new.raw_user_meta_data->>'amba_id',
 case when new.raw_app_meta_data->>'game_role' = 'developer'
   and lower(new.raw_user_meta_data->>'amba_id') = 'thaney' then 'developer' else 'player' end);
 return new;
end;
$$;
revoke all on function public.create_game_profile() from public,anon,authenticated;
create trigger on_game_auth_created after insert on auth.users for each row execute function public.create_game_profile();
commit;

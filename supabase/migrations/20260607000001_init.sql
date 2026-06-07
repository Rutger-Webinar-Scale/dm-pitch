-- DM Pitch System — Phase 2 schema
-- profiles: one row per user, role owner/setter
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  name text not null default '',
  role text not null default 'setter' check (role in ('owner','setter')),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- security definer so policies can check ownership without RLS recursion
create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'owner'); $$;

create policy "profiles: own or owner sees all" on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_owner());

-- auto-create profile on signup; Rutger = owner, everyone else = setter
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, role)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
          case when lower(new.email) = 'rutger.kreulen@gmail.com' then 'owner' else 'setter' end);
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- leads: whole lead object as jsonb, tagged to a setter
create table public.leads (
  id text primary key,
  setter_id uuid not null references public.profiles(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
create index leads_setter_idx on public.leads(setter_id);
alter table public.leads enable row level security;

create policy "leads select own or owner" on public.leads
  for select to authenticated using (setter_id = auth.uid() or public.is_owner());
create policy "leads insert own or owner" on public.leads
  for insert to authenticated with check (setter_id = auth.uid() or public.is_owner());
create policy "leads update own or owner" on public.leads
  for update to authenticated
  using (setter_id = auth.uid() or public.is_owner())
  with check (setter_id = auth.uid() or public.is_owner());
create policy "leads delete own or owner" on public.leads
  for delete to authenticated using (setter_id = auth.uid() or public.is_owner());

-- shared team state: scripts, A/B variants, daily goal (whole team reads+writes, only owner deletes)
create table public.shared_state (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.shared_state enable row level security;
create policy "shared read" on public.shared_state
  for select to authenticated using (true);
create policy "shared insert" on public.shared_state
  for insert to authenticated with check (true);
create policy "shared update" on public.shared_state
  for update to authenticated using (true) with check (true);
create policy "shared delete owner only" on public.shared_state
  for delete to authenticated using (public.is_owner());

-- per-user prefs: language, own IG accounts, active account
create table public.user_state (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.user_state enable row level security;
create policy "user_state own" on public.user_state
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

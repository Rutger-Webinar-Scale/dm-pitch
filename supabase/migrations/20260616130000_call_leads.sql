-- Cold Calling System — volledig aparte software, eigen lead-tabel.
-- DMPS (public.leads) deelt hierna NIETS meer met cold-call.

-- toegangshelper: owner óf setter met can_cold_call
create or replace function public.can_cold_call() returns boolean
language sql stable security definer set search_path = public as
$$ select exists (
     select 1 from public.profiles
     where id = auth.uid() and (role = 'owner' or can_cold_call)
   ); $$;

-- aparte tabel voor bel-leads (zelfde vorm als public.leads)
create table if not exists public.call_leads (
  id text primary key,
  setter_id uuid not null references public.profiles(id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
create index if not exists call_leads_setter_idx on public.call_leads(setter_id);
alter table public.call_leads enable row level security;

drop policy if exists "call_leads select" on public.call_leads;
create policy "call_leads select" on public.call_leads
  for select to authenticated
  using ((setter_id = auth.uid() and public.can_cold_call()) or public.is_owner());

drop policy if exists "call_leads insert" on public.call_leads;
create policy "call_leads insert" on public.call_leads
  for insert to authenticated
  with check ((setter_id = auth.uid() and public.can_cold_call()) or public.is_owner());

drop policy if exists "call_leads update" on public.call_leads;
create policy "call_leads update" on public.call_leads
  for update to authenticated
  using ((setter_id = auth.uid() and public.can_cold_call()) or public.is_owner())
  with check ((setter_id = auth.uid() and public.can_cold_call()) or public.is_owner());

drop policy if exists "call_leads delete" on public.call_leads;
create policy "call_leads delete" on public.call_leads
  for delete to authenticated
  using ((setter_id = auth.uid() and public.can_cold_call()) or public.is_owner());

-- gedeelde state voor het cold-call-systeem (scripts, dagdoel) — los van DMPS shared_state
-- hergebruikt bestaande public.shared_state met eigen keys (prefix 'call_'), geen schemawijziging nodig.

-- verhuis bestaande channel:'call'-leads uit public.leads naar de nieuwe tabel
insert into public.call_leads (id, setter_id, data, updated_at)
  select id, setter_id, data, updated_at
  from public.leads
  where data->>'channel' = 'call'
on conflict (id) do nothing;

delete from public.leads where data->>'channel' = 'call';

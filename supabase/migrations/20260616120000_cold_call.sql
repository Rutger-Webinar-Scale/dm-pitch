-- Cold Call module
-- 1) per-setter toegangsvlag voor cold-call (default uit → bestaande setters merken niets)
alter table public.profiles add column if not exists can_cold_call boolean not null default false;

-- 2) owner mag profielen updaten (o.a. can_cold_call togglen); setters kunnen niet escaleren
drop policy if exists "profiles update owner" on public.profiles;
create policy "profiles update owner" on public.profiles
  for update to authenticated using (public.is_owner()) with check (public.is_owner());

-- 3) owner (Rutger) mag altijd cold-callen
update public.profiles set can_cold_call = true where lower(email) = 'rutger.kreulen@gmail.com';

-- NB: cold-call leads delen de bestaande public.leads-tabel; ze worden onderscheiden
-- door data->>'channel' = 'call' (geen schemawijziging nodig, RLS per setter blijft gelden).

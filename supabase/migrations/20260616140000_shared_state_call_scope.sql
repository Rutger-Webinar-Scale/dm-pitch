-- Scheid cold-call shared_state (keys met prefix 'call_') af van de rest.
-- Zonder dit kan elke ingelogde user (ook setters zonder can_cold_call, zoals Eliza)
-- de bel-scripts/doel lezen én overschrijven via een directe PostgREST-call.
-- DMPS-keys (scripts, abVariants, goal, toolLinks, resources) blijven team-breed leesbaar.

drop policy if exists "shared read" on public.shared_state;
create policy "shared read" on public.shared_state
  for select to authenticated
  using (key not like 'call\_%' or public.can_cold_call());

drop policy if exists "shared insert" on public.shared_state;
create policy "shared insert" on public.shared_state
  for insert to authenticated
  with check (key not like 'call\_%' or public.can_cold_call());

drop policy if exists "shared update" on public.shared_state;
create policy "shared update" on public.shared_state
  for update to authenticated
  using (key not like 'call\_%' or public.can_cold_call())
  with check (key not like 'call\_%' or public.can_cold_call());

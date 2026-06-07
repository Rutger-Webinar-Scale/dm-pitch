-- Setter Hub media: team mag uploaden/vervangen in de assets-bucket (public read via bucket)
create policy "assets insert" on storage.objects
  for insert to authenticated with check (bucket_id = 'assets');
create policy "assets update" on storage.objects
  for update to authenticated using (bucket_id = 'assets') with check (bucket_id = 'assets');
create policy "assets delete" on storage.objects
  for delete to authenticated using (bucket_id = 'assets');
create policy "assets select" on storage.objects
  for select to authenticated using (bucket_id = 'assets');

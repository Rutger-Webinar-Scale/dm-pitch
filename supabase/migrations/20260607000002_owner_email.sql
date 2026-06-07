-- owner signup ook via rutger@webinar-scale.com (beide e-mails = Rutger)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, role)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
          case when lower(new.email) in ('rutger.kreulen@gmail.com','rutger@webinar-scale.com')
               then 'owner' else 'setter' end);
  return new;
end; $$;

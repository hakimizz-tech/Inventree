-- Only the admin (app_metadata.role = 'admin') can read or write.
-- app_metadata can only be set with the service-role key, so users can't self-promote.
create policy "admin full access"
on public.inventory_items
for all
to authenticated
using      ( (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' )
with check ( (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin' );
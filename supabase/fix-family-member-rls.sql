drop policy if exists "users can read own memberships" on public.family_members;
create policy "users can read own memberships"
on public.family_members for select
using (user_id = auth.uid());

drop policy if exists "users can update own memberships" on public.family_members;
create policy "users can update own memberships"
on public.family_members for update
using (user_id = auth.uid())
with check (user_id = auth.uid());


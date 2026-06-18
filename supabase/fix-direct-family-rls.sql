drop policy if exists "members can read their family direct" on public.families;
create policy "members can read their family direct"
on public.families for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = families.id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read children direct" on public.children;
create policy "members can read children direct"
on public.children for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = children.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read guardians direct" on public.guardians;
create policy "members can read guardians direct"
on public.guardians for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = guardians.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read star records direct" on public.star_records;
create policy "members can read star records direct"
on public.star_records for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = star_records.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read rewards direct" on public.rewards;
create policy "members can read rewards direct"
on public.rewards for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = rewards.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can manage rewards direct" on public.rewards;
create policy "members can manage rewards direct"
on public.rewards for all
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = rewards.family_id
      and fm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = rewards.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read reward redemptions direct" on public.reward_redemptions;
create policy "members can read reward redemptions direct"
on public.reward_redemptions for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = reward_redemptions.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read badges direct" on public.badges;
create policy "members can read badges direct"
on public.badges for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = badges.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can manage badges direct" on public.badges;
create policy "members can manage badges direct"
on public.badges for all
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = badges.family_id
      and fm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = badges.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read child badges direct" on public.child_badges;
create policy "members can read child badges direct"
on public.child_badges for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = child_badges.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read title rules direct" on public.title_rules;
create policy "members can read title rules direct"
on public.title_rules for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = title_rules.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can manage title rules direct" on public.title_rules;
create policy "members can manage title rules direct"
on public.title_rules for all
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = title_rules.family_id
      and fm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = title_rules.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can read settings direct" on public.settings;
create policy "members can read settings direct"
on public.settings for select
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = settings.family_id
      and fm.user_id = auth.uid()
  )
);

drop policy if exists "members can manage settings direct" on public.settings;
create policy "members can manage settings direct"
on public.settings for all
using (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = settings.family_id
      and fm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.family_members fm
    where fm.family_id = settings.family_id
      and fm.user_id = auth.uid()
  )
);

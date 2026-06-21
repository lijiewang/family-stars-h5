with earned_lifetime_badges as (
  select c.family_id, c.id as child_id, b.id as badge_id
  from public.children c
  join public.badges b on b.family_id = c.family_id
  where b.is_active = true
    and b.rule_type = 'lifetime_stars'
    and greatest(c.lifetime_stars, c.available_stars) >= b.rule_value
),
earned_category_star_badges as (
  select sr.family_id, sr.child_id, b.id as badge_id
  from public.star_records sr
  join public.badges b on b.family_id = sr.family_id
    and b.is_active = true
    and b.rule_type = 'category_positive_stars'
    and b.category = sr.category
  where sr.type = 'praise'
  group by sr.family_id, sr.child_id, b.id, b.rule_value
  having sum(sr.stars) >= b.rule_value
),
earned_category_count_badges as (
  select sr.family_id, sr.child_id, b.id as badge_id
  from public.star_records sr
  join public.badges b on b.family_id = sr.family_id
    and b.is_active = true
    and b.rule_type = 'category_positive_count'
    and b.category = sr.category
  where sr.type = 'praise'
  group by sr.family_id, sr.child_id, b.id, b.rule_value
  having count(*) >= b.rule_value
),
earned_badges as (
  select * from earned_lifetime_badges
  union
  select * from earned_category_star_badges
  union
  select * from earned_category_count_badges
)
insert into public.child_badges (family_id, child_id, badge_id)
select family_id, child_id, badge_id
from earned_badges
on conflict (child_id, badge_id) do nothing;

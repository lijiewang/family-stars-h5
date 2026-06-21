with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.badges (
  family_id,
  name,
  description,
  icon_key,
  rule_type,
  rule_value,
  category,
  sort_order
)
select id, '星球小子勋章', '累计获得 1 颗成长星。', 'badge-planet-kid', 'lifetime_stars', 1, null, 1 from family
on conflict (family_id, name) do update set
  description = excluded.description,
  icon_key = excluded.icon_key,
  rule_type = excluded.rule_type,
  rule_value = excluded.rule_value,
  category = excluded.category,
  sort_order = excluded.sort_order,
  is_active = true;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
),
badge_orders(name, sort_order) as (
  values
    ('星球小子勋章', 1),
    ('星球小队员勋章', 2),
    ('闪亮探险家勋章', 3),
    ('自律小勇士勋章', 4),
    ('星球队长勋章', 5),
    ('整理达人勋章', 6),
    ('友爱兄弟勋章', 7),
    ('睡前小达人勋章', 8),
    ('情绪管理勋章', 9),
    ('运动健将勋章', 10)
)
update public.badges b
set sort_order = badge_orders.sort_order
from family, badge_orders
where b.family_id = family.id
  and b.name = badge_orders.name;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
),
planet_kid_badge as (
  select b.id, b.family_id
  from public.badges b
  join family f on f.id = b.family_id
  where b.name = '星球小子勋章'
)
insert into public.child_badges (family_id, child_id, badge_id)
select c.family_id, c.id, planet_kid_badge.id
from public.children c
join planet_kid_badge on planet_kid_badge.family_id = c.family_id
where c.lifetime_stars >= 1
on conflict (child_id, badge_id) do nothing;

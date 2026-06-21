with family as (
  insert into public.families (name, invite_code, admin_pin)
  values ('一涵一杉星球探险队', 'PIPI-MANMAN', '2468')
  on conflict (invite_code) do update set name = excluded.name
  returning id
)
insert into public.children (
  family_id,
  name,
  nickname,
  age,
  avatar_key,
  theme_planet,
  sort_order
)
select id, '一涵', '一涵', 9, 'rocket-captain', 'blue-tech-planet', 1 from family
union all
select id, '一杉', '一杉', 3, 'little-astronaut', 'yellow-candy-planet', 2 from family
on conflict (family_id, name) do update set
  nickname = excluded.nickname,
  age = excluded.age,
  avatar_key = excluded.avatar_key,
  theme_planet = excluded.theme_planet,
  sort_order = excluded.sort_order;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.guardians (family_id, name, role_key, sort_order)
select id, '爸爸', 'dad', 1 from family
union all
select id, '妈妈', 'mom', 2 from family
union all
select id, '奶奶', 'grandma', 3 from family
on conflict (family_id, role_key) do update set name = excluded.name;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.rewards (family_id, name, description, cost_stars, sort_order)
select id, '选择一个睡前故事', '今晚可以自己选择一本睡前故事。', 10, 1 from family
union all
select id, '亲子游戏 15 分钟', '晚饭后安排 15 分钟亲子游戏时间。', 20, 2 from family
union all
select id, '选择一次家庭电影', '周末可以选择一部适合全家看的电影。', 30, 3 from family
union all
select id, '一次小礼物', '兑换一个提前约定好的小礼物。', 50, 4 from family
union all
select id, '户外活动选择权', '选择一次公园、运动或户外活动。', 80, 5 from family
union all
select id, '大愿望兑换', '兑换一次提前约定的大愿望。', 120, 6 from family
on conflict (family_id, name) do update set
  description = excluded.description,
  cost_stars = excluded.cost_stars,
  sort_order = excluded.sort_order;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.title_rules (family_id, title, required_lifetime_stars, sort_order)
select id, '星球小队员', 10, 1 from family
union all
select id, '闪亮探险家', 30, 2 from family
union all
select id, '自律小勇士', 60, 3 from family
union all
select id, '星球队长', 100, 4 from family
union all
select id, '超级成长官', 150, 5 from family
union all
select id, '家庭英雄', 220, 6 from family
on conflict (family_id, title) do update set
  required_lifetime_stars = excluded.required_lifetime_stars,
  sort_order = excluded.sort_order;

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
union all
select id, '星球小队员勋章', '累计获得 10 颗成长星。', 'badge-star-rookie', 'lifetime_stars', 10, null, 2 from family
union all
select id, '闪亮探险家勋章', '累计获得 30 颗成长星。', 'badge-explorer', 'lifetime_stars', 30, null, 3 from family
union all
select id, '自律小勇士勋章', '累计获得 60 颗成长星。', 'badge-discipline', 'lifetime_stars', 60, null, 4 from family
union all
select id, '星球队长勋章', '累计获得 100 颗成长星。', 'badge-captain', 'lifetime_stars', 100, null, 5 from family
union all
select id, '整理达人勋章', '整理类累计获得 20 颗星。', 'badge-tidy', 'category_positive_stars', 20, '整理', 6 from family
union all
select id, '友爱兄弟勋章', '兄弟互动累计获得 20 颗星。', 'badge-brothers', 'category_positive_stars', 20, '兄弟互动', 7 from family
union all
select id, '睡前小达人勋章', '睡觉类获得 5 次正向记录。', 'badge-bedtime', 'category_positive_count', 5, '睡觉', 8 from family
union all
select id, '情绪管理勋章', '情绪类获得 10 次正向记录。', 'badge-emotion', 'category_positive_count', 10, '情绪', 9 from family
union all
select id, '运动健将勋章', '运动类累计获得 20 颗星。', 'badge-sports', 'category_positive_stars', 20, '运动', 10 from family
on conflict (family_id, name) do update set
  description = excluded.description,
  icon_key = excluded.icon_key,
  rule_type = excluded.rule_type,
  rule_value = excluded.rule_value,
  category = excluded.category,
  sort_order = excluded.sort_order;

with family as (
  select id from public.families where invite_code = 'PIPI-MANMAN'
)
insert into public.settings (family_id, key, value)
select id, 'max_praise_stars', '5'::jsonb from family
union all
select id, 'max_improvement_stars', '3'::jsonb from family
union all
select id, 'daily_deduct_limit', '5'::jsonb from family
union all
select id, 'allow_negative_stars', 'false'::jsonb from family
on conflict (family_id, key) do update set value = excluded.value;

select
  f.id as family_id,
  f.name,
  f.invite_code,
  (select count(*) from public.children c where c.family_id = f.id) as children_count,
  (select count(*) from public.guardians g where g.family_id = f.id) as guardians_count,
  (select count(*) from public.rewards r where r.family_id = f.id) as rewards_count,
  (select count(*) from public.badges b where b.family_id = f.id) as badges_count
from public.families f
where f.invite_code = 'PIPI-MANMAN';

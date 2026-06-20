create or replace function public.update_star_record_category(
  p_family_id uuid,
  p_record_id uuid,
  p_category text
)
returns public.star_records
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_record public.star_records%rowtype;
begin
  if not public.is_family_member(p_family_id) then
    raise exception '没有访问这个家庭空间的权限';
  end if;

  if length(trim(coalesce(p_category, ''))) = 0 then
    raise exception '必须选择行为类别';
  end if;

  update public.star_records
  set category = trim(p_category)
  where id = p_record_id
    and family_id = p_family_id
  returning * into updated_record;

  if updated_record.id is null then
    raise exception '记录不存在';
  end if;

  if updated_record.type = 'praise' then
    insert into public.child_badges (family_id, child_id, badge_id)
    select p_family_id, updated_record.child_id, b.id
    from public.badges b
    where b.family_id = p_family_id
      and b.is_active = true
      and (
        (
          b.rule_type = 'category_positive_stars'
          and b.rule_value <= (
            select coalesce(sum(stars), 0)
            from public.star_records
            where family_id = p_family_id
              and child_id = updated_record.child_id
              and type = 'praise'
              and category = b.category
          )
        )
        or (
          b.rule_type = 'category_positive_count'
          and b.rule_value <= (
            select count(*)::int
            from public.star_records
            where family_id = p_family_id
              and child_id = updated_record.child_id
              and type = 'praise'
              and category = b.category
          )
        )
      )
    on conflict (child_id, badge_id) do nothing;
  end if;

  return updated_record;
end;
$$;

grant execute on function public.update_star_record_category(uuid, uuid, text) to authenticated;

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
select id, '运动健将勋章', '运动类累计获得 20 颗星。', 'badge-sports', 'category_positive_stars', 20, '运动', 9 from family
on conflict (family_id, name) do update set
  description = excluded.description,
  icon_key = excluded.icon_key,
  rule_type = excluded.rule_type,
  rule_value = excluded.rule_value,
  category = excluded.category,
  sort_order = excluded.sort_order;

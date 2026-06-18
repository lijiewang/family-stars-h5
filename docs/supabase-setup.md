# 皮皮小满星球探险队 Supabase 配置说明

这份说明用于第一版微信 H5 应用。目标是：爸爸、妈妈、奶奶不用注册账号，在微信里打开 H5 后通过家庭邀请码加入同一个家庭空间，数据统一保存在 Supabase。

## 1. 推荐数据方案

第一版使用 Supabase：

- PostgreSQL 保存家庭、孩子、星星记录、奖励、勋章和设置
- Supabase Auth 的匿名登录保存每台设备的身份
- Row Level Security 根据家庭成员关系隔离数据
- 邀请码：`PIPI-MANMAN`
- 家庭名称：`皮皮小满星球探险队`

这种方式比“纯本地保存”更适合三位家长共享数据。爸爸、妈妈、奶奶在各自微信里打开同一个 H5 链接，加入同一个家庭空间后，看到的是同一份云端记录。

## 2. 你需要先做什么

### 第一步：创建 Supabase 项目

1. 打开 Supabase 控制台。
2. 新建一个 Project。
3. Project name 可以填：`family-star-adventure`。
4. Database password 请自己保存好。
5. Region 选择离你使用地较近、访问稳定的区域。

### 第二步：启用匿名登录

进入 Supabase 项目后：

1. 打开 `Authentication`。
2. 找到 `Providers`。
3. 启用 `Anonymous sign-ins`。

前端会在首次打开时调用匿名登录，家长不用输入手机号或邮箱。

### 第三步：运行建表 SQL

1. 打开 Supabase 左侧的 `SQL Editor`。
2. 新建 Query。
3. 复制 [schema.sql](../supabase/schema.sql) 的全部内容。
4. 点击 Run。

执行完成后会自动创建：

- 家庭：`皮皮小满星球探险队`
- 邀请码：`PIPI-MANMAN`
- 孩子：皮皮、小满
- 操作人：爸爸、妈妈、奶奶
- 默认奖励
- 默认称号
- 默认勋章
- 默认星星规则

默认管理 PIN 暂定为：`2468`。第一版可以用于设置页入口，后续开发时也可以改成你指定的数字。

## 3. 前端环境变量

开发时需要在项目根目录创建 `.env.local`。

```bash
NEXT_PUBLIC_SUPABASE_URL=你的 Supabase Project URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=你的 Supabase anon public key
NEXT_PUBLIC_DEFAULT_INVITE_CODE=PIPI-MANMAN
```

这两个 Supabase 值在这里找：

1. 进入 Supabase 项目。
2. 打开 `Project Settings`。
3. 打开 `API`。
4. 复制 `Project URL` 到 `NEXT_PUBLIC_SUPABASE_URL`。
5. 复制 `anon public` key 到 `NEXT_PUBLIC_SUPABASE_ANON_KEY`。

注意：

- `.env.local` 不要提交到 Git。
- `anon public key` 可以放在前端，但 `service_role key` 绝对不要放到前端。
- 第一版只需要 `anon public key`。

## 4. 前端第一次进入的流程

H5 打开后：

1. 调用 Supabase 匿名登录。
2. 输入或默认带出邀请码：`PIPI-MANMAN`。
3. 选择操作人：
   - 爸爸，对应 `dad`
   - 妈妈，对应 `mom`
   - 奶奶，对应 `grandma`
4. 调用数据库函数：

```ts
await supabase.rpc('join_family', {
  p_invite_code: 'PIPI-MANMAN',
  p_guardian_role_key: 'dad'
})
```

返回值会包含：

- `family_id`
- `family_name`
- `guardian_id`
- `guardian_name`
- `guardian_role_key`

前端把这些信息保存到微信浏览器的 `localStorage`，以后再打开就直接进入首页。

## 5. 加星和减星调用方式

加星和减星统一调用 `add_star_record`。

表扬示例：

```ts
await supabase.rpc('add_star_record', {
  p_family_id: familyId,
  p_child_id: childId,
  p_guardian_id: guardianId,
  p_type: 'praise',
  p_stars: 3,
  p_category: '兄弟互动',
  p_reason: '主动帮小满收拾玩具'
})
```

需要改进示例：

```ts
await supabase.rpc('add_star_record', {
  p_family_id: familyId,
  p_child_id: childId,
  p_guardian_id: guardianId,
  p_type: 'improvement',
  p_stars: 1,
  p_category: '睡觉',
  p_reason: '睡前反复跑出房间，需要继续练习睡前流程'
})
```

数据库会自动处理：

- 原因必填
- 表扬增加当前星星和累计星星
- 需要改进减少当前星星
- 当前星星不会低于 0
- 每日减星上限
- 称号自动升级

## 6. 奖励兑换调用方式

```ts
await supabase.rpc('redeem_reward', {
  p_family_id: familyId,
  p_child_id: childId,
  p_guardian_id: guardianId,
  p_reward_id: rewardId,
  p_note: '周末兑换'
})
```

数据库会自动处理：

- 判断星星是否足够
- 扣除当前可用星星
- 增加已消耗星星
- 保存奖励名称和星星价格快照

## 7. 常用查询

查询孩子：

```ts
const { data } = await supabase
  .from('children')
  .select('*')
  .eq('family_id', familyId)
  .order('sort_order')
```

查询行为记录：

```ts
const { data } = await supabase
  .from('star_records')
  .select('*, children(name), guardians(name)')
  .eq('family_id', familyId)
  .order('created_at', { ascending: false })
```

查询奖励：

```ts
const { data } = await supabase
  .from('rewards')
  .select('*')
  .eq('family_id', familyId)
  .eq('is_active', true)
  .order('sort_order')
```

查询兑换记录：

```ts
const { data } = await supabase
  .from('reward_redemptions')
  .select('*, children(name), guardians(name)')
  .eq('family_id', familyId)
  .order('created_at', { ascending: false })
```

## 8. 角色图标建议

第一版先不依赖真实头像，使用星球角色图标。

皮皮，9 岁：

- `avatar_key`: `rocket-captain`
- 角色设定：火箭小队长
- 视觉关键词：蓝色、火箭、队长徽章、任务感
- 适合强调自律、责任、学习、照顾弟弟

小满，3 岁：

- `avatar_key`: `little-astronaut`
- 角色设定：小小宇航员
- 视觉关键词：黄色、小星球、圆润、可爱、星星背包
- 适合强调自理、表达、睡觉、分享

## 9. 后续扩展角色

后续如果要增加爷爷、外公、外婆或其他照看人，只需要在 `guardians` 表增加一条记录：

```sql
insert into public.guardians (family_id, name, role_key, sort_order)
select id, '爷爷', 'grandpa', 4
from public.families
where invite_code = 'PIPI-MANMAN';
```

前端操作人选择列表从 `guardians` 表读取即可，不需要写死。

## 10. 你需要发给我的信息

你完成 Supabase 项目创建和 SQL 执行后，把下面两项发给我即可：

```bash
NEXT_PUBLIC_SUPABASE_URL=...
NEXT_PUBLIC_SUPABASE_ANON_KEY=...
```

不要发 `service_role key`。

如果你希望我直接帮你接入项目开发，也可以只把这两个环境变量填到本地 `.env.local`，然后告诉我“环境变量已填好”。我会继续开始 H5 应用开发。

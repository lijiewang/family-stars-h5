# 自动部署和 SQL 执行说明

## 1. Netlify 自动部署

项目已经增加 `netlify.toml`。Netlify 连接 GitHub 仓库后，每次 `main` 分支有新提交，Netlify 会自动执行：

```bash
mkdir -p dist && cp index.html app.js styles.css config.js _headers dist/
```

发布目录是：

```bash
dist
```

### Netlify 设置步骤

1. 打开 `https://app.netlify.com/`。
2. 选择 `Add new site`。
3. 选择 `Import an existing project`。
4. 选择 GitHub，并授权 Netlify 访问仓库。
5. 选择仓库：`lijiewang/family-stars-h5`。
6. Build command 会自动读取 `netlify.toml`。
7. Publish directory 会自动读取为 `dist`。
8. 点击 Deploy。

以后只要代码推送到 GitHub，Netlify 会自动部署。

## 2. Supabase SQL 手动触发执行

项目已经增加 GitHub Action：

```text
.github/workflows/run-supabase-sql.yml
```

这个 Action 不会自动执行，必须你在 GitHub 页面手动点击运行，并选择要执行的 SQL 文件。

### 添加 GitHub Secret

1. 打开 GitHub 仓库。
2. 进入 `Settings`。
3. 打开 `Secrets and variables`。
4. 打开 `Actions`。
5. 点击 `New repository secret`。
6. Name 填：

```text
SUPABASE_DB_URL
```

7. Secret 填 Supabase 数据库连接字符串。

推荐使用 Supabase 的 Pooler 连接串，格式类似：

```text
postgresql://postgres.<project-ref>:<database-password>@aws-0-<region>.pooler.supabase.com:6543/postgres
```

如果连接串里没有 SSL 参数，可以在末尾加上：

```text
?sslmode=require
```

连接串可以在 Supabase 项目里找：

1. 打开 Supabase Project。
2. 打开 `Project Settings`。
3. 打开 `Database`。
4. 找到 `Connection string`。
5. 优先选择 `Session pooler`。
6. 把 `[YOUR-PASSWORD]` 替换成项目数据库密码。

不要把这个连接串写进代码，也不要提交到 Git。

### 执行 SQL

1. 打开 GitHub 仓库。
2. 进入 `Actions`。
3. 选择 `Run Supabase SQL`。
4. 点击 `Run workflow`。
5. 选择要执行的 SQL 文件。
6. 再点击绿色 `Run workflow`。

当前可选 SQL：

```text
supabase/backfill-earned-badges.sql
supabase/add-redemption-invalidation.sql
supabase/add-planet-kid-badge.sql
supabase/transfer-stars-and-rename-family.sql
supabase/add-sports-and-record-category-edit.sql
supabase/fix-direct-family-rls.sql
supabase/fix-family-member-rls.sql
```

## 3. 推荐使用方式

- 前端改动：我提交并推送到 GitHub 后，Netlify 自动发布。
- 数据库改动：我新增 SQL 后，你在 GitHub Actions 手动选择并运行对应 SQL。

这样能减少重复手工操作，同时避免数据库在每次提交时被意外修改。

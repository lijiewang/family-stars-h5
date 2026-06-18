# 微信 H5 部署说明

这个应用是纯静态 H5，发布时只需要上传以下文件：

- `index.html`
- `styles.css`
- `config.js`
- `app.js`
- `_headers`

## 推荐方式：Netlify Drop

这是最快的手动部署方式。

1. 打开 https://app.netlify.com/drop
2. 登录或注册 Netlify。
3. 把 `dist` 文件夹拖到页面中。
4. 等待上传完成。
5. Netlify 会生成一个 HTTPS 地址，例如 `https://xxx.netlify.app`。
6. 用微信打开这个地址测试。

## 备用方式：Cloudflare Pages

1. 打开 https://dash.cloudflare.com/
2. 进入 `Workers & Pages`。
3. 创建 Pages 项目。
4. 选择 `Direct Upload`。
5. 上传 `dist` 文件夹。
6. 发布后得到 `https://xxx.pages.dev` 地址。

## 微信中使用

发布后，把 HTTPS 地址发到家庭微信群。爸爸、妈妈、奶奶首次打开时：

1. 输入或保留默认邀请码 `PIPI-MANMAN`。
2. 选择操作人。
3. 点击进入星球队。

后续微信浏览器会保存本机身份，通常不需要重复选择。

## 注意

- 不要上传 `.env.local`。
- 不要上传 `supabase/` SQL 文件夹。
- 不要把 Supabase `service_role key` 放进前端。
- 当前 `config.js` 里的 `anon public key` 是允许放前端的公开 key，真实权限由 RLS 控制。

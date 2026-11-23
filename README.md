# OCI Helper Serverless（一键部署版）

一键把 **OCI 抢机 / 实例管理面板**部署到你自己的 Cloudflare 账号。

[![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/Yohann0617/oci-helper-serverless-cf)

## 特点

- 数据库表结构由 Worker 在**首次请求时自动创建**，无需执行任何 SQL 命令。
- 提供两种部署方式，按需选择：
  - **方式一 · 一键按钮（推荐）**：自动 Fork + 创建 D1 + 部署，全程不用手动建库。
  - **方式二 · 连接 GitHub 导入（不 Fork）**：不创建副本仓库，但需要先手动建 D1 再绑定（多 3 步）。

## 方式一：一键按钮部署（自动创建 D1）（推荐🏆）

1. 点击页面顶部的 **Deploy to Cloudflare** 按钮。
2. 授权 GitHub / Cloudflare，Cloudflare 会把本仓库**复制一份到你自己的 GitHub 账号**，并自动创建 D1 数据库、绑定资源、完成部署（按向导提示填写 Worker 名称即可，默认 `oci-helper-serverless`）。
3. 部署完成后打开 Worker 域名（如 `https://oci-helper-serverless.<你的子域>.workers.dev`），用默认密码 `admin123` 登录。

> 这个方式会 Fork 仓库到你的账号（Cloudflare 的机制如此，无法关闭），好处是以后可以在你 Fork 的仓库点 **Sync fork** 同步源仓库更新，Cloudflare 会自动重新部署。

## 方式二：连接 GitHub 导入（不 Fork，需手动建 D1）

<details>
    <summary> ☜ Read more 👨‍💻</summary>
  
如果你不想 Fork、想直接连接本仓库导入，按下面步骤操作：

1. **先创建 D1 数据库**：Cloudflare Dashboard → **存储和数据库 → D1 SQL 数据库 → 创建**，名称随便填（例如 `oci-helper-db`，只是给你自己看的标签），创建即可。
2. **导入项目**：Workers & Pages → **创建 → 连接 GitHub**，选择本仓库（`oci-helper-serverless-cf`），在构建设置里把**部署命令**改为：
   ```
   npx wrangler deploy --config wrangler.import.toml
   ```
   （`wrangler.import.toml` 是专门为不 Fork 方式准备的配置，不声明 D1，因此不会因占位符 `database_id` 而部署失败。）
3. **绑定 D1**：部署完成后，进入该 Worker → **设置 → 绑定 → 添加绑定**，类型选 **D1 数据库**，**变量名称必须填 `DB`**（大小写一致），选择第 1 步创建的数据库，保存。
4. **重新部署**：在 Worker 的 **部署** 页点一次重新部署，让绑定生效。Worker 首次请求时会自动建表，无需执行任何 SQL 命令。
5. 打开 Worker 域名，用默认密码 `admin123` 登录。

> 为何方式二不能自动建库：Cloudflare 的"连接 GitHub 导入仓库"流程不会读取占位符自动创建 D1，只有 Deploy 按钮的向导才会。因此这里用 `wrangler.import.toml` 跳过 D1 声明，再在 Dashboard 里手动绑定（变量名 `DB`）。数据库名称本身随便，Worker 只认绑定变量名 `DB`。

</details>

## 方式三：本机命令行部署（可选）

<details>
    <summary> ☜ Read more 👨‍💻</summary>
  
如果你想在自己机器上部署：

```bash
git clone https://github.com/Yohann0617/oci-helper-serverless-cf.git
cd oci-helper-serverless-cf
npm install -g wrangler
wrangler login
wrangler d1 create oci-helper-serverless   # 把返回的 database_id 填进 wrangler.toml
wrangler deploy
```

</details>

## 部署后必做（安全🔒）

登录后请尽快：
1. 在 Cloudflare 控制台 → Workers & Pages → 你的 Worker → **Settings → Variables and Secrets** 添加：
   - `AUTH_PASSWORD`：你的登录密码（替换默认 `admin123`）
   - `AUTH_SECRET`：一串随机长字符串（用于签名登录 token）
   - `KEY_SECRET`：另一串随机长字符串（用于加密 OCI 私钥；**修改后已录入的私钥需重新添加**）
2. 在「系统设置」页填写 Telegram Bot Token / Chat ID（可选，用于通知）。

> 提示：默认密码 `admin123` 仅用于首次登录演示，公网部署后务必修改。

## 需要哪些API权限
在 OCI 控制台创建一个 IAM 用户 + API Key，把 user OCID / tenancy OCID / fingerprint / 私钥填到系统设置。建议给该用户单独的组，策略最小化，例如：

```
Allow group <你的组> to manage instance-family in tenancy
Allow group <你的组> to manage volume-family in tenancy
Allow group <你的组> to manage virtual-network-family in tenancy
Allow group <你的组> to read identities in tenancy
Allow group <你的组> to inspect limits in tenancy
```

换 IP 任务需要 `manage vnic-attachment-family in tenancy`。配额查询功能需要 `inspect limits in tenancy`（上面策略已包含）。本项目不调用容量报告接口，无需 `compute-capacity-report-family` 权限。

## 后续更新

- **方式一（Fork 用户）**：在你 Fork 的仓库页面点 **Sync fork → Update branch**，Cloudflare 会自动重新部署；如未自动触发，在 Cloudflare Dashboard 手动点 **Deploy**，或重新打开部署按钮向导选择已有仓库。
- **方式二（直接导入用户）**：本仓库更新后，因 Cloudflare 已连接该 GitHub 仓库，通常会自动构建；若没有，在 Worker 的 **部署** 页点 **Deploy** 触发一次即可。

## 隐私与数据

- 所有 OCI 私钥用 `KEY_SECRET` 派生的 AES-256-GCM 加密后存在**你自己的 D1 数据库**，本项目不收集任何数据。

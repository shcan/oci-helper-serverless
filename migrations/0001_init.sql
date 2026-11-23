-- OCI Helper Serverless —— 完整 D1 初始化（合并历史所有增量迁移，幂等，可重复执行）
-- 说明：本文件即最终 schema；线上已执行过旧迁移的数据库再次执行不会破坏已有数据
--       （全部 CREATE TABLE IF NOT EXISTS / CREATE INDEX IF NOT EXISTS）。

-- ---------------------------------------------------------------- 配置
CREATE TABLE IF NOT EXISTS oci_cfg (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  tenancy_ocid      TEXT NOT NULL,
  user_ocid         TEXT NOT NULL,
  fingerprint       TEXT NOT NULL,
  region            TEXT NOT NULL,
  compartment_id    TEXT,
  private_key_enc   TEXT NOT NULL,       -- AES-GCM 加密（KEY_SECRET）
  passphrase_enc    TEXT,                -- AES-GCM 加密
  proxy             TEXT,
  tenant_name       TEXT,
  plan_type         TEXT,                -- FREE_TIER / PAYG
  regions           TEXT,                -- 已订阅区域 JSON 数组
  tenant_meta       TEXT,                -- getTenancy 缓存 JSON
  status            TEXT NOT NULL DEFAULT 'unknown',
  last_error        TEXT,
  last_checked_at   TEXT,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_oci_cfg_created ON oci_cfg (created_at DESC);

-- ---------------------------------------------------------------- 任务（抢机 + 换 IP 共用，type 区分）
CREATE TABLE IF NOT EXISTS task (
  id                  TEXT PRIMARY KEY,
  cfg_id              TEXT NOT NULL,
  type                TEXT NOT NULL DEFAULT 'launch',   -- launch | ip
  name                TEXT,
  status              TEXT NOT NULL DEFAULT 'running',
  region              TEXT,
  availability_domain TEXT,
  compartment_id      TEXT,                -- 指定区间（Compartment），空则用配置默认值
  shape               TEXT,
  ocpus               REAL,
  memory_gb           REAL,
  boot_volume_gb      INTEGER,
  os_name             TEXT,
  os_version          TEXT,
  image_id            TEXT,
  subnet_id           TEXT,
  root_password       TEXT,
  ssh_public_key      TEXT,                -- 与 root_password 二选一
  target_count        INTEGER NOT NULL DEFAULT 1,
  success_count       INTEGER NOT NULL DEFAULT 0,
  attempt_count       INTEGER NOT NULL DEFAULT 0,
  interval_sec        INTEGER NOT NULL DEFAULT 60,
  capacity_check      INTEGER NOT NULL DEFAULT 1,
  instance_id         TEXT,                -- 换 IP 任务的目标实例
  instance_name       TEXT,
  ip_version          TEXT NOT NULL DEFAULT 'ipv4',  -- ipv4 | ipv6
  cidr_list           TEXT,
  last_ip             TEXT,
  last_message        TEXT,
  last_error          TEXT,
  dns_record          TEXT,                -- 换 IP 后同步到 Cloudflare DNS 的记录
  dns_zone_id         TEXT,
  dns_proxied         INTEGER NOT NULL DEFAULT 0,
  next_run_at         INTEGER NOT NULL DEFAULT 0,
  locked_until        INTEGER,
  created_at          TEXT NOT NULL,
  updated_at          TEXT NOT NULL,
  FOREIGN KEY (cfg_id) REFERENCES oci_cfg (id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_task_due ON task (status, next_run_at);
CREATE INDEX IF NOT EXISTS idx_task_cfg ON task (cfg_id, created_at DESC);

-- ---------------------------------------------------------------- 系统配置（key/value，敏感项 AES-GCM 加密）
CREATE TABLE IF NOT EXISTS sys_cfg (
  key        TEXT PRIMARY KEY,
  value      TEXT,
  updated_at TEXT NOT NULL
);

# KidsHabitHelper 开发进度与后续计划

> 最后更新：2026-06-14

---

## 项目概述

**习惯养成助手** — 帮助家长管理小孩日常习惯打卡的应用，通过奖惩规则（以分钟计）激励孩子养成好习惯。

**技术栈：**
- Flutter (Android / iOS / Web)
- Drift (本地 SQLite 数据库)
- Riverpod (状态管理)
- GoRouter (路由)
- 微信云开发 CloudBase (云同步后端)
- 微信小程序 (第二客户端)

**架构：**

```
微信小程序 ──(原生 SDK)──→ 微信云数据库
                              ↕
Flutter App  ──(HTTP API)──→ 云函数 ──→ 微信云数据库
```

---

## 当前开发进度

### 已完成

#### 1. Flutter 项目脚手架 (d8700f2)
- [x] Flutter 项目初始化，配置所有依赖
- [x] 依赖项：flutter_riverpod, drift, go_router, fl_chart, http, shared_preferences

#### 2. 本地数据库层 (be48280)
- [x] Drift 数据库定义，三张核心表：
  - `children` — 小孩档案（姓名、头像、余额）
  - `rules` — 奖惩规则（名称、分钟变化量、图标）
  - `records` — 打卡记录（关联小孩和规则）
- [x] 数据库查询方法（CRUD + 聚合查询）
- [x] Web 平台 WASM 数据库适配

#### 3. Repository + Provider 层 (009360c)
- [x] `ChildRepository` / `RuleRepository` / `RecordRepository` — 数据访问层
- [x] Riverpod Providers：状态管理 + 依赖注入
- [x] 数据库单元测试

#### 4. 全部 UI 页面 (6e5eb33)
- [x] **首页**：小孩卡片列表，显示余额
- [x] **小孩详情页**：快捷打卡按钮 + 历史记录
- [x] **规则表单页**：新增/编辑规则
- [x] **统计页**：余额趋势图表 + 规则汇总
- [x] **设置页**：数据管理入口
- [x] **小孩表单页**：新增/编辑小孩信息

#### 5. Web 平台支持 (ab6fe24)
- [x] Drift WASM 数据库集成
- [x] Web 平台适配（数据库 stub/impl 分离）

#### 6. 目录重构 + Firebase → CloudBase 迁移
- [x] Flutter 项目从根目录迁移到 `app/` 子目录
- [x] 移除 Firebase 依赖
- [x] 新建微信云开发 HTTP API 数据源 (`CloudBaseDatasource`)
- [x] 新建 CloudBase 认证服务 (`CloudBaseAuthService`)
- [x] 创建 `shared/data-schema.md` — 两端共享的数据结构文档
- [x] 创建 `shared/migration-plan.md` — 迁移方案文档
- [x] 认证页面（登录 / 注册）
- [x] 同步 Provider (`SyncProvider`)

#### 7. 微信小程序项目骨架
- [x] `miniprogram/` 目录结构创建
- [x] 基础配置文件 (`project.config.json`, `app.json`, `app.js`)
- [x] 小程序前端页面结构

#### 8. 云函数实现 (c27dc34)
- [x] `login` 云函数 — 双模式：小程序 callFunction 返回 openid + HTTP POST 邮箱密码登录
- [x] `register` 云函数 — HTTP POST 注册 + SHA-256 密码哈希
- [x] `sync` 云函数 — REST HTTP API（GET/POST/DELETE）+ sync_meta 管理

#### 9. Flutter 数据源修复 (ab27263)
- [x] `CloudBaseDatasource` 改为 query-param 路由，匹配 data-schema.md API 规范

#### 10. 小程序前端开发 (513c639, cba6f3c)
- [x] 首页：小孩列表 + 余额（聚合计算）
- [x] 详情页：快捷打卡 + 头像选择器
- [x] 规则管理页：新增 / 编辑 / 删除规则
- [x] 统计页：按时间段统计
- [x] 设置页：缓存清除 + 关于
- [x] 数据模型对齐 data-schema.md（minutesChange, userId, avatar, icon）
- [x] 改用 `wx.cloud.database()` 直连数据库

#### 11. 计时器功能（24h 内、秒级）
- [x] 小程序：`pages/timer` 页面 + `utils/timer.js` 纯逻辑
- [x] 小程序：前台 setKeepScreenOn + InnerAudioContext 提示音 + 结束确认打卡
- [x] 小程序：订阅消息后台通知（需用户每次授权）
- [x] 云函数 `timer-notify`：定时触发器扫描 timers 集合发订阅消息
- [x] Flutter：`TimerProvider`（Riverpod）+ `ActiveTimer` 模型
- [x] Flutter：`flutter_local_notifications` 后台定时通知 + `audioplayers` 提示音
- [x] Flutter：计时器页面 + 详情页入口

---

## 项目目录结构

```
D:\KidsHabitHelper\
├── app/                              ← Flutter 项目
│   ├── lib/
│   │   ├── auth/                     ← 认证服务
│   │   │   └── cloudbase_auth_service.dart
│   │   ├── data/
│   │   │   └── remote/               ← 远程数据源
│   │   │       ├── remote_datasource.dart
│   │   │       ├── cloudbase_datasource.dart
│   │   │       └── sync_service.dart
│   │   ├── database/                 ← Drift 本地数据库
│   │   │   ├── app_database.dart
│   │   │   ├── app_database.g.dart
│   │   │   ├── tables.dart
│   │   │   ├── web_db_impl.dart
│   │   │   └── web_db_stub.dart
│   │   ├── pages/                    ← UI 页面
│   │   │   ├── auth/                 ← 登录/注册页
│   │   │   ├── child_detail_page.dart
│   │   │   ├── child_form_page.dart
│   │   │   ├── home_page.dart
│   │   │   ├── rule_form_page.dart
│   │   │   ├── settings_page.dart
│   │   │   └── statistics_page.dart
│   │   ├── providers/                ← Riverpod Providers
│   │   │   ├── auth_provider.dart
│   │   │   ├── child_provider.dart
│   │   │   ├── database_provider.dart
│   │   │   ├── record_provider.dart
│   │   │   ├── rule_provider.dart
│   │   │   └── sync_provider.dart
│   │   ├── repositories/             ← 数据仓库
│   │   │   ├── child_repository.dart
│   │   │   ├── record_repository.dart
│   │   │   └── rule_repository.dart
│   │   ├── router.dart               ← GoRouter 路由配置
│   │   └── main.dart                 ← 应用入口
│   ├── android/
│   ├── web/
│   ├── test/
│   └── pubspec.yaml
├── miniprogram/                      ← 微信小程序
│   ├── miniprogram/                  ← 小程序前端
│   │   ├── pages/
│   │   ├── components/
│   │   ├── app.js / app.json / app.wxss
│   │   └── ...
│   ├── cloudfunctions/               ← 云函数
│   │   ├── login/                    ← 登录（双模式）
│   │   ├── register/                 ← 注册（HTTP + 密码哈希）
│   │   └── sync/                     ← 数据同步（REST API）
│   └── project.config.json
└── shared/                           ← 共享文档
    ├── data-schema.md                ← 数据结构 + API 定义
    └── migration-plan.md             ← 迁移方案
```

---

## 待完成事项

### P0 — 核心功能（发布前必须完成）

#### 1. 云函数实现与部署
- [x] 实现 `login` 云函数 — 邮箱密码登录
- [x] 实现 `register` 云函数 — 用户注册（含密码哈希）
- [x] 实现 `sync` 云函数 — 数据 CRUD（upsert / pull / delete）
- [x] 实现 `sync/meta` — 同步时间戳管理（集成在 sync 函数中）
- [ ] 部署云函数到微信云开发环境
- [ ] 配置云函数 HTTP 触发 URL

#### 2. Flutter 端同步功能联调
- [ ] 配置云开发环境 ID（需创建环境后获得）
- [ ] 端到端测试：登录 → 打卡 → 同步 → 拉取
- [ ] 增量同步逻辑验证（since 参数）
- [ ] 冲突处理策略（本地优先 / 远程优先 / 时间戳对比）
- [ ] 离线模式支持（无网络时本地操作，联网后自动同步）

#### 3. 构建与发布
- [ ] `flutter analyze` 通过（无 error）
- [ ] `flutter test` 通过
- [ ] Android APK 构建成功
- [ ] Web 构建成功并部署
- [ ] iOS 构建验证（如需支持）

### P1 — 微信小程序端

#### 4. 小程序前端开发
- [x] 首页：小孩列表 + 余额显示
- [x] 小孩详情页：快捷打卡
- [x] 规则管理页：新增 / 编辑 / 删除
- [x] 统计页：余额图表 + 记录汇总
- [x] 设置页：缓存清除 + 关于

#### 5. 小程序云开发集成
- [x] 用户登录（微信授权 → openid）
- [x] 云数据库直接操作（无需云函数中转）
- [x] 数据与 Flutter 端同步（共享同一云数据库）
- [x] 小程序端数据模型验证（对齐 `data-schema.md`）

### P2 — 体验优化

#### 6. UI/UX 改进
- [ ] 深色模式支持
- [ ] 多语言支持（中文 / 英文）
- [ ] 动画与过渡效果优化
- [ ] 打卡成功反馈动画
- [ ] 下拉刷新 + 加载状态
- [ ] 空状态提示页（无小孩 / 无规则 / 无记录）

#### 7. 数据与安全
- [ ] 本地数据加密（敏感字段）
- [ ] Token 安全存储（flutter_secure_storage）
- [ ] 输入校验（表单字段）
- [ ] 数据备份 / 导出功能
- [ ] 数据清除确认对话框

#### 8. 测试覆盖
- [ ] Repository 层单元测试
- [ ] Provider 层单元测试
- [ ] Widget 测试（关键页面）
- [ ] 集成测试（同步流程）
- [ ] 云函数单元测试

### P3 — 功能扩展

#### 9. 高级功能
- [ ] 多家长共享（家庭组）
- [ ] 推送通知（打卡提醒）
- [ ] 自定义时间段统计（周 / 月 / 自定义）
- [ ] 小孩自定义主题 / 头像上传
- [ ] 打卡日历视图
- [ ] 成就系统（连续打卡徽章）

---

## 技术债务

| 项目 | 说明 | 优先级 |
|------|------|--------|
| Web 数据库 print 语句 | `web_db_impl.dart` 使用 print 调试，应替换为日志框架 | 低 |
| 原根目录遗留文件 | `android/` 目录因文件锁未清理，原 `lib/` 等目录仍存在 | 中 |
| 代码风格统一 | 部分 Provider 中有未使用的导入或变量 | 低 |

---

## 关键依赖版本

| 包名 | 版本 | 用途 |
|------|------|------|
| flutter_riverpod | ^3.3.1 | 状态管理 |
| drift | ^2.33.0 | 本地数据库 |
| drift_flutter | ^0.3.0 | Drift 平台适配 |
| go_router | ^17.2.3 | 路由导航 |
| fl_chart | ^0.70.2 | 图表 |
| http | ^1.4.0 | HTTP 请求 |
| shared_preferences | ^2.5.3 | 本地存储 |
| sqlite3 | ^3.3.0 | Web WASM 数据库 |
| flutter_local_notifications | ^19.0.0 | 本地定时通知（计时器） |
| audioplayers | ^6.1.0 | 计时器提示音 |
| timezone | ^0.10.1 | 通知时区处理 |

---

## Git 提交历史

| 提交 | 说明 |
|------|------|
| `d8700f2` | chore: scaffold Flutter project with dependencies |
| `be48280` | feat: add drift database tables and query methods |
| `009360c` | feat: add repositories, providers, and database tests |
| `6e5eb33` | feat: implement all UI pages - home, child detail, statistics, settings |
| `ab6fe24` | feat: add web platform support with drift wasm database |
| `d7990ff` | feat: migrate Firebase to CloudBase, restructure project |
| `c27dc34` | feat: rewrite cloud functions with HTTP API and password hashing |
| `ab27263` | fix: rewrite CloudBaseDatasource to use query-param routing |
| `513c639` | feat: rewrite mini program pages with direct DB and schema-aligned model |
| `cba6f3c` | feat: add rule-manage and settings pages, simplify app.js |

---

## 参考文档

- `shared/data-schema.md` — 云数据库集合结构 + 云函数 HTTP API 完整定义
- `shared/migration-plan.md` — Firebase → CloudBase 迁移方案 + 实施步骤

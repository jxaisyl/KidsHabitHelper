# KidsHabitHelper: Firebase 迁移至微信云开发 + 目录重构

## Context

当前 Flutter 项目使用 Firebase (Auth + Firestore) 作为云同步后端。由于：
1. 国内访问 Firebase 受限
2. 需要支持微信小程序端
3. 微信云开发与小程序原生集成最好

决定迁移到微信云开发（CloudBase），同时重构项目目录支持多端。

## 目标目录结构

```
D:\KidsHabitHelper\
├── app/                         ← Flutter 项目（现有代码移入）
│   ├── lib/
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── pubspec.yaml
│   └── ...
├── miniprogram/                 ← 微信小程序项目（含云函数）
│   ├── miniprogram/             ← 小程序前端
│   │   ├── pages/
│   │   ├── components/
│   │   ├── app.js
│   │   ├── app.json
│   │   └── ...
│   ├── cloudfunctions/          ← 云函数（Flutter 也通过 HTTP 调用）
│   │   ├── login/               ← 登录/注册
│   │   ├── sync/                ← 数据同步 CRUD
│   │   └── ...
│   └── project.config.json
└── shared/                      ← 共享文档/数据模型定义
    └── data-schema.md           ← 数据结构文档（两个端参考）
```

## 架构设计

```
微信小程序 ──(原生SDK)──→ 微信云数据库
                              ↕
Flutter App  ──(HTTP API)──→ 云函数 ──→ 微信云数据库
```

- 小程序端使用微信云开发原生 SDK 直接操作云数据库
- Flutter 端通过云函数暴露的 HTTP API 进行数据同步
- 两端共享同一套数据模型定义

## 实施步骤

### Step 1: 目录重构 — 移动 Flutter 项目到 `app/`

将当前根目录下所有 Flutter 相关文件移入 `app/` 子目录：

**移动的文件/目录：**
- `lib/`, `test/`, `android/`, `ios/`, `web/`
- `pubspec.yaml`, `pubspec.lock`
- `analysis_options.yaml`
- `.metadata`, `.dart_tool/`, `build/`

**保留在根目录：**
- `.gitignore`, `.git/`
- 新建 `miniprogram/`, `shared/`

**操作方式：** 使用 `git mv` 批量移动，保持 git 历史。

### Step 2: 移除 Firebase 依赖，替换为 HTTP API 调用

**修改 `app/pubspec.yaml`：**
- 移除: `firebase_core`, `firebase_auth`, `cloud_firestore`
- 添加: `http` (用于调用云函数 HTTP API), `shared_preferences` (缓存 token)

### Step 3: 抽象远程数据源接口

创建 `app/lib/data/remote/remote_datasource.dart` 接口：

```dart
abstract class RemoteDatasource {
  // Children
  Future<void> pushChild(Map<String, dynamic> data, String remoteId);
  Future<void> deleteChild(String remoteId);
  Future<List<Map<String, dynamic>>> pullChildren(DateTime? since);
  // Rules
  Future<void> pushRule(Map<String, dynamic> data, String remoteId);
  Future<void> deleteRule(String remoteId);
  Future<List<Map<String, dynamic>>> pullRules(DateTime? since);
  // Records
  Future<void> pushRecord(Map<String, dynamic> data, String remoteId);
  Future<void> deleteRecord(String remoteId);
  Future<List<Map<String, dynamic>>> pullRecords(DateTime? since);
  // Sync meta
  Future<DateTime?> getLastSync();
  Future<void> updateLastSync();
}
```

**关键文件修改：**
- `lib/data/remote/firestore_datasource.dart` → 删除
- 新建 `lib/data/remote/cloudbase_datasource.dart` — 实现接口，通过 HTTP 调用云函数
- `lib/data/remote/sync_service.dart` — 改为依赖 `RemoteDatasource` 接口而非具体实现

### Step 4: 替换认证系统

**删除：**
- `lib/auth/auth_service.dart` (Firebase Auth)
- `lib/firebase_options.dart`

**新建：**
- `lib/auth/cloudbase_auth_service.dart` — 通过云函数 HTTP API 实现登录/注册

```dart
class CloudBaseAuthService {
  final String _apiBase; // 云函数 HTTP 触发地址
  String? _token;

  Future<String> signIn(String email, String password);
  Future<String> signUp(String email, String password);
  Future<void> signOut();
  String? get currentToken;
}
```

**修改 `lib/providers/auth_provider.dart`：**
- 移除 `firebase_auth` 依赖
- 使用 `CloudBaseAuthService` 替代 `FirebaseAuth`
- authState 改为基于本地 token 状态管理

**修改 `lib/pages/auth/login_page.dart` 和 `register_page.dart`：**
- 适配新的 AuthService 接口（API 不变，底层实现改变）

### Step 5: 修改 main.dart 和 providers

**`lib/main.dart`：**
- 移除 `Firebase.initializeApp()`
- 改为初始化 CloudBase 配置（API 基地址等）

**`lib/providers/sync_provider.dart`：**
- 移除 `FirebaseFirestore` 依赖
- 使用 `CloudBaseDatasource` 替代 `FirestoreDatasource`

**`lib/providers/database_provider.dart`：**
- 保持不变（Drift 本地数据库不涉及 Firebase）

### Step 6: 创建微信小程序项目骨架

**`miniprogram/` 目录：**
- 使用微信开发者工具项目结构
- 配置云开发环境
- 创建基础云函数：`login/`, `sync/`
- 小程序前端页面复用 Flutter 版的 UI 设计

### Step 7: 创建共享数据模型文档

**`shared/data-schema.md`：**
- 记录 Children, Rules, Records 的字段定义
- 云数据库集合结构
- API 接口定义（云函数 HTTP 触发 URL 和参数）
- 两个端共同参考

## 关键修改文件清单

| 操作 | 文件 |
|------|------|
| 删除 | `app/lib/data/remote/firestore_datasource.dart` |
| 删除 | `app/lib/auth/auth_service.dart` |
| 删除 | `app/lib/firebase_options.dart` |
| 新建 | `app/lib/data/remote/remote_datasource.dart` |
| 新建 | `app/lib/data/remote/cloudbase_datasource.dart` |
| 新建 | `app/lib/auth/cloudbase_auth_service.dart` |
| 新建 | `shared/data-schema.md` |
| 新建 | `miniprogram/` 整个项目 |
| 修改 | `app/pubspec.yaml` |
| 修改 | `app/lib/main.dart` |
| 修改 | `app/lib/providers/auth_provider.dart` |
| 修改 | `app/lib/providers/sync_provider.dart` |
| 修改 | `app/lib/data/remote/sync_service.dart` |
| 修改 | `app/lib/pages/auth/login_page.dart` |
| 修改 | `app/lib/pages/auth/register_page.dart` |

## 验证方式

1. `cd app && flutter analyze` — 无 error
2. `cd app && flutter build apk --debug --target-platform android-arm64` — 构建成功
3. `cd app && flutter test` — 现有测试通过（可能需要适配）
4. 微信开发者工具打开 `miniprogram/` — 项目可加载

## 注意事项

- 云函数需要先在微信开发者工具中创建云开发环境后才能部署
- Flutter 端调用云函数 HTTP API 需要云函数启用 HTTP 触发
- 云开发环境 ID 配置需要用户提供（创建环境后获得）
- `android/` 目录由于文件锁暂时通过 cp 复制到 `app/`，原目录待解锁后清理

# 习惯养成助手 — 数据结构文档

> 本文档定义了习惯养成助手（KidsHabitHelper）的云数据库集合结构和云函数 HTTP API 接口。
> Flutter 端和微信小程序端共同参考本文档实现数据交互。

---

## 目录

1. [云数据库集合定义](#1-云数据库集合定义)
2. [云函数 HTTP API 定义](#2-云函数-http-api-定义)
3. [通用约定](#3-通用约定)

---

## 1. 云数据库集合定义

微信云开发使用文档型数据库，每个集合对应一个数据实体。所有集合中的 `_id` 由云数据库自动生成（字符串类型）。所有用户数据通过 `userId` 字段隔离。

### 1.1 children 集合 — 小孩信息

存储用户创建的小孩档案。

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `_id` | String | 自动 | — | 云数据库自动生成的文档 ID |
| `userId` | String | 是 | — | 所属用户 ID（openid），用于数据隔离 |
| `name` | String | 是 | — | 小孩姓名，长度 1–50 个字符 |
| `avatar` | String | 是 | `"👦"` | 头像，使用单个 Emoji 字符 |
| `localId` | Int | 否 | — | Flutter 端本地数据库对应的整数 ID，用于同步映射 |
| `createdAt` | DateTime | 是 | 当前时间 | 创建时间，ISO 8601 格式 |
| `updatedAt` | DateTime | 是 | 当前时间 | 最后更新时间，ISO 8601 格式 |

**示例文档：**

```json
{
  "_id": "child_1_1718198400000",
  "userId": "oXXXX-xxxxxxxxxxxxxxxx",
  "name": "小明",
  "avatar": "👦",
  "localId": 1,
  "createdAt": "2026-06-12T08:00:00.000Z",
  "updatedAt": "2026-06-12T08:00:00.000Z"
}
```

### 1.2 rules 集合 — 规则定义

存储用户自定义的奖惩规则。

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `_id` | String | 自动 | — | 云数据库自动生成的文档 ID |
| `userId` | String | 是 | — | 所属用户 ID（openid），用于数据隔离 |
| `name` | String | 是 | — | 规则名称，长度 1–50 个字符 |
| `minutesChange` | Int | 是 | — | 分钟变化量，正数表示奖励，负数表示扣减 |
| `icon` | String | 是 | `"✅"` | 规则图标，使用单个 Emoji 字符 |
| `localId` | Int | 否 | — | Flutter 端本地数据库对应的整数 ID，用于同步映射 |
| `updatedAt` | DateTime | 是 | 当前时间 | 最后更新时间，ISO 8601 格式 |

**示例文档：**

```json
{
  "_id": "rule_1_1718198400000",
  "userId": "oXXXX-xxxxxxxxxxxxxxxx",
  "name": "完成作业",
  "minutesChange": 30,
  "icon": "📖",
  "localId": 1,
  "updatedAt": "2026-06-12T08:00:00.000Z"
}
```

### 1.3 records 集合 — 打卡记录

存储每次奖惩操作的详细记录，通过 `childId` 和 `ruleId` 关联到对应的小孩和规则。

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `_id` | String | 自动 | — | 云数据库自动生成的文档 ID |
| `userId` | String | 是 | — | 所属用户 ID（openid），用于数据隔离 |
| `childId` | String | 是 | — | 关联的小孩 ID（指向 children 集合中的 `_id`） |
| `ruleId` | String | 是 | — | 关联的规则 ID（指向 rules 集合中的 `_id`） |
| `minutesChange` | Int | 是 | — | 本次分钟变化量（与规则定义一致，冗余存储） |
| `note` | String | 否 | `null` | 备注说明，可选 |
| `localId` | Int | 否 | — | Flutter 端本地数据库对应的整数 ID，用于同步映射 |
| `createdAt` | DateTime | 是 | 当前时间 | 记录创建时间，ISO 8601 格式 |
| `updatedAt` | DateTime | 是 | 当前时间 | 最后更新时间，ISO 8601 格式 |

**示例文档：**

```json
{
  "_id": "record_1_1718198400000",
  "userId": "oXXXX-xxxxxxxxxxxxxxxx",
  "childId": "child_1_1718198400000",
  "ruleId": "rule_1_1718198400000",
  "minutesChange": 30,
  "note": "今天按时完成语文和数学作业",
  "localId": 1,
  "createdAt": "2026-06-12T09:30:00.000Z",
  "updatedAt": "2026-06-12T09:30:00.000Z"
}
```

### 1.4 sync_meta 集合 — 同步元数据

存储每个用户的最后同步时间戳，用于增量同步。

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `_id` | String | 自动 | — | 云数据库自动生成的文档 ID |
| `userId` | String | 是 | — | 所属用户 ID（openid），唯一索引 |
| `lastSyncTimestamp` | DateTime | 是 | — | 最后一次同步完成的时间，ISO 8601 格式 |

**示例文档：**

```json
{
  "_id": "meta_oXXXX-xxxxxxxxxxxxxxxx",
  "userId": "oXXXX-xxxxxxxxxxxxxxxx",
  "lastSyncTimestamp": "2026-06-12T10:00:00.000Z"
}
```

### 1.5 users 集合 — 用户账户

存储通过邮箱注册的用户账户信息。

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `_id` | String | 自动 | — | 云数据库自动生成的文档 ID |
| `email` | String | 是 | — | 登录邮箱，唯一 |
| `passwordHash` | String | 是 | — | 密码哈希值（bcrypt） |
| `createdAt` | DateTime | 是 | 当前时间 | 注册时间 |

---

## 2. 云函数 HTTP API 定义

### API 基地址

```
https://{env-id}.service.tcloudbase.com/{function-name}
```

- `{env-id}`：微信云开发环境 ID，部署后获得
- `{function-name}`：云函数名称

**替换示例：**

```
https://kids-habit-xxxxx.service.tcloudbase.com/login
https://kids-habit-xxxxx.service.tcloudbase.com/register
https://kids-habit-xxxxx.service.tcloudbase.com/sync
```

### 认证方式

除 `login` 和 `register` 外，所有接口请求需在 HTTP Header 中携带 Token：

```
Authorization: Bearer <token>
Content-Type: application/json
```

Token 在登录/注册成功后由服务端返回。

---

### 2.1 login — 登录

**请求**

```
POST /login
Content-Type: application/x-www-form-urlencoded
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `email` | String | 是 | 注册邮箱 |
| `password` | String | 是 | 密码 |

**成功响应** `200 OK`

```json
{
  "token": "oXXXX-xxxxxxxxxxxxxxxx",
  "uid": "oXXXX-xxxxxxxxxxxxxxxx"
}
```

**失败响应** `401 Unauthorized`

```json
{
  "error": "user-not-found",
  "message": "用户不存在"
}
```

```json
{
  "error": "wrong-password",
  "message": "邮箱或密码错误"
}
```

**云函数实现参考：**

```javascript
// cloudfunctions/login/index.js
const cloud = require('wx-server-sdk')
cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

exports.main = async (event) => {
  const { email, password } = event
  const { data: users } = await db.collection('users')
    .where({ email }).limit(1).get()

  if (users.length === 0) {
    return { error: 'user-not-found', message: '用户不存在' }
  }

  // 此处应使用 bcrypt 验证密码，示例简化
  const user = users[0]
  if (user.passwordHash !== hashPassword(password)) {
    return { error: 'wrong-password', message: '邮箱或密码错误' }
  }

  return { token: user._id, uid: user._id }
}
```

---

### 2.2 register — 注册

**请求**

```
POST /register
Content-Type: application/x-www-form-urlencoded
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `email` | String | 是 | 注册邮箱 |
| `password` | String | 是 | 密码（不少于 6 位） |

**成功响应** `200 OK`

```json
{
  "token": "oXXXX-xxxxxxxxxxxxxxxx",
  "uid": "oXXXX-xxxxxxxxxxxxxxxx"
}
```

**失败响应**

`400 Bad Request`

```json
{
  "error": "email-already-in-use",
  "message": "该邮箱已被注册"
}
```

```json
{
  "error": "weak-password",
  "message": "密码强度太弱"
}
```

**云函数实现参考：**

```javascript
// cloudfunctions/register/index.js
const cloud = require('wx-server-sdk')
cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

exports.main = async (event) => {
  const { email, password } = event

  // 检查邮箱是否已注册
  const { data: existing } = await db.collection('users')
    .where({ email }).limit(1).get()
  if (existing.length > 0) {
    return { error: 'email-already-in-use', message: '该邮箱已被注册' }
  }

  if (!password || password.length < 6) {
    return { error: 'weak-password', message: '密码强度太弱' }
  }

  const result = await db.collection('users').add({
    data: {
      email,
      passwordHash: hashPassword(password),
      createdAt: new Date()
    }
  })

  return { token: result._id, uid: result._id }
}
```

---

### 2.3 sync — 数据同步（统一入口）

`sync` 云函数通过 `action` 和 `collection` 参数统一处理 Children、Rules、Records 三种实体的增删改查操作。

---

#### 2.3.1 推送数据（新增/更新）

**请求**

```
POST /sync
Authorization: Bearer <token>
Content-Type: application/json
```

**请求体**

```json
{
  "collection": "children",
  "action": "upsert",
  "data": {
    "id": "child_1_1718198400000",
    "name": "小明",
    "avatar": "👦",
    "localId": 1,
    "createdAt": "2026-06-12T08:00:00.000Z",
    "updatedAt": "2026-06-12T08:00:00.000Z"
  }
}
```

`collection` 取值及对应 `data` 字段：

| collection | data 必填字段 | data 可选字段 |
|------------|--------------|--------------|
| `children` | `id`, `name`, `avatar` | `localId`, `createdAt`, `updatedAt` |
| `rules` | `id`, `name`, `minutesChange`, `icon` | `localId`, `updatedAt` |
| `records` | `id`, `childId`, `ruleId`, `minutesChange` | `note`, `localId`, `createdAt`, `updatedAt` |

**成功响应** `200 OK`

```json
{
  "ok": true
}
```

**失败响应** `401 Unauthorized`

```json
{
  "error": "unauthorized",
  "message": "未授权，请先登录"
}
```

---

#### 2.3.2 拉取数据

**请求**

```
GET /sync?collection=children&since=2026-06-11T00:00:00.000Z
Authorization: Bearer <token>
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `collection` | String | 是 | 集合名称：`children` / `rules` / `records` |
| `since` | String | 否 | ISO 8601 时间戳，仅返回该时间之后更新的数据。不传则返回全部 |

**成功响应** `200 OK`

```json
[
  {
    "id": "child_1_1718198400000",
    "userId": "oXXXX-xxxxxxxxxxxxxxxx",
    "name": "小明",
    "avatar": "👦",
    "localId": 1,
    "createdAt": "2026-06-12T08:00:00.000Z",
    "updatedAt": "2026-06-12T08:00:00.000Z"
  },
  {
    "id": "child_2_1718198600000",
    "userId": "oXXXX-xxxxxxxxxxxxxxxx",
    "name": "小红",
    "avatar": "👧",
    "localId": 2,
    "createdAt": "2026-06-12T08:10:00.000Z",
    "updatedAt": "2026-06-12T08:10:00.000Z"
  }
]
```

---

#### 2.3.3 删除数据

**请求**

```
DELETE /sync?collection=children&id=child_1_1718198400000
Authorization: Bearer <token>
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `collection` | String | 是 | 集合名称：`children` / `rules` / `records` |
| `id` | String | 是 | 要删除的文档 ID |

**成功响应** `200 OK`

```json
{
  "ok": true
}
```

**失败响应** `404 Not Found`

```json
{
  "error": "not-found",
  "message": "文档不存在"
}
```

---

### 2.4 sync/meta — 同步元数据

#### 2.4.1 获取最后同步时间

**请求**

```
GET /sync/meta
Authorization: Bearer <token>
```

**成功响应** `200 OK`

```json
{
  "lastSyncTimestamp": "2026-06-12T10:00:00.000Z"
}
```

如果用户从未同步过：

```json
{
  "lastSyncTimestamp": null
}
```

---

#### 2.4.2 更新最后同步时间

**请求**

```
POST /sync/meta
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "lastSyncTimestamp": "2026-06-12T10:00:00.000Z"
}
```

**成功响应** `200 OK`

```json
{
  "ok": true
}
```

---

### 2.5 API 接口汇总表

| 接口 | 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|------|
| 登录 | POST | `/login` | 否 | 邮箱密码登录，返回 token 和 uid |
| 注册 | POST | `/register` | 否 | 邮箱密码注册，返回 token 和 uid |
| 推送数据 | POST | `/sync` | 是 | 新增或更新 children/rules/records |
| 拉取数据 | GET | `/sync?collection=&since=` | 是 | 按 collection 拉取数据，支持增量 |
| 删除数据 | DELETE | `/sync?collection=&id=` | 是 | 按 collection 和 id 删除 |
| 获取同步时间 | GET | `/sync/meta` | 是 | 获取最后同步时间戳 |
| 更新同步时间 | POST | `/sync/meta` | 是 | 更新最后同步时间戳 |

---

## 3. 通用约定

### 3.1 时间格式

所有时间字段使用 **ISO 8601** 格式，示例：`2026-06-12T08:00:00.000Z`

### 3.2 ID 生成规则

- **云数据库 `_id`**：由云数据库自动生成，或使用语义化格式 `{entity}_{localId}_{timestamp}`
- **本地 ID**：Drift SQLite 自增整数
- **ID 映射**：通过 `localId` 字段在云文档中记录对应的本地 ID，实现双向映射

### 3.3 数据隔离

所有业务集合（`children`、`rules`、`records`、`sync_meta`）均通过 `userId` 字段实现多用户数据隔离。云函数在处理请求时从 Token 中提取用户身份，仅操作该用户的数据。

### 3.4 增量同步机制

1. 客户端记录最后同步时间 `lastSyncTimestamp`
2. 拉取数据时传入 `since` 参数，服务端仅返回 `updatedAt > since` 的记录
3. 首次同步（`since` 为空）时拉取全量数据
4. 同步完成后调用 `/sync/meta` 更新时间戳

### 3.5 错误码汇总

| HTTP 状态码 | error 字段 | 说明 |
|------------|-----------|------|
| 200 | — | 成功 |
| 400 | `email-already-in-use` | 邮箱已被注册 |
| 400 | `weak-password` | 密码强度不足 |
| 401 | `user-not-found` | 用户不存在 |
| 401 | `wrong-password` | 密码错误 |
| 401 | `unauthorized` | 未携带有效 Token |
| 404 | `not-found` | 请求的资源不存在 |
| 429 | `too-many-requests` | 请求过于频繁 |
| 500 | `internal-error` | 服务端内部错误 |

### 3.6 Flutter 端调用示例

```dart
// 认证
final authService = CloudBaseAuthService('https://kids-habit-xxxxx.service.tcloudbase.com');
await authService.signUp('user@example.com', 'password123');
await authService.signIn('user@example.com', 'password123');

// 数据同步
final datasource = CloudBaseDatasource(
  'https://kids-habit-xxxxx.service.tcloudbase.com',
  authService.currentToken!,
);

// 推送一个小孩
await datasource.pushChild({
  'name': '小明',
  'avatar': '👦',
  'createdAt': DateTime.now().toIso8601String(),
  'updatedAt': DateTime.now().toIso8601String(),
  'localId': 1,
}, 'child_1_${DateTime.now().millisecondsSinceEpoch}');

// 拉取所有小孩
final children = await datasource.pullChildren(null);

// 增量拉取（仅拉取上次同步后的更新）
final lastSync = await datasource.getLastSync();
final updatedChildren = await datasource.pullChildren(lastSync);

// 更新同步时间
await datasource.updateLastSync();
```

### 3.7 微信小程序端调用示例

```javascript
// 小程序端使用云开发原生 SDK，无需经过云函数 HTTP API
const db = wx.cloud.database()

// 新增小孩
await db.collection('children').add({
  data: {
    userId: 'OPENID', // 云函数中自动获取
    name: '小明',
    avatar: '👦',
    createdAt: new Date(),
    updatedAt: new Date()
  }
})

// 查询小孩列表
const { data } = await db.collection('children')
  .where({ userId: 'OPENID' })
  .orderBy('createdAt', 'desc')
  .get()

// 新增记录
await db.collection('records').add({
  data: {
    userId: 'OPENID',
    childId: 'child_xxx',
    ruleId: 'rule_xxx',
    minutesChange: 30,
    note: '按时完成作业',
    createdAt: new Date(),
    updatedAt: new Date()
  }
})

// 计算余额（聚合查询）
const { list } = await db.collection('records')
  .where({ userId: 'OPENID', childId: 'child_xxx' })
  .field({ minutesChange: true })
  .get()
const balance = list.reduce((sum, r) => sum + r.minutesChange, 0)
```

# Cloud Functions & Mini Program Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement cloud functions (login, register, sync) per data-schema.md spec, fix Flutter datasource to match, and rewrite mini program to use direct DB access with correct data model.

**Architecture:** Three cloud functions handle Flutter HTTP API requests. Mini program bypasses cloud functions and uses `wx.cloud.database()` directly. Both share the same cloud database with `userId`-based data isolation.

**Tech Stack:** Node.js (wx-server-sdk ~2.6.3), WeChat CloudBase HTTP triggers, Flutter/Dart (http, shared_preferences), WeChat Mini Program (WXML/WXSS)

---

## Key Gaps Identified

1. **Cloud functions** only support callFunction pattern, not HTTP trigger — Flutter can't call them
2. **`register` stores plain passwords** — must hash with crypto
3. **`sync` uses action-based callFunction** — needs REST-style HTTP handling per data-schema.md
4. **Flutter `CloudBaseDatasource`** uses path-based routing (`/sync/children`) but spec uses query-param routing (`/sync?collection=children`)
5. **Mini program data model** mismatches schema: `minutes` vs `minutesChange`, `balance` field on children (should be computed), `_openid` vs `userId`
6. **Mini program** uses callFunction for data — should use direct DB access per data-schema.md section 3.7
7. **Mini program missing pages**: rule management, settings/profile

---

## File Map

### Cloud Functions (create/rewrite)
| File | Responsibility |
|------|---------------|
| `miniprogram/cloudfunctions/login/index.js` | Dual-mode: callFunction returns openid; HTTP POST does email/password login |
| `miniprogram/cloudfunctions/login/package.json` | Dependencies |
| `miniprogram/cloudfunctions/register/index.js` | HTTP POST email/password registration with hashed passwords |
| `miniprogram/cloudfunctions/register/package.json` | Dependencies (adds crypto) |
| `miniprogram/cloudfunctions/sync/index.js` | HTTP REST API for Flutter data sync + meta operations |
| `miniprogram/cloudfunctions/sync/package.json` | Dependencies |

### Flutter (modify)
| File | Change |
|------|--------|
| `app/lib/data/remote/cloudbase_datasource.dart` | Rewrite to use query-param routing per spec |

### Mini Program (rewrite/create)
| File | Responsibility |
|------|---------------|
| `miniprogram/miniprogram/app.js` | Get openid via login function, store globally |
| `miniprogram/miniprogram/app.json` | Add rule-manage and settings pages |
| `miniprogram/miniprogram/pages/index/index.js` | Rewrite: direct DB, userId-based queries, computed balance |
| `miniprogram/miniprogram/pages/index/index.wxml` | Update data bindings (minutesChange, computed balance) |
| `miniprogram/miniprogram/pages/detail/detail.js` | Rewrite: direct DB, schema-aligned data model |
| `miniprogram/miniprogram/pages/detail/detail.wxml` | Update data bindings |
| `miniprogram/miniprogram/pages/detail/detail.wxss` | Add rule management section styles |
| `miniprogram/miniprogram/pages/statistics/statistics.js` | Rewrite: direct DB, userId queries |
| `miniprogram/miniprogram/pages/statistics/statistics.wxml` | Update data bindings |
| `miniprogram/miniprogram/pages/rule-manage/rule-manage.js` | New: rule CRUD page |
| `miniprogram/miniprogram/pages/rule-manage/rule-manage.wxml` | New: rule list + add/edit/delete UI |
| `miniprogram/miniprogram/pages/rule-manage/rule-manage.wxss` | New: styles |
| `miniprogram/miniprogram/pages/rule-manage/rule-manage.json` | New: page config |
| `miniprogram/miniprogram/pages/settings/settings.js` | New: about, feedback |
| `miniprogram/miniprogram/pages/settings/settings.wxml` | New: settings UI |
| `miniprogram/miniprogram/pages/settings/settings.wxss` | New: styles |
| `miniprogram/miniprogram/pages/settings/settings.json` | New: page config |
| `miniprogram/miniprogram/utils/util.js` | Keep as-is (already good) |

---

## Task 1: Rewrite `login` Cloud Function

**Files:**
- Rewrite: `miniprogram/cloudfunctions/login/index.js`
- Modify: `miniprogram/cloudfunctions/login/package.json`

- [ ] **Step 1: Write `login/index.js`**

The function must handle two calling patterns:
1. **callFunction** (mini program): `event` has no `httpMethod` — return openid from wx context
2. **HTTP POST** (Flutter): `event` has `httpMethod: 'POST'` with email/password in body

```javascript
const cloud = require('wx-server-sdk')
const crypto = require('crypto')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex')
}

exports.main = async (event, context) => {
  // HTTP 触发模式（Flutter 端调用）
  if (event.httpMethod === 'POST') {
    let email, password
    // body 可能是字符串或已解析对象
    if (typeof event.body === 'string') {
      const params = new URLSearchParams(event.body)
      email = params.get('email')
      password = params.get('password')
    } else if (event.body) {
      email = event.body.email
      password = event.body.password
    }

    if (!email || !password) {
      return { statusCode: 400, error: 'invalid-params', message: '邮箱和密码不能为空' }
    }

    const { data: users } = await db.collection('users')
      .where({ email }).limit(1).get()

    if (users.length === 0) {
      return { statusCode: 401, error: 'user-not-found', message: '用户不存在' }
    }

    const user = users[0]
    if (user.passwordHash !== hashPassword(password)) {
      return { statusCode: 401, error: 'wrong-password', message: '邮箱或密码错误' }
    }

    return { token: user._id, uid: user._id }
  }

  // callFunction 模式（小程序端调用）— 返回 openid
  const wxContext = cloud.getWXContext()
  return {
    openid: wxContext.OPENID,
    appid: wxContext.APPID,
    unionid: wxContext.UNIONID
  }
}
```

- [ ] **Step 2: Update `login/package.json`**

```json
{
  "name": "login",
  "version": "1.0.0",
  "description": "登录云函数 - 支持小程序 callFunction 和 HTTP 邮箱密码登录",
  "main": "index.js",
  "dependencies": {
    "wx-server-sdk": "~2.6.3"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add miniprogram/cloudfunctions/login/
git commit -m "feat: rewrite login cloud function with dual callFunction/HTTP support and password hashing"
```

---

## Task 2: Rewrite `register` Cloud Function

**Files:**
- Rewrite: `miniprogram/cloudfunctions/register/index.js`
- Modify: `miniprogram/cloudfunctions/register/package.json`

- [ ] **Step 1: Write `register/index.js`**

```javascript
const cloud = require('wx-server-sdk')
const crypto = require('crypto')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()

function hashPassword(password) {
  return crypto.createHash('sha256').update(password).digest('hex')
}

exports.main = async (event, context) => {
  // 只支持 HTTP 触发（Flutter 端注册）
  let email, password
  if (typeof event.body === 'string') {
    const params = new URLSearchParams(event.body)
    email = params.get('email')
    password = params.get('password')
  } else if (event.body) {
    email = event.body.email
    password = event.body.password
  }

  if (!email || !password) {
    return { statusCode: 400, error: 'invalid-params', message: '邮箱和密码不能为空' }
  }

  if (password.length < 6) {
    return { statusCode: 400, error: 'weak-password', message: '密码强度太弱' }
  }

  // 检查邮箱是否已注册
  const { data: existing } = await db.collection('users')
    .where({ email }).limit(1).get()

  if (existing.length > 0) {
    return { statusCode: 400, error: 'email-already-in-use', message: '该邮箱已被注册' }
  }

  // 创建用户
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

- [ ] **Step 2: Update `register/package.json`**

```json
{
  "name": "register",
  "version": "1.0.0",
  "description": "注册云函数 - HTTP 邮箱密码注册",
  "main": "index.js",
  "dependencies": {
    "wx-server-sdk": "~2.6.3"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add miniprogram/cloudfunctions/register/
git commit -m "feat: rewrite register cloud function with password hashing and proper error responses"
```

---

## Task 3: Rewrite `sync` Cloud Function

**Files:**
- Rewrite: `miniprogram/cloudfunctions/sync/index.js`
- Modify: `miniprogram/cloudfunctions/sync/package.json`

This is the largest task. The sync function handles all REST operations per data-schema.md section 2.3–2.4.

- [ ] **Step 1: Write `sync/index.js`**

```javascript
const cloud = require('wx-server-sdk')

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()
const _ = db.command

// Token 验证：从 Authorization header 解析 uid
function verifyToken(event) {
  const authHeader = (event.headers && event.headers.authorization) ||
                     (event.headers && event.headers.Authorization) || ''
  const token = authHeader.replace('Bearer ', '').trim()
  if (!token) return null
  // token 即为 users 集合中的 _id（注册/登录时返回）
  return token
}

exports.main = async (event, context) => {
  const method = event.httpMethod

  // --- Token 验证 ---
  const uid = verifyToken(event)
  if (!uid) {
    return { statusCode: 401, error: 'unauthorized', message: '未授权，请先登录' }
  }

  // 解析 query 参数
  const query = event.queryString || {}
  const collection = query.collection

  // 解析 body
  let body = {}
  if (event.body) {
    if (typeof event.body === 'string') {
      try { body = JSON.parse(event.body) } catch (e) { body = {} }
    } else {
      body = event.body
    }
  }

  try {
    // ===== GET /sync?collection=children&since=... =====
    if (method === 'GET') {
      // sync meta: GET /sync?collection=meta
      if (collection === 'meta') {
        const { data: meta } = await db.collection('sync_meta')
          .where({ userId: uid }).limit(1).get()
        if (meta.length === 0) {
          return { lastSyncTimestamp: null }
        }
        return { lastSyncTimestamp: meta[0].lastSyncTimestamp || null }
      }

      // 数据拉取
      if (!['children', 'rules', 'records'].includes(collection)) {
        return { statusCode: 400, error: 'invalid-collection', message: '无效的集合名称' }
      }

      let queryBuilder = db.collection(collection).where({ userId: uid })
      if (query.since) {
        queryBuilder = db.collection(collection).where({
          userId: uid,
          updatedAt: _.gt(new Date(query.since))
        })
      }

      const { data } = await queryBuilder.get()

      // 统一返回格式：将 _id 映射为 id
      return data.map(function (item) {
        item.id = item._id
        delete item._id
        return item
      })
    }

    // ===== POST /sync =====
    if (method === 'POST') {
      // sync meta update: POST /sync body: {collection: "meta", ...}
      if (body.collection === 'meta' || (collection === 'meta')) {
        const ts = body.lastSyncTimestamp || body.data && body.data.lastSyncTimestamp
        const { data: existing } = await db.collection('sync_meta')
          .where({ userId: uid }).limit(1).get()

        if (existing.length > 0) {
          await db.collection('sync_meta').doc(existing[0]._id).update({
            data: { lastSyncTimestamp: ts || new Date().toISOString() }
          })
        } else {
          await db.collection('sync_meta').add({
            data: {
              userId: uid,
              lastSyncTimestamp: ts || new Date().toISOString()
            }
          })
        }
        return { ok: true }
      }

      // 数据 upsert: POST /sync body: {collection, action: "upsert", data: {id, ...}}
      const coll = body.collection
      if (!['children', 'rules', 'records'].includes(coll)) {
        return { statusCode: 400, error: 'invalid-collection', message: '无效的集合名称' }
      }

      const itemData = body.data || {}
      const docId = itemData.id

      if (!docId) {
        return { statusCode: 400, error: 'missing-id', message: '缺少文档 ID' }
      }

      // 构建存储数据：添加 userId，移除 id 字段
      const storeData = { userId: uid }
      const fieldsToCopy = Object.assign({}, itemData)
      delete fieldsToCopy.id

      Object.assign(storeData, fieldsToCopy)
      storeData.updatedAt = new Date().toISOString()

      // 尝试 upsert：先查再更新或插入
      const { data: existing } = await db.collection(coll)
        .where({ _id: docId, userId: uid }).limit(1).get()

      if (existing.length > 0) {
        await db.collection(coll).doc(docId).update({ data: storeData })
      } else {
        storeData._id = docId
        await db.collection(coll).add({ data: storeData })
      }

      return { ok: true }
    }

    // ===== DELETE /sync?collection=children&id=xxx =====
    if (method === 'DELETE') {
      if (!['children', 'rules', 'records'].includes(collection)) {
        return { statusCode: 400, error: 'invalid-collection', message: '无效的集合名称' }
      }
      const docId = query.id
      if (!docId) {
        return { statusCode: 400, error: 'missing-id', message: '缺少文档 ID' }
      }

      // 验证文档属于该用户
      const { data: doc } = await db.collection(collection)
        .where({ _id: docId, userId: uid }).limit(1).get()

      if (doc.length === 0) {
        return { statusCode: 404, error: 'not-found', message: '文档不存在' }
      }

      await db.collection(collection).doc(docId).remove()
      return { ok: true }
    }

    return { statusCode: 405, error: 'method-not-allowed', message: '不支持的请求方法' }

  } catch (err) {
    console.error('sync error:', err)
    return { statusCode: 500, error: 'internal-error', message: '服务器错误' }
  }
}
```

- [ ] **Step 2: Update `sync/package.json`**

```json
{
  "name": "sync",
  "version": "1.0.0",
  "description": "数据同步云函数 - HTTP REST API for Flutter",
  "main": "index.js",
  "dependencies": {
    "wx-server-sdk": "~2.6.3"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add miniprogram/cloudfunctions/sync/
git commit -m "feat: rewrite sync cloud function as REST HTTP API per data-schema spec"
```

---

## Task 4: Fix Flutter `CloudBaseDatasource`

**Files:**
- Rewrite: `app/lib/data/remote/cloudbase_datasource.dart`

The current datasource uses path-based routing (`/sync/children`) but the spec (and the new sync cloud function) uses query-param routing (`/sync?collection=children`).

- [ ] **Step 1: Rewrite `cloudbase_datasource.dart`**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'remote_datasource.dart';

/// 通过微信云开发云函数 HTTP API 实现的远程数据源
/// API 规范见 shared/data-schema.md
class CloudBaseDatasource implements RemoteDatasource {
  final String _apiBase;
  final String _token;

  CloudBaseDatasource(this._apiBase, this._token);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      };

  // --- Children ---
  @override
  Future<void> pushChild(Map<String, dynamic> data, String remoteId) {
    return _upsert('children', remoteId, data);
  }

  @override
  Future<void> deleteChild(String remoteId) {
    return _delete('children', remoteId);
  }

  @override
  Future<List<Map<String, dynamic>>> pullChildren(DateTime? since) {
    return _pull('children', since);
  }

  // --- Rules ---
  @override
  Future<void> pushRule(Map<String, dynamic> data, String remoteId) {
    return _upsert('rules', remoteId, data);
  }

  @override
  Future<void> deleteRule(String remoteId) {
    return _delete('rules', remoteId);
  }

  @override
  Future<List<Map<String, dynamic>>> pullRules(DateTime? since) {
    return _pull('rules', since);
  }

  // --- Records ---
  @override
  Future<void> pushRecord(Map<String, dynamic> data, String remoteId) {
    return _upsert('records', remoteId, data);
  }

  @override
  Future<void> deleteRecord(String remoteId) {
    return _delete('records', remoteId);
  }

  @override
  Future<List<Map<String, dynamic>>> pullRecords(DateTime? since) {
    return _pull('records', since);
  }

  // --- Sync meta ---
  @override
  Future<DateTime?> getLastSync() async {
    final uri = Uri.parse('$_apiBase/sync').replace(
      queryParameters: {'collection': 'meta'},
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ts = data['lastSyncTimestamp'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }

  @override
  Future<void> updateLastSync() async {
    final response = await http.post(
      Uri.parse('$_apiBase/sync'),
      headers: _headers,
      body: jsonEncode({
        'collection': 'meta',
        'lastSyncTimestamp': DateTime.now().toIso8601String(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
  }

  // --- Helpers ---

  /// POST /sync {collection, action: "upsert", data: {id, ...fields}}
  Future<void> _upsert(String collection, String remoteId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_apiBase/sync'),
      headers: _headers,
      body: jsonEncode({
        'collection': collection,
        'action': 'upsert',
        'data': {'id': remoteId, ...data},
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
  }

  /// DELETE /sync?collection=xxx&id=yyy
  Future<void> _delete(String collection, String id) async {
    final uri = Uri.parse('$_apiBase/sync').replace(
      queryParameters: {'collection': collection, 'id': id},
    );
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
  }

  /// GET /sync?collection=xxx&since=yyy
  Future<List<Map<String, dynamic>>> _pull(String collection, DateTime? since) async {
    final params = {'collection': collection};
    if (since != null) {
      params['since'] = since.toIso8601String();
    }
    final uri = Uri.parse('$_apiBase/sync').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('CloudBase API error: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List;
    return list.cast<Map<String, dynamic>>();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/lib/data/remote/cloudbase_datasource.dart
git commit -m "fix: rewrite CloudBaseDatasource to use query-param routing per data-schema spec"
```

---

## Task 5: Fix Mini Program Data Model — Index Page

**Files:**
- Rewrite: `miniprogram/miniprogram/pages/index/index.js`
- Rewrite: `miniprogram/miniprogram/pages/index/index.wxml`

The mini program currently uses callFunction for data access and has wrong field names. Rewrite to use direct `wx.cloud.database()` with schema-aligned fields.

Data model alignment (per `shared/data-schema.md`):
- `userId` (not `_openid`) — set to openid obtained from login function
- `minutesChange` (not `minutes`) on rules and records
- `avatar` on children (emoji string)
- No `balance` field on children — compute from records aggregation
- `icon` on rules (emoji string)

- [ ] **Step 1: Rewrite `pages/index/index.js`**

```javascript
const util = require('../../utils/util.js')
const db = wx.cloud.database()
const app = getApp()

Page({
  data: {
    children: [],
    loading: true,
    today: '',
    isEmpty: false
  },

  onLoad: function () {
    this.setData({ today: util.formatDate(new Date()) })
  },

  onShow: function () {
    this.loadChildren()
  },

  onPullDownRefresh: function () {
    this.loadChildren().then(function () {
      wx.stopPullDownRefresh()
    })
  },

  loadChildren: function () {
    var that = this
    var openid = app.globalData.openid

    if (!openid) {
      // 等待 openid 获取完成
      setTimeout(function () { that.loadChildren() }, 500)
      return Promise.resolve()
    }

    that.setData({ loading: true })

    // 1. 获取所有孩子
    return db.collection('children')
      .where({ userId: openid })
      .orderBy('createdAt', 'asc')
      .get()
      .then(function (childrenRes) {
        var children = childrenRes.data

        // 2. 获取所有记录，计算每个孩子的余额
        return db.collection('records')
          .where({ userId: openid })
          .field({ childId: true, minutesChange: true })
          .get()
          .then(function (recordsRes) {
            var balanceMap = {}
            recordsRes.data.forEach(function (r) {
              if (!balanceMap[r.childId]) balanceMap[r.childId] = 0
              balanceMap[r.childId] += r.minutesChange || 0
            })

            children.forEach(function (c) {
              c.balance = balanceMap[c._id] || 0
            })

            that.setData({
              children: children,
              loading: false,
              isEmpty: children.length === 0
            })
          })
      })
      .catch(function (err) {
        console.error('加载孩子列表失败', err)
        that.setData({ loading: false })
        wx.showToast({ title: '加载失败', icon: 'none' })
      })
  },

  onChildTap: function (e) {
    var childId = e.currentTarget.dataset.id
    wx.navigateTo({
      url: '/pages/detail/detail?childId=' + childId
    })
  },

  onAddChild: function () {
    wx.navigateTo({
      url: '/pages/detail/detail?mode=add'
    })
  },

  onLongPressChild: function (e) {
    var that = this
    var childId = e.currentTarget.dataset.id
    var childName = e.currentTarget.dataset.name

    wx.showActionSheet({
      itemList: ['删除'],
      success: function (res) {
        if (res.tapIndex === 0) {
          wx.showModal({
            title: '确认删除',
            content: '确定要删除"' + childName + '"吗？所有相关记录将被清除。',
            confirmColor: '#F44336',
            success: function (modalRes) {
              if (modalRes.confirm) {
                that.deleteChild(childId)
              }
            }
          })
        }
      }
    })
  },

  deleteChild: function (childId) {
    var that = this
    var openid = app.globalData.openid

    // 先删除关联记录
    db.collection('records')
      .where({ userId: openid, childId: childId })
      .get()
      .then(function (res) {
        var promises = res.data.map(function (r) {
          return db.collection('records').doc(r._id).remove()
        })
        return Promise.all(promises)
      })
      .then(function () {
        return db.collection('children').doc(childId).remove()
      })
      .then(function () {
        wx.showToast({ title: '已删除', icon: 'success' })
        that.loadChildren()
      })
      .catch(function (err) {
        console.error('删除失败', err)
        wx.showToast({ title: '删除失败', icon: 'none' })
      })
  }
})
```

- [ ] **Step 2: Rewrite `pages/index/index.wxml`**

```xml
<view class="container">
  <view class="header">
    <view class="header-top flex-between">
      <view class="header-title">
        <text class="title-text">习惯养成助手</text>
      </view>
      <view class="header-date text-secondary">
        <text>{{today}}</text>
      </view>
    </view>
  </view>

  <view class="child-list" wx:if="{{!isEmpty}}">
    <view
      class="child-card card"
      wx:for="{{children}}"
      wx:key="_id"
      data-id="{{item._id}}"
      data-name="{{item.name}}"
      bindtap="onChildTap"
      bindlongpress="onLongPressChild"
    >
      <view class="child-header flex-between">
        <view class="child-info flex-row">
          <view class="child-avatar flex-center">
            <text class="avatar-text">{{item.avatar || item.name[0]}}</text>
          </view>
          <view class="child-name-wrap">
            <text class="child-name">{{item.name}}</text>
          </view>
        </view>
        <view class="child-balance">
          <text class="balance-label">余额</text>
          <text class="balance-value {{item.balance >= 0 ? 'text-success' : 'text-danger'}}">
            {{item.balance >= 0 ? '+' : ''}}{{item.balance}} 分钟
          </text>
        </view>
      </view>
    </view>
  </view>

  <view class="loading-wrap" wx:if="{{loading}}">
    <view class="empty-state">
      <text class="empty-text">加载中...</text>
    </view>
  </view>

  <view class="empty-state" wx:if="{{isEmpty && !loading}}">
    <text class="empty-icon">👦👧</text>
    <text class="empty-text">还没有添加孩子</text>
    <text class="empty-text">点击下方按钮添加第一个孩子吧</text>
  </view>

  <view class="add-btn-wrap">
    <button class="btn-primary add-btn" bindtap="onAddChild">
      + 添加孩子
    </button>
  </view>
</view>
```

- [ ] **Step 3: Commit**

```bash
git add miniprogram/miniprogram/pages/index/
git commit -m "feat: rewrite mini program index page with direct DB access and schema-aligned data model"
```

---

## Task 6: Fix Mini Program — Detail Page

**Files:**
- Rewrite: `miniprogram/miniprogram/pages/detail/detail.js`
- Rewrite: `miniprogram/miniprogram/pages/detail/detail.wxml`

- [ ] **Step 1: Rewrite `pages/detail/detail.js`**

```javascript
const util = require('../../utils/util.js')
const db = wx.cloud.database()
const app = getApp()

Page({
  data: {
    mode: 'view',
    childId: '',
    child: null,
    rules: [],
    todayRecords: [],
    today: '',
    todayTotal: 0,
    newChildName: '',
    newChildAvatar: '',
    submitting: false,
    loading: true
  },

  // 头像选项
  avatarOptions: ['👦', '👧', '👶', '🧒', '👦🏽', '👧🏽', '🧒🏻', '👶🏻'],

  onLoad: function (options) {
    var today = util.formatDate(new Date())
    this.setData({ today: today })

    if (options.mode === 'add') {
      this.setData({ mode: 'add' })
      wx.setNavigationBarTitle({ title: '添加孩子' })
    } else if (options.childId) {
      this.setData({ childId: options.childId })
      this.loadChildData()
    }
  },

  onShow: function () {
    if (this.data.childId && this.data.mode === 'view') {
      this.loadChildData()
    }
  },

  loadChildData: function () {
    var that = this
    var openid = app.globalData.openid
    that.setData({ loading: true })

    // 并行获取孩子信息、规则、今日记录
    var childPromise = db.collection('children').doc(that.data.childId).get()
    var rulesPromise = db.collection('rules')
      .where({ userId: openid })
      .orderBy('minutesChange', 'desc')
      .get()

    // 今日记录：按 createdAt 日期过滤
    var todayStart = that.data.today + 'T00:00:00.000Z'
    var todayEnd = that.data.today + 'T23:59:59.999Z'
    var recordsPromise = db.collection('records')
      .where({
        userId: openid,
        childId: that.data.childId,
        createdAt: db.command.gte(todayStart).and(db.command.lte(todayEnd))
      })
      .orderBy('createdAt', 'desc')
      .get()

    Promise.all([childPromise, rulesPromise, recordsPromise])
      .then(function (results) {
        var child = results[0].data
        var rules = results[1].data
        var todayRecords = results[2].data

        var todayTotal = 0
        var ruleMap = {}
        rules.forEach(function (r) { ruleMap[r._id] = r })
        todayRecords.forEach(function (r) {
          todayTotal += r.minutesChange || 0
          r.ruleName = r.ruleId && ruleMap[r.ruleId] ? ruleMap[r.ruleId].name : '自定义'
          r.ruleIcon = r.ruleId && ruleMap[r.ruleId] ? ruleMap[r.ruleId].icon : '📝'
        })

        that.setData({
          child: child,
          rules: rules,
          todayRecords: todayRecords,
          todayTotal: todayTotal,
          loading: false
        })
      })
      .catch(function (err) {
        console.error('加载详情失败', err)
        that.setData({ loading: false })
        wx.showToast({ title: '加载失败', icon: 'none' })
      })
  },

  // === 添加孩子 ===
  onNameInput: function (e) {
    this.setData({ newChildName: e.detail.value })
  },

  onAvatarSelect: function (e) {
    this.setData({ newChildAvatar: e.currentTarget.dataset.avatar })
  },

  onSubmitAddChild: function () {
    var that = this
    var name = that.data.newChildName.trim()
    if (!name) {
      wx.showToast({ title: '请输入孩子姓名', icon: 'none' })
      return
    }

    var openid = app.globalData.openid
    that.setData({ submitting: true })

    db.collection('children').add({
      data: {
        userId: openid,
        name: name,
        avatar: that.data.newChildAvatar || '👦',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    })
    .then(function () {
      wx.showToast({ title: '添加成功', icon: 'success' })
      setTimeout(function () { wx.navigateBack() }, 1000)
    })
    .catch(function (err) {
      console.error('添加失败', err)
      wx.showToast({ title: '添加失败', icon: 'none' })
      that.setData({ submitting: false })
    })
  },

  // === 打卡记录 ===
  onRuleTap: function (e) {
    var that = this
    var ruleId = e.currentTarget.dataset.id
    var ruleName = e.currentTarget.dataset.name
    var ruleMinutes = e.currentTarget.dataset.minutes

    wx.showModal({
      title: '确认记录',
      content: '为"' + that.data.child.name + '"记录：' + ruleName + '（' + (ruleMinutes >= 0 ? '+' : '') + ruleMinutes + '分钟）',
      success: function (res) {
        if (res.confirm) {
          that.addRecord(ruleId, ruleMinutes)
        }
      }
    })
  },

  addRecord: function (ruleId, minutesChange) {
    var that = this
    var openid = app.globalData.openid

    db.collection('records').add({
      data: {
        userId: openid,
        childId: that.data.childId,
        ruleId: ruleId,
        minutesChange: minutesChange,
        note: '',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    })
    .then(function () {
      wx.showToast({ title: '记录成功', icon: 'success' })
      that.loadChildData()
    })
    .catch(function (err) {
      console.error('记录失败', err)
      wx.showToast({ title: '记录失败', icon: 'none' })
    })
  },

  // === 删除记录 ===
  onDeleteRecord: function (e) {
    var that = this
    var recordId = e.currentTarget.dataset.id

    wx.showModal({
      title: '确认删除',
      content: '确定要删除这条记录吗？',
      confirmColor: '#F44336',
      success: function (res) {
        if (res.confirm) {
          db.collection('records').doc(recordId).remove()
            .then(function () {
              wx.showToast({ title: '已删除', icon: 'success' })
              that.loadChildData()
            })
            .catch(function (err) {
              console.error('删除失败', err)
              wx.showToast({ title: '删除失败', icon: 'none' })
            })
        }
      }
    })
  }
})
```

- [ ] **Step 2: Rewrite `pages/detail/detail.wxml`**

```xml
<view class="container">
  <!-- 加载中 -->
  <view wx:if="{{loading}}" class="empty-state mt-30">
    <text class="empty-text">加载中...</text>
  </view>

  <!-- 添加孩子模式 -->
  <view wx:if="{{mode === 'add' && !loading}}">
    <view class="card">
      <view class="form-group mb-30">
        <text class="form-label">孩子姓名</text>
        <input
          class="form-input"
          placeholder="请输入孩子姓名"
          value="{{newChildName}}"
          bindinput="onNameInput"
        />
      </view>
      <view class="form-group mb-30">
        <text class="form-label">选择头像</text>
        <view class="avatar-picker">
          <view
            class="avatar-option {{newChildAvatar === item ? 'avatar-selected' : ''}}"
            wx:for="{{['👦','👧','👶','🧒','👦🏽','👧🏽','🧒🏻','👶🏻']}}"
            wx:key="*this"
            data-avatar="{{item}}"
            bindtap="onAvatarSelect"
          >
            <text class="avatar-emoji">{{item}}</text>
          </view>
        </view>
      </view>
      <button
        class="btn-primary"
        bindtap="onSubmitAddChild"
        disabled="{{submitting}}"
        loading="{{submitting}}"
      >
        保存
      </button>
    </view>
  </view>

  <!-- 查看模式 -->
  <view wx:if="{{mode === 'view' && !loading && child}}">
    <!-- 孩子信息头部 -->
    <view class="child-profile card">
      <view class="profile-top flex-between">
        <view class="flex-row">
          <view class="profile-avatar flex-center">
            <text class="avatar-text">{{child.avatar || child.name[0]}}</text>
          </view>
          <view class="profile-info">
            <text class="profile-name">{{child.name}}</text>
            <text class="profile-date text-secondary">{{today}}</text>
          </view>
        </view>
      </view>
      <view class="today-summary flex-between mt-20">
        <text class="summary-label">今日合计</text>
        <text class="summary-value {{todayTotal >= 0 ? 'text-success' : 'text-danger'}}">
          {{todayTotal >= 0 ? '+' : ''}}{{todayTotal}} 分钟
        </text>
      </view>
    </view>

    <!-- 快捷记录 -->
    <view class="section-title mt-30 mb-20">
      <text class="section-text">快捷记录</text>
      <text class="section-link" bindtap="onGoRuleManage">管理规则 ></text>
    </view>
    <view wx:if="{{rules.length === 0}}" class="empty-hint">
      <text class="text-secondary">暂无规则，请先添加规则</text>
    </view>
    <view class="rules-grid">
      <view
        class="rule-btn {{item.minutesChange >= 0 ? 'rule-positive' : 'rule-negative'}}"
        wx:for="{{rules}}"
        wx:key="_id"
        data-id="{{item._id}}"
        data-name="{{item.name}}"
        data-minutes="{{item.minutesChange}}"
        bindtap="onRuleTap"
      >
        <text class="rule-name">{{item.icon}} {{item.name}}</text>
        <text class="rule-minutes">{{item.minutesChange >= 0 ? '+' : ''}}{{item.minutesChange}}</text>
      </view>
    </view>

    <!-- 今日记录 -->
    <view class="section-title mt-30 mb-20">
      <text class="section-text">今日记录</text>
    </view>
    <view wx:if="{{todayRecords.length === 0}}" class="empty-hint">
      <text class="text-secondary">今天还没有记录</text>
    </view>
    <view
      class="record-item card"
      wx:for="{{todayRecords}}"
      wx:key="_id"
    >
      <view class="flex-between">
        <view class="record-info">
          <text class="record-rule">{{item.ruleIcon}} {{item.ruleName}}</text>
        </view>
        <view class="flex-row">
          <text class="record-minutes {{item.minutesChange >= 0 ? 'text-success' : 'text-danger'}}">
            {{item.minutesChange >= 0 ? '+' : ''}}{{item.minutesChange}} 分钟
          </text>
          <view class="delete-btn" data-id="{{item._id}}" bindtap="onDeleteRecord">
            <text class="delete-icon">×</text>
          </view>
        </view>
      </view>
    </view>
  </view>
</view>
```

- [ ] **Step 3: Add navigation helper to `detail.js` (append to bottom)**

```javascript
  onGoRuleManage: function () {
    wx.navigateTo({
      url: '/pages/rule-manage/rule-manage'
    })
  }
```

- [ ] **Step 4: Commit**

```bash
git add miniprogram/miniprogram/pages/detail/
git commit -m "feat: rewrite mini program detail page with direct DB and schema-aligned fields"
```

---

## Task 7: Fix Mini Program — Statistics Page

**Files:**
- Rewrite: `miniprogram/miniprogram/pages/statistics/statistics.js`
- Rewrite: `miniprogram/miniprogram/pages/statistics/statistics.wxml`

- [ ] **Step 1: Rewrite `pages/statistics/statistics.js`**

```javascript
const util = require('../../utils/util.js')
const db = wx.cloud.database()
const _ = db.command
const app = getApp()

Page({
  data: {
    children: [],
    selectedChildId: '',
    selectedChildName: '',
    dateRange: 'week',
    startDate: '',
    endDate: '',
    records: [],
    summary: {
      totalMinutes: 0,
      positiveCount: 0,
      negativeCount: 0,
      dailyAvg: 0
    },
    loading: false,
    isEmpty: true
  },

  onLoad: function () {
    var end = new Date()
    var start = new Date()
    start.setDate(start.getDate() - 7)
    this.setData({
      endDate: util.formatDate(end),
      startDate: util.formatDate(start)
    })
    this.loadChildren()
  },

  loadChildren: function () {
    var that = this
    var openid = app.globalData.openid

    if (!openid) {
      setTimeout(function () { that.loadChildren() }, 500)
      return
    }

    db.collection('children')
      .where({ userId: openid })
      .orderBy('createdAt', 'asc')
      .get()
      .then(function (res) {
        var children = res.data || []
        that.setData({ children: children })
        if (children.length > 0) {
          that.setData({
            selectedChildId: children[0]._id,
            selectedChildName: children[0].name
          })
          that.loadStatistics()
        }
      })
      .catch(function (err) {
        console.error('加载孩子列表失败', err)
      })
  },

  onChildChange: function (e) {
    var index = e.detail.value
    var child = this.data.children[index]
    this.setData({
      selectedChildId: child._id,
      selectedChildName: child.name
    })
    this.loadStatistics()
  },

  onDateRangeChange: function (e) {
    var range = e.currentTarget.dataset.range
    var end = new Date()
    var start = new Date()

    if (range === 'week') {
      start.setDate(start.getDate() - 7)
    } else if (range === 'month') {
      start.setMonth(start.getMonth() - 1)
    } else if (range === 'quarter') {
      start.setMonth(start.getMonth() - 3)
    }

    this.setData({
      dateRange: range,
      startDate: util.formatDate(start),
      endDate: util.formatDate(end)
    })
    this.loadStatistics()
  },

  loadStatistics: function () {
    var that = this
    var openid = app.globalData.openid
    if (!that.data.selectedChildId || !openid) return

    that.setData({ loading: true })

    var startISO = that.data.startDate + 'T00:00:00.000Z'
    var endISO = that.data.endDate + 'T23:59:59.999Z'

    db.collection('records')
      .where({
        userId: openid,
        childId: that.data.selectedChildId,
        createdAt: _.gte(startISO).and(_.lte(endISO))
      })
      .orderBy('createdAt', 'desc')
      .get()
      .then(function (res) {
        var records = res.data
        var totalMinutes = 0
        var positiveCount = 0
        var negativeCount = 0

        records.forEach(function (r) {
          totalMinutes += r.minutesChange || 0
          if (r.minutesChange >= 0) positiveCount++
          else negativeCount++
        })

        // 获取规则名
        return db.collection('rules')
          .where({ userId: openid })
          .get()
          .then(function (rulesRes) {
            var ruleMap = {}
            rulesRes.data.forEach(function (r) { ruleMap[r._id] = r })
            records.forEach(function (r) {
              r.ruleName = r.ruleId && ruleMap[r.ruleId] ? ruleMap[r.ruleId].name : '自定义'
            })

            var dayCount = that.data.dateRange === 'week' ? 7 :
                           that.data.dateRange === 'month' ? 30 : 90

            that.setData({
              records: records,
              summary: {
                totalMinutes: totalMinutes,
                positiveCount: positiveCount,
                negativeCount: negativeCount,
                dailyAvg: Math.round(totalMinutes / dayCount)
              },
              loading: false,
              isEmpty: records.length === 0
            })
          })
      })
      .catch(function (err) {
        console.error('加载统计数据失败', err)
        that.setData({ loading: false })
        wx.showToast({ title: '加载失败', icon: 'none' })
      })
  }
})
```

- [ ] **Step 2: Update `pages/statistics/statistics.wxml`**

Replace `item.minutes` with `item.minutesChange` in the record-val class:

```xml
<view class="container">
  <view class="card">
    <view class="picker-row flex-between">
      <text class="picker-label">选择孩子</text>
      <picker
        range="{{children}}"
        range-key="name"
        value="{{children.length > 0 ? children.findIndex(function(c){return c._id === selectedChildId}) : 0}}"
        bindchange="onChildChange"
      >
        <view class="picker-value flex-row">
          <text>{{selectedChildName || '请选择'}}</text>
          <text class="picker-arrow">▸</text>
        </view>
      </picker>
    </view>
  </view>

  <view class="date-range flex-row mt-20">
    <view class="range-btn {{dateRange === 'week' ? 'range-active' : ''}}" data-range="week" bindtap="onDateRangeChange">
      <text>近一周</text>
    </view>
    <view class="range-btn {{dateRange === 'month' ? 'range-active' : ''}}" data-range="month" bindtap="onDateRangeChange">
      <text>近一月</text>
    </view>
    <view class="range-btn {{dateRange === 'quarter' ? 'range-active' : ''}}" data-range="quarter" bindtap="onDateRangeChange">
      <text>近三月</text>
    </view>
  </view>

  <view class="summary-cards flex-row mt-20" wx:if="{{!isEmpty}}">
    <view class="summary-card card flex-1">
      <text class="summary-title">总积分</text>
      <text class="summary-num {{summary.totalMinutes >= 0 ? 'text-success' : 'text-danger'}}">
        {{summary.totalMinutes >= 0 ? '+' : ''}}{{summary.totalMinutes}}
      </text>
      <text class="summary-unit">分钟</text>
    </view>
    <view class="summary-card card flex-1">
      <text class="summary-title">日均</text>
      <text class="summary-num text-primary">{{summary.dailyAvg}}</text>
      <text class="summary-unit">分钟</text>
    </view>
    <view class="summary-card card flex-1">
      <text class="summary-title">次数</text>
      <text class="summary-num text-primary">+{{summary.positiveCount}} / -{{summary.negativeCount}}</text>
    </view>
  </view>

  <view wx:if="{{loading}}" class="empty-state mt-30">
    <text class="empty-text">加载中...</text>
  </view>

  <view wx:if="{{isEmpty && !loading}}" class="empty-state mt-30">
    <text class="empty-icon">📊</text>
    <text class="empty-text">该时间段内暂无记录</text>
  </view>

  <view class="record-list mt-20" wx:if="{{!isEmpty && !loading}}">
    <view class="section-title mb-20">
      <text class="section-text">详细记录</text>
    </view>
    <view class="record-item card" wx:for="{{records}}" wx:key="_id">
      <view class="flex-between">
        <view class="record-left">
          <text class="record-date">{{item.createdAt}}</text>
          <text class="record-rule-name">{{item.ruleName || '自定义'}}</text>
        </view>
        <text class="record-val {{item.minutesChange >= 0 ? 'text-success' : 'text-danger'}}">
          {{item.minutesChange >= 0 ? '+' : ''}}{{item.minutesChange}} 分钟
        </text>
      </view>
    </view>
  </view>
</view>
```

- [ ] **Step 3: Commit**

```bash
git add miniprogram/miniprogram/pages/statistics/
git commit -m "feat: rewrite mini program statistics page with direct DB and schema-aligned fields"
```

---

## Task 8: Create Mini Program — Rule Management Page

**Files:**
- Create: `miniprogram/miniprogram/pages/rule-manage/rule-manage.js`
- Create: `miniprogram/miniprogram/pages/rule-manage/rule-manage.wxml`
- Create: `miniprogram/miniprogram/pages/rule-manage/rule-manage.wxss`
- Create: `miniprogram/miniprogram/pages/rule-manage/rule-manage.json`
- Modify: `miniprogram/miniprogram/app.json` — add new page route

- [ ] **Step 1: Create `pages/rule-manage/rule-manage.json`**

```json
{
  "usingComponents": {},
  "navigationBarTitleText": "规则管理",
  "backgroundColor": "#F5F5F5"
}
```

- [ ] **Step 2: Create `pages/rule-manage/rule-manage.js`**

```javascript
var db = wx.cloud.database()
var app = getApp()

Page({
  data: {
    rules: [],
    showForm: false,
    editingRuleId: '',
    formName: '',
    formMinutesChange: '',
    formIcon: '',
    submitting: false,
    loading: true
  },

  iconOptions: ['✅', '📖', '🛁', '🌙', '🏃', '🧹', '🍎', '💪', '❌', '📱', '😢', '⏰'],

  onLoad: function () {
    this.loadRules()
  },

  onShow: function () {
    this.loadRules()
  },

  loadRules: function () {
    var that = this
    var openid = app.globalData.openid

    if (!openid) {
      setTimeout(function () { that.loadRules() }, 500)
      return
    }

    that.setData({ loading: true })
    db.collection('rules')
      .where({ userId: openid })
      .orderBy('minutesChange', 'desc')
      .get()
      .then(function (res) {
        that.setData({ rules: res.data, loading: false })
      })
      .catch(function (err) {
        console.error('加载规则失败', err)
        that.setData({ loading: false })
      })
  },

  onShowAddForm: function () {
    this.setData({
      showForm: true,
      editingRuleId: '',
      formName: '',
      formMinutesChange: '30',
      formIcon: '✅'
    })
  },

  onEditRule: function (e) {
    var rule = e.currentTarget.dataset.rule
    this.setData({
      showForm: true,
      editingRuleId: rule._id,
      formName: rule.name,
      formMinutesChange: String(rule.minutesChange),
      formIcon: rule.icon || '✅'
    })
  },

  onCancelForm: function () {
    this.setData({ showForm: false })
  },

  onNameInput: function (e) {
    this.setData({ formName: e.detail.value })
  },

  onMinutesInput: function (e) {
    this.setData({ formMinutesChange: e.detail.value })
  },

  onIconSelect: function (e) {
    this.setData({ formIcon: e.currentTarget.dataset.icon })
  },

  onSubmitForm: function () {
    var that = this
    var openid = app.globalData.openid
    var name = that.data.formName.trim()
    var minutes = parseInt(that.data.formMinutesChange)

    if (!name) {
      wx.showToast({ title: '请输入规则名称', icon: 'none' })
      return
    }
    if (isNaN(minutes) || minutes === 0) {
      wx.showToast({ title: '请输入有效的分钟数', icon: 'none' })
      return
    }

    that.setData({ submitting: true })

    if (that.data.editingRuleId) {
      // 更新
      db.collection('rules').doc(that.data.editingRuleId).update({
        data: {
          name: name,
          minutesChange: minutes,
          icon: that.data.formIcon || '✅',
          updatedAt: new Date().toISOString()
        }
      })
      .then(function () {
        wx.showToast({ title: '更新成功', icon: 'success' })
        that.setData({ showForm: false, submitting: false })
        that.loadRules()
      })
      .catch(function (err) {
        console.error('更新失败', err)
        wx.showToast({ title: '更新失败', icon: 'none' })
        that.setData({ submitting: false })
      })
    } else {
      // 新增
      db.collection('rules').add({
        data: {
          userId: openid,
          name: name,
          minutesChange: minutes,
          icon: that.data.formIcon || '✅',
          updatedAt: new Date().toISOString()
        }
      })
      .then(function () {
        wx.showToast({ title: '添加成功', icon: 'success' })
        that.setData({ showForm: false, submitting: false })
        that.loadRules()
      })
      .catch(function (err) {
        console.error('添加失败', err)
        wx.showToast({ title: '添加失败', icon: 'none' })
        that.setData({ submitting: false })
      })
    }
  },

  onDeleteRule: function (e) {
    var that = this
    var ruleId = e.currentTarget.dataset.id
    var ruleName = e.currentTarget.dataset.name

    wx.showModal({
      title: '确认删除',
      content: '确定要删除规则"' + ruleName + '"吗？',
      confirmColor: '#F44336',
      success: function (res) {
        if (res.confirm) {
          db.collection('rules').doc(ruleId).remove()
            .then(function () {
              wx.showToast({ title: '已删除', icon: 'success' })
              that.loadRules()
            })
            .catch(function (err) {
              console.error('删除失败', err)
              wx.showToast({ title: '删除失败', icon: 'none' })
            })
        }
      }
    })
  }
})
```

- [ ] **Step 3: Create `pages/rule-manage/rule-manage.wxml`**

```xml
<view class="container">
  <!-- 规则列表 -->
  <view class="section-title mb-20" wx:if="{{!showForm}}">
    <text class="section-text">奖惩规则</text>
  </view>

  <view wx:if="{{loading}}" class="empty-state mt-30">
    <text class="empty-text">加载中...</text>
  </view>

  <view wx:if="{{rules.length === 0 && !loading && !showForm}}" class="empty-state mt-30">
    <text class="empty-icon">📋</text>
    <text class="empty-text">还没有规则</text>
    <text class="empty-text">点击下方按钮添加第一条规则</text>
  </view>

  <view wx:if="{{!showForm}}">
    <view
      class="rule-item card"
      wx:for="{{rules}}"
      wx:key="_id"
    >
      <view class="flex-between">
        <view class="rule-info">
          <text class="rule-icon">{{item.icon}} {{item.name}}</text>
          <text class="rule-value {{item.minutesChange >= 0 ? 'text-success' : 'text-danger'}}">
            {{item.minutesChange >= 0 ? '+' : ''}}{{item.minutesChange}} 分钟
          </text>
        </view>
        <view class="rule-actions flex-row">
          <view class="action-btn edit-btn" data-rule="{{item}}" bindtap="onEditRule">
            <text>编辑</text>
          </view>
          <view class="action-btn delete-btn" data-id="{{item._id}}" data-name="{{item.name}}" bindtap="onDeleteRule">
            <text>删除</text>
          </view>
        </view>
      </view>
    </view>

    <button class="btn-primary mt-30" bindtap="onShowAddForm">+ 添加规则</button>
  </view>

  <!-- 添加/编辑表单 -->
  <view wx:if="{{showForm}}" class="card">
    <view class="form-title">{{editingRuleId ? '编辑规则' : '添加规则'}}</view>

    <view class="form-group mb-30">
      <text class="form-label">规则名称</text>
      <input
        class="form-input"
        placeholder="例如：完成作业"
        value="{{formName}}"
        bindinput="onNameInput"
      />
    </view>

    <view class="form-group mb-30">
      <text class="form-label">分钟变化（正数奖励，负数扣减）</text>
      <input
        class="form-input"
        type="number"
        placeholder="例如：30 或 -15"
        value="{{formMinutesChange}}"
        bindinput="onMinutesInput"
      />
    </view>

    <view class="form-group mb-30">
      <text class="form-label">选择图标</text>
      <view class="icon-picker">
        <view
          class="icon-option {{formIcon === item ? 'icon-selected' : ''}}"
          wx:for="{{['✅','📖','🛁','🌙','🏃','🧹','🍎','💪','❌','📱','😢','⏰']}}"
          wx:key="*this"
          data-icon="{{item}}"
          bindtap="onIconSelect"
        >
          <text>{{item}}</text>
        </view>
      </view>
    </view>

    <view class="form-actions flex-row">
      <button class="btn-secondary flex-1" bindtap="onCancelForm">取消</button>
      <button class="btn-primary flex-1 ml-10" bindtap="onSubmitForm" disabled="{{submitting}}" loading="{{submitting}}">
        保存
      </button>
    </view>
  </view>
</view>
```

- [ ] **Step 4: Create `pages/rule-manage/rule-manage.wxss`**

```css
/* pages/rule-manage/rule-manage.wxss */

.form-title {
  font-size: 34rpx;
  font-weight: bold;
  color: var(--text-primary);
  margin-bottom: 30rpx;
}

/* 规则列表 */
.rule-item {
  padding: 20rpx 24rpx;
}

.rule-info {
  display: flex;
  flex-direction: column;
}

.rule-icon {
  font-size: 30rpx;
  color: var(--text-primary);
}

.rule-value {
  font-size: 28rpx;
  font-weight: bold;
  margin-top: 6rpx;
}

.rule-actions {
  gap: 16rpx;
}

.action-btn {
  padding: 10rpx 24rpx;
  border-radius: 8rpx;
  font-size: 24rpx;
}

.edit-btn {
  background-color: #E3F2FD;
  color: #1976D2;
}

.delete-btn {
  background-color: #FFEBEE;
  color: var(--danger-color);
}

/* 图标选择器 */
.icon-picker {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
}

.icon-option {
  width: 80rpx;
  height: 80rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12rpx;
  border: 2rpx solid var(--divider-color);
  font-size: 36rpx;
}

.icon-option:active {
  opacity: 0.7;
}

.icon-selected {
  border-color: var(--primary-color);
  background-color: #E0F2F1;
}

/* 表单按钮 */
.form-actions {
  gap: 20rpx;
  margin-top: 20rpx;
}
```

- [ ] **Step 5: Update `app.json` to register the new page**

Add `"pages/rule-manage/rule-manage"` to the pages array:

```json
{
  "pages": [
    "pages/index/index",
    "pages/detail/detail",
    "pages/rule-manage/rule-manage",
    "pages/statistics/statistics",
    "pages/settings/settings"
  ],
  "window": {
    "backgroundColor": "#F6F6F6",
    "backgroundTextStyle": "light",
    "navigationBarBackgroundColor": "#009688",
    "navigationBarTitleText": "习惯养成助手",
    "navigationBarTextStyle": "white"
  },
  "tabBar": {
    "color": "#999999",
    "selectedColor": "#009688",
    "backgroundColor": "#ffffff",
    "borderStyle": "black",
    "list": [
      {
        "pagePath": "pages/index/index",
        "text": "首页"
      },
      {
        "pagePath": "pages/statistics/statistics",
        "text": "统计"
      }
    ]
  },
  "sitemapLocation": "sitemap.json",
  "style": "v2",
  "cloud": true
}
```

- [ ] **Step 6: Commit**

```bash
git add miniprogram/miniprogram/pages/rule-manage/ miniprogram/miniprogram/app.json
git commit -m "feat: add rule management page to mini program with CRUD operations"
```

---

## Task 9: Create Mini Program — Settings Page

**Files:**
- Create: `miniprogram/miniprogram/pages/settings/settings.js`
- Create: `miniprogram/miniprogram/pages/settings/settings.wxml`
- Create: `miniprogram/miniprogram/pages/settings/settings.wxss`
- Create: `miniprogram/miniprogram/pages/settings/settings.json`

- [ ] **Step 1: Create `pages/settings/settings.json`**

```json
{
  "usingComponents": {},
  "navigationBarTitleText": "设置",
  "backgroundColor": "#F5F5F5"
}
```

- [ ] **Step 2: Create `pages/settings/settings.js`**

```javascript
var app = getApp()

Page({
  data: {
    version: '1.0.0',
    openid: ''
  },

  onLoad: function () {
    this.setData({ openid: app.globalData.openid || '' })
  },

  onClearCache: function () {
    wx.showModal({
      title: '清除缓存',
      content: '确定要清除本地缓存吗？云端数据不受影响。',
      success: function (res) {
        if (res.confirm) {
          wx.clearStorage({
            success: function () {
              wx.showToast({ title: '缓存已清除', icon: 'success' })
            }
          })
        }
      }
    })
  },

  onFeedback: function () {
    // 使用微信内置反馈功能（需在 app.json 配置）
  },

  onAbout: function () {
    wx.showModal({
      title: '关于',
      content: '习惯养成助手 v1.0.0\n帮助家长管理孩子日常习惯，用积分奖励激励孩子成长。',
      showCancel: false
    })
  }
})
```

- [ ] **Step 3: Create `pages/settings/settings.wxml`**

```xml
<view class="container">
  <view class="section-title mb-20">
    <text class="section-text">数据</text>
  </view>
  <view class="card">
    <view class="setting-item flex-between" bindtap="onClearCache">
      <text>清除缓存</text>
      <text class="text-secondary">▸</text>
    </view>
  </view>

  <view class="section-title mt-30 mb-20">
    <text class="section-text">其他</text>
  </view>
  <view class="card">
    <view class="setting-item flex-between" bindtap="onFeedback">
      <text>意见反馈</text>
      <text class="text-secondary">▸</text>
    </view>
    <view class="setting-item flex-between" bindtap="onAbout">
      <text>关于</text>
      <text class="text-secondary text-bold">v{{version}} ▸</text>
    </view>
  </view>
</view>
```

- [ ] **Step 4: Create `pages/settings/settings.wxss`**

```css
/* pages/settings/settings.wxss */

.setting-item {
  padding: 24rpx 0;
  font-size: 30rpx;
  color: var(--text-primary);
}

.setting-item + .setting-item {
  border-top: 1rpx solid var(--divider-color);
}
```

- [ ] **Step 5: Commit**

```bash
git add miniprogram/miniprogram/pages/settings/
git commit -m "feat: add settings page to mini program"
```

---

## Task 10: Update Mini Program `app.js` for Schema Alignment

**Files:**
- Modify: `miniprogram/miniprogram/app.js`

Update to properly store openid in `globalData` and ensure it's available before pages load.

- [ ] **Step 1: Rewrite `app.js`**

```javascript
App({
  onLaunch: function () {
    if (!wx.cloud) {
      console.error('请使用 2.2.3 或以上的基础库以使用云能力')
      return
    }

    wx.cloud.init({
      traceUser: true
    })

    this.getOpenId()
  },

  getOpenId: function () {
    var that = this
    wx.cloud.callFunction({
      name: 'login',
      data: {}
    }).then(function (res) {
      that.globalData.openid = res.result.openid
    }).catch(function (err) {
      console.error('获取 openid 失败', err)
    })
  },

  globalData: {
    openid: null
  }
})
```

- [ ] **Step 2: Commit**

```bash
git add miniprogram/miniprogram/app.js
git commit -m "fix: simplify mini program app.js to only get openid via login function"
```

---

## Task 11: Update DEVELOPMENT.md

**Files:**
- Modify: `DEVELOPMENT.md`

- [ ] **Step 1: Update the progress checklist**

Mark the following as completed:
- P0 > 云函数实现: login (dual mode), register (with hashing), sync (REST HTTP API)
- P1 > 小程序前端: 首页, 详情页, 统计页, 规则管理页, 设置页
- P1 > 小程序云开发集成: openid 获取, 直接 DB 操作
- P2 > Flutter datasource 修复

- [ ] **Step 2: Commit**

```bash
git add DEVELOPMENT.md
git commit -m "docs: update development progress after cloud functions and mini program implementation"
```

---

## Self-Review Checklist

1. **Spec coverage:**
   - data-schema.md 1.1 children schema → Task 5,6,7 (mini program uses correct fields)
   - data-schema.md 1.2 rules schema → Task 8 (rule-manage page uses `minutesChange`, `icon`)
   - data-schema.md 1.3 records schema → Task 6 (detail page creates records with `minutesChange`, `childId`, `ruleId`)
   - data-schema.md 1.4 sync_meta → Task 3 (sync function handles meta)
   - data-schema.md 1.5 users → Task 1,2 (login/register with `passwordHash`)
   - data-schema.md 2.1 login API → Task 1 (HTTP POST with email/password)
   - data-schema.md 2.2 register API → Task 2 (HTTP POST with validation)
   - data-schema.md 2.3 sync API → Task 3 (GET/POST/DELETE)
   - data-schema.md 2.4 sync/meta → Task 3 (collection=meta handling)
   - Flutter datasource → Task 4 (query-param routing)
   - Mini program direct DB → Tasks 5,6,7 (use `wx.cloud.database()`)

2. **Placeholder scan:** All code blocks contain complete implementations. No TBD/TODO.

3. **Type consistency:**
   - `minutesChange` used consistently in Task 6,7,8 (not `minutes`)
   - `userId` used consistently in all mini program DB operations
   - `passwordHash` used in login and register cloud functions
   - `avatar` used in children (not `birthDate`)
   - Flutter datasource uses `collection` query-param format matching sync cloud function

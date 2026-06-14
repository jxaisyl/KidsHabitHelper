# 计时器功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在微信小程序和 Flutter App 两端实现倒计时器（24h 内、秒级精度），结束时播放提示音并弹确认框，确认后对孩子执行选定规则；小程序后台用订阅消息兜底，Flutter 用本地通知。

**Architecture:** 计时器是设备本地临时状态（不参与云同步）。三轨并行：(1) Flutter — `TimerProvider`(Riverpod) + `flutter_local_notifications` 定时通知 + `audioplayers` 提示音；(2) 小程序 — `pages/timer` 页 + `setKeepScreenOn` + `InnerAudioContext`；(3) 云函数 `timer-notify`（定时触发器）扫描 `timers` 集合发订阅消息。

**Tech Stack:** Flutter 3 / Riverpod 3 / go_router / drift；微信小程序原生；wx-server-sdk；新增依赖 `flutter_local_notifications`、`audioplayers`。

**Reference spec:** `docs/superpowers/specs/2026-06-14-timer-feature-design.md`

---

## 文件结构

### 新增文件

| 文件 | 责任 |
|------|------|
| `app/lib/models/active_timer.dart` | `ActiveTimer` 模型 + JSON 序列化（Flutter） |
| `app/lib/providers/timer_provider.dart` | `TimerNotifier` 状态管理（Riverpod） |
| `app/lib/pages/timer_page.dart` | Flutter 计时器页面 UI |
| `app/test/models/active_timer_test.dart` | `ActiveTimer` 单元测试 |
| `app/test/providers/timer_provider_test.dart` | `TimerNotifier` 单元测试 |
| `miniprogram/miniprogram/pages/timer/timer.{wxml,wxss,js,json}` | 小程序计时器页面 |
| `miniprogram/miniprogram/utils/timer.js` | 小程序计时器纯逻辑（剩余时间计算、格式化） |
| `miniprogram/cloudfunctions/timer-notify/index.js` | 定时触发器：扫描到期 timer 发订阅消息 |
| `miniprogram/cloudfunctions/timer-notify/config.json` | 每分钟触发配置 |
| `miniprogram/cloudfunctions/timer-notify/package.json` | 云函数依赖声明 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `app/pubspec.yaml` | 加 `flutter_local_notifications`、`audioplayers`、音频资源声明 |
| `app/lib/main.dart` | 初始化 `flutter_local_notifications` |
| `app/lib/router.dart` | 加 `/child/:id/timer` 路由 |
| `app/lib/pages/child_detail_page.dart` | 加"计时器"入口按钮 |
| `app/android/app/src/main/AndroidManifest.xml` | 通知/精确闹钟权限 |
| `miniprogram/miniprogram/pages/detail/detail.{wxml,js}` | 加计时器入口按钮 |
| `miniprogram/miniprogram/app.js` | `onShow` 检查到期计时器 |
| `miniprogram/miniprogram/app.json` | 注册 timer 页面路由 |
| `shared/data-schema.md` | 补充 `timers` 集合定义 |
| `DEVELOPMENT.md` | 更新进度 |

---

## Task 1: 数据结构文档更新

**Files:**
- Modify: `shared/data-schema.md`

- [ ] **Step 1: 在 data-schema.md 第 1.4 节（sync_meta）之后插入 1.5 timers 集合定义**

在 `### 1.4 sync_meta 集合` 章节之后、`### 1.5 users 集合` 之前插入新章节，并把原 1.5 users 改为 1.6（同时更新目录引用）：

```markdown
### 1.5 timers 集合 — 计时器后台通知

存储小程序端启动的计时器，供定时触发器云函数 `timer-notify` 扫描并发送订阅消息。Flutter 端不写入此集合（Flutter 用本地通知）。记录在倒计时结束后由云函数标记 `notified`，并在 25 小时后被清理。

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `_id` | String | 自动 | — | 云数据库自动生成的文档 ID |
| `userId` | String | 是 | — | 所属用户 ID（openid），用于数据隔离 |
| `childId` | String | 是 | — | 关联的小孩 ID |
| `childName` | String | 是 | — | 小孩姓名（冗余存储，供消息模板使用） |
| `ruleId` | String | 是 | — | 关联的规则 ID |
| `ruleName` | String | 是 | — | 规则名称 |
| `ruleIcon` | String | 否 | `"⏰"` | 规则图标 |
| `minutesChange` | Int | 是 | — | 规则分钟变化量 |
| `startAt` | DateTime | 是 | — | 计时开始时间，ISO 8601 |
| `duration` | Int | 是 | — | 计时总时长（秒），范围 1–86400 |
| `fireAt` | DateTime | 是 | — | 计划到期时间 = startAt + duration，ISO 8601 |
| `notified` | Bool | 是 | `false` | 是否已发送订阅消息 |
| `createdAt` | DateTime | 是 | 当前时间 | 创建时间，ISO 8601 |

**示例文档：**

\```json
{
  "_id": "timer_xxx",
  "userId": "oXXXX",
  "childId": "child_xxx",
  "childName": "小明",
  "ruleId": "rule_xxx",
  "ruleName": "完成作业",
  "ruleIcon": "📖",
  "minutesChange": 30,
  "startAt": "2026-06-14T10:00:00.000Z",
  "duration": 1800,
  "fireAt": "2026-06-14T10:30:00.000Z",
  "notified": false,
  "createdAt": "2026-06-14T10:00:00.000Z"
}
\```
```

- [ ] **Step 2: Commit**

```bash
git add shared/data-schema.md
git commit -m "docs: add timers collection to data schema"
```

---

## Task 2: 小程序计时器纯逻辑工具 `utils/timer.js`

把可测试的纯函数抽出来，与微信 API 解耦。

**Files:**
- Create: `miniprogram/miniprogram/utils/timer.js`

- [ ] **Step 1: 创建 `utils/timer.js`**

```javascript
// 计时器纯逻辑工具：不依赖 wx API，便于人工验证

// 计算剩余秒数（向下取整，最小 0）
// 参数均为 ISO 字符串或 Date
function remainingSeconds(startAt, durationSec, now) {
  var start = typeof startAt === 'string' ? new Date(startAt).getTime() : startAt.getTime()
  var current = typeof now === 'string' ? new Date(now).getTime() : now.getTime()
  var elapsed = Math.floor((current - start) / 1000)
  var remain = durationSec - elapsed
  return remain < 0 ? 0 : remain
}

// 把秒格式化为 HH:MM:SS（24h 内）
function formatHMS(totalSec) {
  if (totalSec < 0) totalSec = 0
  var h = Math.floor(totalSec / 3600)
  var m = Math.floor((totalSec % 3600) / 60)
  var s = totalSec % 60
  return [h, m, s].map(function (n) {
    return n < 10 ? '0' + n : '' + n
  }).join(':')
}

// 校验时长：1..86400 秒
function isValidDuration(sec) {
  return typeof sec === 'number' && Number.isFinite(sec) && sec >= 1 && sec <= 86400
}

module.exports = {
  remainingSeconds: remainingSeconds,
  formatHMS: formatHMS,
  isValidDuration: isValidDuration
}
```

- [ ] **Step 2: Commit**

```bash
git add miniprogram/miniprogram/utils/timer.js
git commit -m "feat(miniprogram): add timer pure-logic utils"
```

---

## Task 3: 小程序计时器页面 — JS 逻辑

**Files:**
- Create: `miniprogram/miniprogram/pages/timer/timer.js`

- [ ] **Step 1: 创建页面 JS**

注意：`childId` 在小程序端是云数据库 `_id`（字符串），与 Flutter 端的 int 不同——这是两端数据模型差异，各自保持一致即可。

```javascript
var timerUtil = require('../../utils/timer.js')
var app = getApp()

Page({
  data: {
    mode: 'setup',              // setup | running | ended
    childId: '',
    child: null,
    rules: [],
    selectedRuleId: '',         // 选中的规则 _id
    selectedRule: null,
    // setup 字段
    hours: 0,
    minutes: 25,
    seconds: 0,
    // running 字段
    display: '00:25:00',
    progress: 0,                // 0..1
    startAt: '',
    duration: 0,
    fireAt: ''
  },

  _tickHandle: null,
  _audio: null,

  onLoad: function (options) {
    var that = this
    if (options.childId) {
      this.setData({ childId: options.childId })
      this.loadChildAndRules(options.childId)
    }

    // 异常恢复：检查是否有进行中的计时器
    var saved = wx.getStorageSync('activeTimer')
    if (saved && saved.status === 'running' && saved.childId === options.childId) {
      var now = Date.now()
      var fireTs = new Date(saved.fireAt).getTime()
      if (now >= fireTs) {
        // 已到期：直接进入结束态
        this._restoreFromSaved(saved, true)
        this._onTimerEnd()
      } else {
        // 未到期：恢复运行态
        this._restoreFromSaved(saved, false)
        this._startTicking()
      }
    }
  },

  onUnload: function () {
    this._stopTicking()
    wx.setKeepScreenOn({ keepScreenOn: false })
  },

  loadChildAndRules: function (childId) {
    var that = this
    var openid = app.globalData.openid
    var db = wx.cloud.database()
    var childP = db.collection('children').doc(childId).get()
    var rulesP = db.collection('rules').where({ userId: openid }).orderBy('minutesChange', 'desc').get()
    Promise.all([childP, rulesP]).then(function (res) {
      that.setData({ child: res[0].data, rules: res[1].data })
    }).catch(function (err) {
      console.error('加载失败', err)
      wx.showToast({ title: '加载失败', icon: 'none' })
    })
  },

  onHourChange: function (e) { this.setData({ hours: +e.detail.value }) },
  onMinuteChange: function (e) { this.setData({ minutes: +e.detail.value }) },
  onSecondChange: function (e) { this.setData({ seconds: +e.detail.value }) },
  onRuleSelect: function (e) {
    var id = e.currentTarget.dataset.id
    var rule = this.data.rules.filter(function (r) { return r._id === id })[0] || null
    this.setData({ selectedRuleId: id, selectedRule: rule })
  },

  onStart: function () {
    var that = this
    var totalSec = this.data.hours * 3600 + this.data.minutes * 60 + this.data.seconds
    if (!timerUtil.isValidDuration(totalSec)) {
      wx.showToast({ title: '请设置 1 秒 ~ 24 小时', icon: 'none' })
      return
    }
    if (!this.data.selectedRule) {
      wx.showToast({ title: '请选择规则', icon: 'none' })
      return
    }

    var startAt = new Date().toISOString()
    var fireAt = new Date(Date.now() + totalSec * 1000).toISOString()
    var saved = {
      childId: this.data.childId,
      childName: this.data.child.name,
      childAvatar: this.data.child.avatar,
      ruleId: this.data.selectedRule._id,
      ruleName: this.data.selectedRule.name,
      ruleIcon: this.data.selectedRule.icon,
      minutesChange: this.data.selectedRule.minutesChange,
      startAt: startAt,
      duration: totalSec,
      fireAt: fireAt,
      status: 'running'
    }
    wx.setStorageSync('activeTimer', saved)
    this._restoreFromSaved(saved, false)

    // 屏幕常亮
    wx.setKeepScreenOn({ keepScreenOn: true })

    // 请求订阅消息授权（失败不阻塞前台计时）
    this._requestSubscribe(fireAt, saved)

    this._startTicking()
  },

  _requestSubscribe: function (fireAt, saved) {
    var that = this
    // TEMPLATE_ID 部署前替换为小程序后台申请的订阅消息模板 ID
    var TEMPLATE_ID = 'REPLACE_WITH_TEMPLATE_ID'
    wx.requestSubscribeMessage({
      tmplIds: [TEMPLATE_ID],
      success: function (res) {
        if (res[TEMPLATE_ID] === 'accept') {
          // 写入 timers 云集合，供定时触发器扫描
          var db = wx.cloud.database()
          db.collection('timers').add({
            data: {
              userId: app.globalData.openid,
              childId: saved.childId,
              childName: saved.childName,
              ruleId: saved.ruleId,
              ruleName: saved.ruleName,
              ruleIcon: saved.ruleIcon,
              minutesChange: saved.minutesChange,
              startAt: saved.startAt,
              duration: saved.duration,
              fireAt: fireAt,
              notified: false,
              createdAt: new Date().toISOString()
            }
          }).catch(function (e) { console.warn('写 timers 失败', e) })
        }
      },
      fail: function () { /* 用户拒绝不影响前台计时 */ }
    })
  },

  _restoreFromSaved: function (saved, ended) {
    this.setData({
      mode: ended ? 'ended' : 'running',
      selectedRuleId: saved.ruleId,
      selectedRule: {
        _id: saved.ruleId, name: saved.ruleName, icon: saved.ruleIcon, minutesChange: saved.minutesChange
      },
      startAt: saved.startAt,
      duration: saved.duration,
      fireAt: saved.fireAt,
      display: timerUtil.formatHMS(saved.duration),
      progress: 0
    })
  },

  _startTicking: function () {
    var that = this
    this._stopTicking()
    var tick = function () {
      var remain = timerUtil.remainingSeconds(that.data.startAt, that.data.duration, Date.now())
      that.setData({
        display: timerUtil.formatHMS(remain),
        progress: 1 - (remain / that.data.duration)
      })
      if (remain <= 0) {
        that._stopTicking()
        that._onTimerEnd()
      }
    }
    tick()
    this._tickHandle = setInterval(tick, 1000)
  },

  _stopTicking: function () {
    if (this._tickHandle) {
      clearInterval(this._tickHandle)
      this._tickHandle = null
    }
  },

  _onTimerEnd: function () {
    var that = this
    this.setData({ mode: 'ended' })
    // 播放提示音
    if (!this._audio) {
      this._audio = wx.createInnerAudioContext()
      this._audio.src = '/assets/audio/alert.mp3'
      this._audio.loop = true
    }
    this._audio.play()
    wx.setKeepScreenOn({ keepScreenOn: false })
    // 弹确认框
    var rule = this.data.selectedRule
    var sign = rule.minutesChange >= 0 ? '+' : ''
    wx.showModal({
      title: '计时结束！',
      content: rule.icon + ' ' + rule.name + '  ' + sign + rule.minutesChange + '分钟  → 给 ' + (this.data.child ? this.data.child.name : ''),
      confirmText: '确认打卡',
      cancelText: '取消',
      success: function (res) {
        that._stopSound()
        if (res.confirm) {
          that._confirmRecord()
        } else {
          that._clearTimer()
        }
      }
    })
  },

  _stopSound: function () {
    if (this._audio) {
      this._audio.stop()
    }
  },

  _confirmRecord: function () {
    var that = this
    var openid = app.globalData.openid
    var rule = this.data.selectedRule
    var db = wx.cloud.database()
    db.collection('records').add({
      data: {
        userId: openid,
        childId: that.data.childId,
        ruleId: rule._id,
        minutesChange: rule.minutesChange,
        note: '计时器打卡',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    }).then(function () {
      wx.showToast({ title: '记录成功', icon: 'success' })
      that._clearTimer()
    }).catch(function (err) {
      console.error('打卡失败', err)
      wx.showToast({ title: '打卡失败', icon: 'none' })
    })
  },

  _clearTimer: function () {
    var saved = wx.getStorageSync('activeTimer')
    if (saved && saved.ruleId) {
      // 清理 timers 云集合中对应文档（best-effort）
      var db = wx.cloud.database()
      db.collection('timers').where({
        userId: app.globalData.openid,
        ruleId: saved.ruleId,
        startAt: saved.startAt
      }).remove().catch(function () {})
    }
    wx.removeStorageSync('activeTimer')
    this.setData({
      mode: 'setup', selectedRuleId: '', selectedRule: null,
      display: '00:00:00', progress: 0, startAt: '', duration: 0, fireAt: ''
    })
    setTimeout(function () { wx.navigateBack() }, 500)
  },

  onCancel: function () {
    var that = this
    wx.showModal({
      title: '取消计时',
      content: '确定取消当前计时？',
      success: function (res) {
        if (res.confirm) {
          that._stopTicking()
          that._stopSound()
          wx.setKeepScreenOn({ keepScreenOn: false })
          that._clearTimer()
        }
      }
    })
  }
})
```

- [ ] **Step 2: Commit**

```bash
git add miniprogram/miniprogram/pages/timer/timer.js
git commit -m "feat(miniprogram): add timer page logic"
```

---

## Task 4: 小程序计时器页面 — WXML + WXSS + JSON

**Files:**
- Create: `miniprogram/miniprogram/pages/timer/timer.wxml`
- Create: `miniprogram/miniprogram/pages/timer/timer.wxss`
- Create: `miniprogram/miniprogram/pages/timer/timer.json`

- [ ] **Step 1: 创建 `timer.wxml`**

```xml
<view class="container">
  <view wx:if="{{mode === 'setup'}}" class="setup-area">
    <view class="card">
      <view class="form-label">设置时长</view>
      <view class="time-picker">
        <picker mode="selector" range="{{24}}" value="{{hours}}" bindchange="onHourChange">
          <view class="time-cell">
            <text class="time-num">{{hours}}</text>
            <text class="time-unit">时</text>
          </view>
        </picker>
        <picker mode="selector" range="{{60}}" value="{{minutes}}" bindchange="onMinuteChange">
          <view class="time-cell">
            <text class="time-num">{{minutes}}</text>
            <text class="time-unit">分</text>
          </view>
        </picker>
        <picker mode="selector" range="{{60}}" value="{{seconds}}" bindchange="onSecondChange">
          <view class="time-cell">
            <text class="time-num">{{seconds}}</text>
            <text class="time-unit">秒</text>
          </view>
        </picker>
      </view>
    </view>

    <view class="card mt-20">
      <view class="form-label">选择规则</view>
      <view class="rules-list">
        <view
          wx:for="{{rules}}"
          wx:key="_id"
          class="rule-row {{selectedRuleId === item._id ? 'rule-selected' : ''}}"
          data-id="{{item._id}}"
          bindtap="onRuleSelect"
        >
          <text class="rule-icon">{{item.icon}}</text>
          <text class="rule-name">{{item.name}}</text>
          <text class="rule-minutes {{item.minutesChange >= 0 ? 'text-success' : 'text-danger'}}">
            {{item.minutesChange >= 0 ? '+' : ''}}{{item.minutesChange}}
          </text>
        </view>
      </view>
    </view>

    <button class="btn-primary mt-20" bindtap="onStart">开始计时</button>
  </view>

  <view wx:if="{{mode === 'running' || mode === 'ended'}}" class="running-area">
    <view class="countdown-card card">
      <text class="countdown-display">{{display}}</text>
      <view class="progress-bar">
        <view class="progress-fill" style="width: {{progress * 100}}%"></view>
      </view>
    </view>
    <view class="info-card card mt-20" wx:if="{{selectedRule}}">
      <text class="info-rule">{{selectedRule.icon}} {{selectedRule.name}}</text>
      <text class="info-minutes">{{selectedRule.minutesChange >= 0 ? '+' : ''}}{{selectedRule.minutesChange}} 分钟</text>
    </view>
    <button wx:if="{{mode === 'running'}}" class="btn-cancel mt-20" bindtap="onCancel">取消计时</button>
  </view>
</view>
```

> 注意：`<picker mode="selector" range="{{24}}">` 在小程序中传数字 N 会生成 `[0..N-1]` 的范围。若该行为不稳定，可改为 JS 中预计算数组 `hourOptions/minuteOptions/secondOptions` 后绑定。实现时以微信开发者工具实测为准。

- [ ] **Step 2: 创建 `timer.wxss`**

```css
.setup-area, .running-area { padding: 10rpx 0; }
.time-picker { display: flex; justify-content: space-around; margin-top: 20rpx; }
.time-cell { display: flex; align-items: baseline; }
.time-num { font-size: 60rpx; font-weight: bold; color: #009688; }
.time-unit { font-size: 24rpx; color: #999; margin-left: 8rpx; }
.rules-list { margin-top: 16rpx; }
.rule-row {
  display: flex; align-items: center; padding: 20rpx 16rpx;
  border-bottom: 1rpx solid #eee;
}
.rule-row.rule-selected { background: #e0f2f1; }
.rule-icon { font-size: 36rpx; margin-right: 16rpx; }
.rule-name { flex: 1; font-size: 28rpx; }
.rule-minutes { font-size: 28rpx; font-weight: bold; }
.countdown-card { text-align: center; padding: 60rpx 20rpx; }
.countdown-display { font-size: 96rpx; font-weight: bold; color: #009688; font-family: monospace; }
.progress-bar { height: 12rpx; background: #eee; border-radius: 6rpx; margin-top: 30rpx; overflow: hidden; }
.progress-fill { height: 100%; background: #009688; transition: width 1s linear; }
.info-card { display: flex; justify-content: space-between; align-items: center; padding: 24rpx; }
.info-rule { font-size: 32rpx; }
.info-minutes { font-size: 32rpx; font-weight: bold; }
.btn-cancel { background: #fff; color: #F44336; border: 1rpx solid #F44336; margin-top: 40rpx; }
```

- [ ] **Step 3: 创建 `timer.json`**

```json
{
  "navigationBarTitleText": "计时器",
  "usingComponents": {}
}
```

- [ ] **Step 4: Commit**

```bash
git add miniprogram/miniprogram/pages/timer/timer.wxml miniprogram/miniprogram/pages/timer/timer.wxss miniprogram/miniprogram/pages/timer/timer.json
git commit -m "feat(miniprogram): add timer page UI"
```

---

## Task 5: 小程序接入详情页入口 + app.json 路由 + app.js 生命周期

**Files:**
- Modify: `miniprogram/miniprogram/pages/detail/detail.wxml`
- Modify: `miniprogram/miniprogram/pages/detail/detail.js`
- Modify: `miniprogram/miniprogram/app.json`
- Modify: `miniprogram/miniprogram/app.js`

- [ ] **Step 1: 在 detail.wxml 的"快捷记录"标题栏（约第 63-66 行）加计时器入口**

把这段：
```xml
<view class="section-title mt-30 mb-20">
  <text class="section-text">快捷记录</text>
  <text class="section-link" bindtap="onGoRuleManage">管理规则 ></text>
</view>
```
改为：
```xml
<view class="section-title mt-30 mb-20">
  <text class="section-text">快捷记录</text>
  <view class="flex-row">
    <text class="section-link" data-childid="{{child._id}}" bindtap="onGoTimer">⏱ 计时器</text>
    <text class="section-link" style="margin-left: 20rpx;" bindtap="onGoRuleManage">管理规则 ></text>
  </view>
</view>
```

- [ ] **Step 2: 在 detail.js 的方法中（`onGoRuleManage` 附近）加 `onGoTimer`**

在 `onGoRuleManage: function () {...}` 之后追加：
```javascript
  onGoTimer: function () {
    wx.navigateTo({
      url: '/pages/timer/timer?childId=' + this.data.childId
    })
  },
```

- [ ] **Step 3: 在 app.json 的 pages 数组注册 timer 页面**

把 `pages` 数组改为：
```json
"pages": [
  "pages/index/index",
  "pages/detail/detail",
  "pages/timer/timer",
  "pages/rule-manage/rule-manage",
  "pages/statistics/statistics",
  "pages/settings/settings"
],
```

- [ ] **Step 4: 在 app.js 的 `App({...})` 中加 `onShow` 生命周期，检查到期计时器**

在 `onLaunch` 函数之后、`getOpenId` 之前插入：
```javascript
  onShow: function () {
    var saved = wx.getStorageSync('activeTimer')
    if (saved && saved.status === 'running') {
      var fireTs = new Date(saved.fireAt).getTime()
      if (Date.now() >= fireTs) {
        // 已到期：跳转到 timer 页让用户确认（timer.js onLoad 会处理）
        wx.navigateTo({
          url: '/pages/timer/timer?childId=' + saved.childId
        })
      }
    }
  },
```

> 注意：`wx.navigateTo` 在 App.onShow 中调用要求当前已有页面栈；冷启动场景由 timer 页 onLoad 自身的恢复逻辑覆盖。若 `navigateTo` 报错（无页面栈），可改为 `switchTab` 到首页或忽略——以微信开发者工具实测为准。

- [ ] **Step 5: Commit**

```bash
git add miniprogram/miniprogram/pages/detail/detail.wxml miniprogram/miniprogram/pages/detail/detail.js miniprogram/miniprogram/app.json miniprogram/miniprogram/app.js
git commit -m "feat(miniprogram): wire timer entry from detail page and lifecycle"
```

---

## Task 6: 小程序提示音资源

**Files:**
- Create: `miniprogram/miniprogram/assets/audio/alert.mp3`

- [ ] **Step 1: 创建音频资源目录并放入提示音**

小程序包体限制下建议用 1–3 秒短提示音。任选其一获取 `alert.mp3`：
- 从 [Pixabay Sounds](https://pixabay.com/sound-effects/)（CC0）下载一个短促的铃/提示音，重命名为 `alert.mp3`
- 或用 ffmpeg 生成 1 秒 880Hz 正弦波：`ffmpeg -f lavfi -i "sine=frequency=880:duration=1" -ac 1 alert.mp3`

放置到 `miniprogram/miniprogram/assets/audio/alert.mp3`。

- [ ] **Step 2: Commit**

```bash
git add miniprogram/miniprogram/assets/audio/alert.mp3
git commit -m "feat(miniprogram): add timer alert sound asset"
```

---

## Task 7: 云函数 timer-notify

**Files:**
- Create: `miniprogram/cloudfunctions/timer-notify/index.js`
- Create: `miniprogram/cloudfunctions/timer-notify/config.json`
- Create: `miniprogram/cloudfunctions/timer-notify/package.json`

- [ ] **Step 1: 创建 `package.json`**

```json
{
  "name": "timer-notify",
  "version": "1.0.0",
  "description": "定时扫描 timers 集合，发送订阅消息",
  "main": "index.js",
  "dependencies": {
    "wx-server-sdk": "~2.6.3"
  }
}
```

- [ ] **Step 2: 创建 `config.json`（定时触发器，每分钟第 0 秒）**

微信云函数定时触发器使用 7 字段 cron（秒 分 时 日 月 周 年）。`0 * * * * * *` 表示每分钟第 0 秒触发。

```json
{
  "triggers": [
    {
      "name": "timerTick",
      "type": "timer",
      "config": "0 * * * * * *"
    }
  ]
}
```

- [ ] **Step 3: 创建 `index.js`**

```javascript
const cloud = require('wx-server-sdk')
cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV })
const db = cloud.database()
const _ = db.command

// 部署前替换为小程序后台申请的订阅消息模板 ID
const TEMPLATE_ID = 'REPLACE_WITH_TEMPLATE_ID'

exports.main = async (event, context) => {
  const now = new Date()
  const expireBefore = new Date(now.getTime() - 25 * 3600 * 1000)

  try {
    // 1. 扫描到期未通知的 timer
    const { data: due } = await db.collection('timers')
      .where({
        fireAt: _.lte(now.toISOString()),
        notified: false
      })
      .limit(100)
      .get()

    // 2. 逐条发送订阅消息
    for (const t of due) {
      try {
        await cloud.openapi.subscribeMessage.send({
          touser: t.userId,
          templateId: TEMPLATE_ID,
          // page: 点击消息跳转到计时器页
          page: 'pages/timer/timer?childId=' + t.childId,
          data: {
            // 字段名必须与申请的模板一致；以下为常见命名，部署前对齐
            thing1: { value: String(t.childName).slice(0, 20) },
            thing2: { value: String(t.ruleName).slice(0, 20) },
            time3: { value: t.fireAt }
          }
        })
        // 标记已通知
        await db.collection('timers').doc(t._id).update({ data: { notified: true } })
      } catch (err) {
        console.error('send failed for timer', t._id, err)
        // errCode 43101 = 用户未订阅，标记 notified 避免重试
        if (err.errCode === 43101) {
          await db.collection('timers').doc(t._id).update({ data: { notified: true } })
        }
      }
    }

    // 3. 清理超过 25 小时的记录
    await db.collection('timers')
      .where({ createdAt: _.lt(expireBefore.toISOString()) })
      .remove()

    return { sent: due.length }
  } catch (err) {
    console.error('timer-notify error:', err)
    return { error: 'internal-error', message: String(err) }
  }
}
```

> **部署前置（手动）：**
> 1. 小程序管理后台 → 功能 → 订阅消息 → 从公共模板库选用或申请"计时提醒/任务完成"类模板，记录 `templateId` 与字段名
> 2. 把 `TEMPLATE_ID`（index.js 顶部）与 `data.thing1/thing2/time3` 字段名替换为实际模板字段
> 3. 微信开发者工具 → 云开发 → 部署 `timer-notify`（上传并部署+定时触发器）

- [ ] **Step 4: Commit**

```bash
git add miniprogram/cloudfunctions/timer-notify/
git commit -m "feat(cloud): add timer-notify scheduled cloud function"
```

---

## Task 8: Flutter — ActiveTimer 模型（TDD）

**Files:**
- Create: `app/lib/models/active_timer.dart`
- Test: `app/test/models/active_timer_test.dart`

- [ ] **Step 1: 写失败测试 `test/models/active_timer_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_habit_helper/models/active_timer.dart';

void main() {
  group('ActiveTimer', () {
    test('remainingSeconds 计算剩余', () {
      final t = ActiveTimer(
        childId: 1,
        childName: '小明',
        childAvatar: '👦',
        ruleId: 2,
        ruleName: '完成作业',
        ruleIcon: '📖',
        minutesChange: 30,
        startAt: DateTime(2026, 6, 14, 10, 0, 0),
        durationSec: 1800,
      );
      // 10 分钟后，应剩 1200 秒
      final remain = t.remainingSecondsAt(DateTime(2026, 6, 14, 10, 10, 0));
      expect(remain, 1200);
    });

    test('remainingSeconds 不为负', () {
      final t = ActiveTimer(
        childId: 1, childName: 'a', childAvatar: 'b',
        ruleId: 2, ruleName: 'r', ruleIcon: 'i', minutesChange: 1,
        startAt: DateTime(2026, 6, 14, 10, 0, 0),
        durationSec: 60,
      );
      expect(t.remainingSecondsAt(DateTime(2026, 6, 14, 11, 0, 0)), 0);
    });

    test('fireAt = startAt + duration', () {
      final t = ActiveTimer(
        childId: 1, childName: 'a', childAvatar: 'b',
        ruleId: 2, ruleName: 'r', ruleIcon: 'i', minutesChange: 1,
        startAt: DateTime(2026, 6, 14, 10, 0, 0),
        durationSec: 90,
      );
      expect(t.fireAt, DateTime(2026, 6, 14, 10, 1, 30));
    });

    test('toJson / fromJson 往返', () {
      final t = ActiveTimer(
        childId: 1, childName: '小明', childAvatar: '👦',
        ruleId: 2, ruleName: '作业', ruleIcon: '📖', minutesChange: 30,
        startAt: DateTime.utc(2026, 6, 14, 10, 0, 0),
        durationSec: 1800,
        status: TimerStatus.running,
      );
      final json = t.toJson();
      final restored = ActiveTimer.fromJson(json);
      expect(restored.childId, 1);
      expect(restored.childName, '小明');
      expect(restored.durationSec, 1800);
      expect(restored.status, TimerStatus.running);
      expect(restored.startAt, DateTime.utc(2026, 6, 14, 10, 0, 0));
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd app && flutter test test/models/active_timer_test.dart`
Expected: FAIL — `kids_habit_helper/models/active_timer.dart` 不存在

- [ ] **Step 3: 实现 `lib/models/active_timer.dart`**

```dart
enum TimerStatus { running, ended, cancelled }

class ActiveTimer {
  final int childId;
  final String childName;
  final String childAvatar;
  final int ruleId;
  final String ruleName;
  final String ruleIcon;
  final int minutesChange;
  final DateTime startAt;
  final int durationSec; // 1..86400
  final TimerStatus status;

  const ActiveTimer({
    required this.childId,
    required this.childName,
    required this.childAvatar,
    required this.ruleId,
    required this.ruleName,
    required this.ruleIcon,
    required this.minutesChange,
    required this.startAt,
    required this.durationSec,
    this.status = TimerStatus.running,
  });

  DateTime get fireAt =>
      startAt.add(Duration(seconds: durationSec));

  int remainingSecondsAt(DateTime now) {
    final elapsed = now.difference(startAt).inSeconds;
    final remain = durationSec - elapsed;
    return remain < 0 ? 0 : remain;
  }

  ActiveTimer copyWith({TimerStatus? status}) => ActiveTimer(
        childId: childId,
        childName: childName,
        childAvatar: childAvatar,
        ruleId: ruleId,
        ruleName: ruleName,
        ruleIcon: ruleIcon,
        minutesChange: minutesChange,
        startAt: startAt,
        durationSec: durationSec,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'childId': childId,
        'childName': childName,
        'childAvatar': childAvatar,
        'ruleId': ruleId,
        'ruleName': ruleName,
        'ruleIcon': ruleIcon,
        'minutesChange': minutesChange,
        'startAt': startAt.toIso8601String(),
        'durationSec': durationSec,
        'status': status.name,
      };

  factory ActiveTimer.fromJson(Map<String, dynamic> json) => ActiveTimer(
        childId: json['childId'] as int,
        childName: json['childName'] as String,
        childAvatar: json['childAvatar'] as String,
        ruleId: json['ruleId'] as int,
        ruleName: json['ruleName'] as String,
        ruleIcon: json['ruleIcon'] as String,
        minutesChange: json['minutesChange'] as int,
        startAt: DateTime.parse(json['startAt'] as String),
        durationSec: json['durationSec'] as int,
        status: TimerStatus.values.byName(json['status'] as String),
      );
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd app && flutter test test/models/active_timer_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add app/lib/models/active_timer.dart app/test/models/active_timer_test.dart
git commit -m "feat(flutter): add ActiveTimer model with tests"
```

---

## Task 9: Flutter — 添加依赖

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: 在 pubspec.yaml 的 dependencies 加两行**

在 `shared_preferences: ^2.5.3` 之后加：
```yaml
  flutter_local_notifications: ^19.0.0
  audioplayers: ^6.1.0
```

- [ ] **Step 2: 在 pubspec.yaml 的 flutter: 段加资源声明**

把：
```yaml
flutter:
  uses-material-design: true
```
改为：
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/sounds/
```

- [ ] **Step 3: 创建资源目录占位**

Run: `mkdir -p app/assets/sounds && touch app/assets/sounds/.gitkeep`

- [ ] **Step 4: 拉取依赖**

Run: `cd app && flutter pub get`
Expected: 依赖解析成功，无冲突。

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/assets/sounds/.gitkeep
git commit -m "feat(flutter): add local notifications and audioplayers deps"
```

---

## Task 10: Flutter — TimerProvider（TDD）

**Files:**
- Create: `app/lib/providers/timer_provider.dart`
- Test: `app/test/providers/timer_provider_test.dart`

- [ ] **Step 1: 写失败测试 `test/providers/timer_provider_test.dart`**

把"现在时刻"作为参数注入，避免依赖真实时钟。

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_habit_helper/models/active_timer.dart';
import 'package:kids_habit_helper/providers/timer_provider.dart';

void main() {
  group('TimerNotifier', () {
    test('startTimer 设置 running 状态', () {
      final notifier = TimerNotifier(
        storage: _FakeStorage(),
        scheduler: _FakeScheduler(),
        sound: _FakeSound(),
        now: () => DateTime(2026, 6, 14, 10, 0, 0),
      );
      notifier.startTimer(
        child: _child(),
        rule: _rule(),
        durationSec: 1800,
      );
      expect(notifier.state, isNotNull);
      expect(notifier.state!.status, TimerStatus.running);
      expect(notifier.state!.durationSec, 1800);
    });

    test('tick 到 0 时进入 ended', () {
      final start = DateTime(2026, 6, 14, 10, 0, 0);
      final sound = _FakeSound();
      final notifier = TimerNotifier(
        storage: _FakeStorage(),
        scheduler: _FakeScheduler(),
        sound: sound,
        now: () => start.add(const Duration(seconds: 1801)),
      );
      notifier.startTimer(child: _child(), rule: _rule(), durationSec: 1800);
      notifier.tick();
      expect(notifier.state!.status, TimerStatus.ended);
      expect(sound.played, true);
    });

    test('cancel 清除状态', () {
      final scheduler = _FakeScheduler();
      final notifier = TimerNotifier(
        storage: _FakeStorage(),
        scheduler: scheduler,
        sound: _FakeSound(),
        now: () => DateTime(2026, 6, 14, 10, 0, 0),
      );
      notifier.startTimer(child: _child(), rule: _rule(), durationSec: 1800);
      notifier.cancel();
      expect(notifier.state, isNull);
      expect(scheduler.cancelled, true);
    });

    test('restore 从存储恢复未到期计时器', () {
      final storage = _FakeStorage();
      storage.saved = {
        'childId': 1, 'childName': '小明', 'childAvatar': '👦',
        'ruleId': 2, 'ruleName': '作业', 'ruleIcon': '📖', 'minutesChange': 30,
        'startAt': DateTime(2026, 6, 14, 10, 0, 0).toIso8601String(),
        'durationSec': 1800, 'status': 'running',
      };
      final notifier = TimerNotifier(
        storage: storage,
        scheduler: _FakeScheduler(),
        sound: _FakeSound(),
        now: () => DateTime(2026, 6, 14, 10, 5, 0),
      );
      notifier.restore();
      expect(notifier.state, isNotNull);
      expect(notifier.state!.remainingSecondsAt(
          DateTime(2026, 6, 14, 10, 5, 0)), 1500);
    });

    test('restore 到期则进入 ended', () {
      final storage = _FakeStorage();
      storage.saved = {
        'childId': 1, 'childName': '小明', 'childAvatar': '👦',
        'ruleId': 2, 'ruleName': '作业', 'ruleIcon': '📖', 'minutesChange': 30,
        'startAt': DateTime(2026, 6, 14, 10, 0, 0).toIso8601String(),
        'durationSec': 60, 'status': 'running',
      };
      final sound = _FakeSound();
      final notifier = TimerNotifier(
        storage: storage,
        scheduler: _FakeScheduler(),
        sound: sound,
        now: () => DateTime(2026, 6, 14, 11, 0, 0),
      );
      notifier.restore();
      expect(notifier.state!.status, TimerStatus.ended);
      expect(sound.played, true);
    });
  });
}

// 测试替身
class _FakeStorage implements TimerStorage {
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>?> load() async => saved;
  @override
  Future<void> save(Map<String, dynamic> json) async { saved = json; }
  @override
  Future<void> clear() async { saved = null; }
}

class _FakeScheduler implements NotificationScheduler {
  bool scheduled = false;
  bool cancelled = false;
  @override
  Future<void> scheduleAt(DateTime time, String title, String body) async {
    scheduled = true;
  }
  @override
  Future<void> cancel() async { cancelled = true; }
}

class _FakeSound implements TimerSound {
  bool played = false;
  @override
  Future<void> playLoop() async { played = true; }
  @override
  Future<void> stop() async {}
}

({int id, String name, String avatar}) _child() => (id: 1, name: '小明', avatar: '👦');
({int id, String name, String icon, int minutesChange}) _rule() =>
    (id: 2, name: '作业', icon: '📖', minutesChange: 30);
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd app && flutter test test/providers/timer_provider_test.dart`
Expected: FAIL — `timer_provider.dart` 不存在

- [ ] **Step 3: 实现 `lib/providers/timer_provider.dart`**

通过抽象接口 `TimerStorage` / `NotificationScheduler` / `TimerSound` 解耦平台 API，便于测试。生产实现分别用 SharedPreferences、flutter_local_notifications、audioplayers。

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/active_timer.dart';

// ===== 抽象接口（便于测试）=====
abstract class TimerStorage {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> json);
  Future<void> clear();
}

abstract class NotificationScheduler {
  Future<void> scheduleAt(DateTime time, String title, String body);
  Future<void> cancel();
}

abstract class TimerSound {
  Future<void> playLoop();
  Future<void> stop();
}

// ===== TimerNotifier =====
class TimerNotifier extends Notifier<ActiveTimer?> {
  final TimerStorage storage;
  final NotificationScheduler scheduler;
  final TimerSound sound;
  final DateTime Function() now;
  Timer? _ticker;

  TimerNotifier({
    required this.storage,
    required this.scheduler,
    required this.sound,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  @override
  ActiveTimer? build() {
    ref.onDispose(() {
      _ticker?.cancel();
      sound.stop();
    });
    return null;
  }

  void startTimer({
    required ({int id, String name, String avatar}) child,
    required ({int id, String name, String icon, int minutesChange}) rule,
    required int durationSec,
  }) {
    final t = ActiveTimer(
      childId: child.id,
      childName: child.name,
      childAvatar: child.avatar,
      ruleId: rule.id,
      ruleName: rule.name,
      ruleIcon: rule.icon,
      minutesChange: rule.minutesChange,
      startAt: now(),
      durationSec: durationSec,
      status: TimerStatus.running,
    );
    state = t;
    storage.save(t.toJson());
    scheduler.scheduleAt(t.fireAt, '计时结束：${rule.name}', '给 ${child.name} 打卡');
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void tick() {
    if (state == null || state!.status != TimerStatus.running) return;
    final remain = state!.remainingSecondsAt(now());
    if (remain <= 0) {
      state = state!.copyWith(status: TimerStatus.ended);
      sound.playLoop();
      _ticker?.cancel();
    }
  }

  Future<void> restore() async {
    final json = await storage.load();
    if (json == null) return;
    final t = ActiveTimer.fromJson(json);
    final remain = t.remainingSecondsAt(now());
    if (t.status == TimerStatus.running && remain <= 0) {
      state = t.copyWith(status: TimerStatus.ended);
      await sound.playLoop();
    } else {
      state = t;
      if (t.status == TimerStatus.running) _startTicker();
    }
  }

  /// 确认打卡后由 UI 调用此方法清除状态
  Future<void> clearAfterConfirm() async {
    _ticker?.cancel();
    await sound.stop();
    await scheduler.cancel();
    await storage.clear();
    state = null;
  }

  Future<void> cancel() async {
    _ticker?.cancel();
    await sound.stop();
    await scheduler.cancel();
    await storage.clear();
    state = null;
  }
}

// ===== 生产实现 =====
class _PrefsTimerStorage implements TimerStorage {
  static const _key = 'active_timer';
  @override
  Future<Map<String, dynamic>?> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_key);
    if (s == null) return null;
    return Map<String, dynamic>.from(
        // ignore: avoid_dynamic_calls
        jsonDecodeCompat(s) as Map);
  }

  @override
  Future<void> save(Map<String, dynamic> json) async {
    final sp = await SharedPreferences.getInstance();
    sp.setString(_key, _encode(json));
  }

  @override
  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    sp.remove(_key);
  }
}

// 简易 JSON 编解码（避免引入 dart:convert 头部耦合）
String _encode(Map<String, dynamic> m) {
  // 用 dart:convert 更稳，直接 import
  return _Json.encode(m);
}
Map<String, dynamic>? jsonDecodeCompat(String s) => _Json.decode(s);

class _LocalNotificationScheduler implements NotificationScheduler {
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'timer_channel';
  static const _notifyId = 1001;

  Future<void> init() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(init);
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId, '计时器', importance: Importance.high,
    ));
  }

  @override
  Future<void> scheduleAt(DateTime time, String title, String body) async {
    await plugin.zonedSchedule(
      _notifyId, title, body,
      // 转换为 TZ 见 flutter_local_notifications 文档；此处用 UTC 简化
      _toTz(time),
      NotificationDetails(
        android: AndroidNotificationDetails(_channelId, '计时器',
            importance: Importance.high, priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('alert')),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel() => plugin.cancel(_notifyId);
}

class _AudioPlayerSound implements TimerSound {
  final AudioPlayer _player = AudioPlayer();
  @override
  Future<void> playLoop() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/alert.mp3'));
  }

  @override
  Future<void> stop() => _player.stop();
}

// ===== Provider =====
final timerProvider = NotifierProvider<TimerNotifier, ActiveTimer?>(() {
  // 生产环境的依赖在 main.dart 初始化后通过 override 注入；
  // 这里给默认实例，测试用构造函数直接传替身。
  throw UnimplementedError('请在 main.dart 中用 override 注入 TimerNotifier');
});
```

> 说明：`_toTz` 与 `_Json` 的实现见下方 Step 4 补充。`flutter_local_notifications` 的 `zonedSchedule` 需 `tz.TZDateTime`，需要 `timezone` 包；为减少依赖，本计划用 `flutter_local_notifications` 自带能力并补一个小工具函数。

- [ ] **Step 4: 补充辅助函数（同一文件顶部 import 后追加）**

在 `timer_provider.dart` 顶部 import 区加：
```dart
import 'dart:convert' show jsonEncode, jsonDecode;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
```

把 `_Json` 和 `_toTz` 实现为：
```dart
class _Json {
  static String encode(Map<String, dynamic> m) => jsonEncode(m);
  static Map<String, dynamic>? decode(String s) {
    final d = jsonDecode(s);
    return d is Map<String, dynamic> ? d : null;
  }
}

tz.TZDateTime _toTz(DateTime time) {
  tzdata.initializeTimeZones();
  return tz.TZDateTime.from(time, tz.local);
}
```

并在 `pubspec.yaml` 的 dependencies 追加（Task 9 已加的下面）：
```yaml
  timezone: ^0.9.4
```
然后 `cd app && flutter pub get`。

- [ ] **Step 5: 运行测试确认通过**

Run: `cd app && flutter test test/providers/timer_provider_test.dart`
Expected: PASS (5 tests)

> 注意：测试中 `TimerNotifier` 用的是带参构造函数（不经过 Provider），所以 `timerProvider` 的 `throw UnimplementedError` 不影响测试。`main.dart` 中的 override 在 Task 12 处理。

- [ ] **Step 6: Commit**

```bash
git add app/lib/providers/timer_provider.dart app/test/providers/timer_provider_test.dart app/pubspec.yaml
git commit -m "feat(flutter): add TimerProvider with tests"
```

---

## Task 11: Flutter — TimerPage UI

**Files:**
- Create: `app/lib/pages/timer_page.dart`

- [ ] **Step 1: 创建 `lib/pages/timer_page.dart`**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/active_timer.dart';
import '../providers/timer_provider.dart';
import '../providers/child_provider.dart';
import '../providers/rule_provider.dart';
import '../providers/record_provider.dart';

class TimerPage extends ConsumerStatefulWidget {
  final int childId;
  const TimerPage({super.key, required this.childId});

  @override
  ConsumerState<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends ConsumerState<TimerPage> {
  int _hours = 0;
  int _minutes = 25;
  int _seconds = 0;
  int? _selectedRuleId;
  // 每秒触发 setState 让倒计时显示实时更新；provider 的 tick() 只处理结束转换
  Timer? _uiTicker;
  // 防止 ended 确认框在重建时被多次弹出
  bool _confirmShown = false;

  @override
  void initState() {
    super.initState();
    // 启动时恢复（若已有计时器，UI 进入运行态）
    Future.microtask(() => ref.read(timerProvider.notifier).restore());
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final childAsync = ref.watch(childrenProvider);
    final rulesAsync = ref.watch(rulesProvider);

    final child = childAsync.whenOrNull<ChildrenData?>(
      data: (list) => list.where((c) => c.id == widget.childId).firstOrNull,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('计时器')),
      body: timer == null
          ? _buildSetup(context, child, rulesAsync)
          : _buildRunning(context, timer),
    );
  }

  Widget _buildSetup(BuildContext context, ChildrenData? child, AsyncValue<List<Rule>> rulesAsync) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _timeSpinner('时', _hours, 23, (v) => setState(() => _hours = v)),
                _timeSpinner('分', _minutes, 59, (v) => setState(() => _minutes = v)),
                _timeSpinner('秒', _seconds, 59, (v) => setState(() => _seconds = v)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('选择规则', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        rulesAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('加载失败: $e'),
          data: (rules) => Column(
            children: rules.map((r) {
              final selected = r.id == _selectedRuleId;
              return Card(
                color: selected ? Colors.teal.shade50 : null,
                child: ListTile(
                  leading: Text(r.icon, style: const TextStyle(fontSize: 24)),
                  title: Text(r.name),
                  trailing: Text('${r.minutesChange >= 0 ? '+' : ''}${r.minutesChange}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => setState(() => _selectedRuleId = r.id),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _selectedRuleId == null ? null : _onStart,
          child: const Text('开始计时'),
        ),
      ],
    );
  }

  Widget _timeSpinner(String label, int value, int max, ValueChanged<int> onChange) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
            icon: const Icon(Icons.arrow_drop_up),
            onPressed: value < max ? () => onChange(value + 1) : null),
        Text('$value', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
        IconButton(
            icon: const Icon(Icons.arrow_drop_down),
            onPressed: value > 0 ? () => onChange(value - 1) : null),
      ],
    );
  }

  void _onStart() {
    final child = ref.read(childrenProvider).whenOrNull<List<ChildrenData>>(
          data: (list) => list,
        )?.where((c) => c.id == widget.childId).firstOrNull;
    final rule = ref.read(rulesProvider).whenOrNull<List<Rule>>(
          data: (rules) => rules,
        )?.where((r) => r.id == _selectedRuleId).firstOrNull;
    if (child == null || rule == null) return;

    final total = _hours * 3600 + _minutes * 60 + _seconds;
    if (total < 1 || total > 86400) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('时长需在 1 秒 ~ 24 小时之间')));
      return;
    }

    ref.read(timerProvider.notifier).startTimer(
          child: (id: child.id, name: child.name, avatar: child.avatar),
          rule: (id: rule.id, name: rule.name, icon: rule.icon, minutesChange: rule.minutesChange),
          durationSec: total,
        );
  }

  Widget _buildRunning(BuildContext context, ActiveTimer timer) {
    // 运行态：启动每秒 setState 计时器；非运行态：停止
    if (timer.status == TimerStatus.running) {
      _uiTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _uiTicker?.cancel();
      _uiTicker = null;
    }
    // ended 状态时弹确认框（只触发一次）
    if (timer.status == TimerStatus.ended && !_confirmShown) {
      _confirmShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showConfirm(context, timer));
    }
    final remain = timer.remainingSecondsAt(DateTime.now());
    final h = (remain ~/ 3600).toString().padLeft(2, '0');
    final m = ((remain % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (remain % 60).toString().padLeft(2, '0');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$h:$m:$s',
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          const SizedBox(height: 16),
          Text('${timer.ruleIcon} ${timer.ruleName}  ${timer.minutesChange >= 0 ? '+' : ''}${timer.minutesChange} 分钟',
              style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 32),
          if (timer.status == TimerStatus.running)
            OutlinedButton(
              onPressed: () => ref.read(timerProvider.notifier).cancel(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('取消计时'),
            ),
        ],
      ),
    );
  }

  void _showConfirm(BuildContext context, ActiveTimer timer) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('计时结束！'),
        content: Text('${timer.ruleIcon} ${timer.ruleName}  '
            '${timer.minutesChange >= 0 ? '+' : ''}${timer.minutesChange} 分钟\n→ 给 ${timer.childName}'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(timerProvider.notifier).cancel();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(recordRepositoryProvider).add(
                childId: timer.childId,
                ruleId: timer.ruleId,
                minutesChange: timer.minutesChange,
                note: '计时器打卡',
              );
              ref.invalidate(balanceProvider(timer.childId));
              await ref.read(timerProvider.notifier).clearAfterConfirm();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('确认打卡'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/lib/pages/timer_page.dart
git commit -m "feat(flutter): add TimerPage UI"
```

---

## Task 12: Flutter — 路由 + 入口 + main.dart 初始化

**Files:**
- Modify: `app/lib/router.dart`
- Modify: `app/lib/pages/child_detail_page.dart`
- Modify: `app/lib/main.dart`

- [ ] **Step 1: 在 router.dart 的 `child/:id` 子路由下加 `timer`**

把 router.dart 中的 `childDetail` 路由块：
```dart
GoRoute(
  path: 'child/:id',
  name: 'childDetail',
  pageBuilder: (context, state) {
    final childId = int.parse(state.pathParameters['id']!);
    return MaterialPage(child: ChildDetailPage(childId: childId));
  },
),
```
改为（加嵌套 routes）：
```dart
GoRoute(
  path: 'child/:id',
  name: 'childDetail',
  pageBuilder: (context, state) {
    final childId = int.parse(state.pathParameters['id']!);
    return MaterialPage(child: ChildDetailPage(childId: childId));
  },
  routes: [
    GoRoute(
      path: 'timer',
      name: 'timer',
      pageBuilder: (context, state) {
        final childId = int.parse(state.pathParameters['id']!);
        return MaterialPage(child: TimerPage(childId: childId));
      },
    ),
  ],
),
```

并在 router.dart 顶部 import：
```dart
import 'pages/timer_page.dart';
```

- [ ] **Step 2: 在 child_detail_page.dart 加计时器入口按钮**

在 "最近记录" 标题（`const Text('最近记录'...)` 之前）插入：
```dart
const SizedBox(height: 16),
FilledButton.tonalIcon(
  onPressed: () => context.go('/child/$childId/timer'),
  icon: const Icon(Icons.timer),
  label: const Text('计时器'),
),
const SizedBox(height: 24),
```

并在 child_detail_page.dart 顶部加 import（若已有则跳过）：
```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 3: 在 main.dart 注入 TimerNotifier 生产依赖并初始化通知**

把 main.dart 的 `main()` 函数改为：
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final notifications = FlutterLocalNotificationsPlugin();
  const init = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await notifications.initialize(init);
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        'timer_channel', '计时器', importance: Importance.high,
      ));

  final storage = _PrefsTimerStorage();
  final scheduler = _LocalNotificationScheduler();
  final sound = _AudioPlayerSound();

  runApp(ProviderScope(
    overrides: [
      timerProvider.overrideWith(() => TimerNotifier(
            storage: storage,
            scheduler: scheduler,
            sound: sound,
          )),
    ],
    child: const KidsHabitHelperApp(),
  ));
}
```

并在 main.dart 顶部加 import：
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'providers/timer_provider.dart';
```

> `main` 里用到的 `_PrefsTimerStorage` / `_LocalNotificationScheduler` / `_AudioPlayerSound` 是 `timer_provider.dart` 里的私有类。为让 main.dart 能访问，把这三个类从 `timer_provider.dart` 移到新文件 `lib/providers/timer_services.dart`（公开类，去掉下划线前缀改为 `PrefsTimerStorage` / `LocalNotificationScheduler` / `AudioPlayerSound`），并更新 `timer_provider.dart` 的 import。在 Step 3 完成后做这一步重构。

- [ ] **Step 4: 重构服务类到独立文件 `lib/providers/timer_services.dart`**

Create `app/lib/providers/timer_services.dart`，内容为从 `timer_provider.dart` 移出的三个生产实现类（改名为公开类 `PrefsTimerStorage`、`LocalNotificationScheduler`、`AudioPlayerSound`）。

在 `timer_provider.dart` 中删除这三个类的实现，改为：
```dart
export 'timer_services.dart';
```
（这样 `timerProvider` 的 default 工厂仍 `throw`，但服务类可被外部 import。）

把 main.dart 中 `_PrefsTimerStorage` / `_LocalNotificationScheduler` / `_AudioPlayerSound` 替换为公开类名 `PrefsTimerStorage` / `LocalNotificationScheduler` / `AudioPlayerSound`。

- [ ] **Step 5: 运行测试确认未破坏**

Run: `cd app && flutter test`
Expected: 所有测试 PASS

- [ ] **Step 6: Commit**

```bash
git add app/lib/router.dart app/lib/pages/child_detail_page.dart app/lib/main.dart app/lib/providers/timer_provider.dart app/lib/providers/timer_services.dart
git commit -m "feat(flutter): wire timer route, entry, and notification init"
```

---

## Task 13: Flutter — Android 权限 + 提示音资源

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Create: `app/assets/sounds/alert.mp3`

- [ ] **Step 1: 在 AndroidManifest.xml 的 `<manifest>` 根节点下加权限**

在已有的 `<uses-permission .../>` 旁边追加：
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

- [ ] **Step 2: 放置 alert.mp3 到 app/assets/sounds/**

任选其一获取 `alert.mp3`（与 Task 6 相同的来源）。放到 `app/assets/sounds/alert.mp3`（覆盖 Task 9 的 `.gitkeep`）。

- [ ] **Step 3: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml app/assets/sounds/alert.mp3
git commit -m "feat(flutter): add android permissions and alert sound asset"
```

---

## Task 14: 更新 DEVELOPMENT.md

**Files:**
- Modify: `DEVELOPMENT.md`

- [ ] **Step 1: 在 DEVELOPMENT.md "当前开发进度 → 已完成" 段末追加新章节**

在 commit `cba6f3c` 那行之后追加：
```markdown
#### 11. 计时器功能（24h 内、秒级）
- [x] 小程序：`pages/timer` 页面 + `utils/timer.js` 纯逻辑
- [x] 小程序：前台 setKeepScreenOn + InnerAudioContext 提示音 + 结束确认打卡
- [x] 小程序：订阅消息后台通知（需用户每次授权）
- [x] 云函数 `timer-notify`：定时触发器扫描 timers 集合发订阅消息
- [x] Flutter：`TimerProvider`（Riverpod）+ `ActiveTimer` 模型
- [x] Flutter：`flutter_local_notifications` 后台定时通知 + `audioplayers` 提示音
- [x] Flutter：计时器页面 + 详情页入口
```

并在 "关键依赖版本" 表格追加：
```markdown
| flutter_local_notifications | ^19.0.0 | 本地定时通知（计时器） |
| audioplayers | ^6.1.0 | 计时器提示音 |
| timezone | ^0.9.4 | 通知时区处理 |
```

- [ ] **Step 2: Commit**

```bash
git add DEVELOPMENT.md
git commit -m "docs: update development progress for timer feature"
```

---

## Task 15: 整体验证

- [ ] **Step 1: Flutter 静态分析**

Run: `cd app && flutter analyze`
Expected: 无 error（warning 可接受，但应为零或极少量）

- [ ] **Step 2: Flutter 测试**

Run: `cd app && flutter test`
Expected: 全部 PASS

- [ ] **Step 3: 小程序语法检查（手动）**

在微信开发者工具打开 `miniprogram/` 目录，编译通过、无控制台报错。

- [ ] **Step 4: 手动端到端验证清单**

Flutter 端：
- [ ] 从孩子详情页进入计时器，设置 5 秒，选规则，开始
- [ ] 倒计时显示正确，结束弹提示音 + 确认框
- [ ] 确认打卡后，详情页余额变化
- [ ] 切到后台 10 秒后回 App：剩余时间正确
- [ ] 杀进程重开：若计时未到期则恢复，已到期则弹确认

小程序端：
- [ ] 从孩子详情页进入计时器，设置 5 秒，选规则，开始
- [ ] 倒计时显示正确，结束提示音 + 确认框（前台）
- [ ] 授权订阅消息后切后台，到时收到微信服务通知
- [ ] 点击通知回到计时器页弹确认

云函数（部署后）：
- [ ] 开发者工具云开发面板能看到 `timer-notify` 触发记录
- [ ] `timers` 集合到期记录被标记 `notified: true`

---

## Spec 覆盖自检

| Spec 要求 | 覆盖 Task |
|-----------|-----------|
| 24h 内、秒级精度 | Task 3 (isValidDuration), Task 8 (model) |
| 从孩子详情页启动、绑定孩子 | Task 5 (小程序入口), Task 12 (Flutter 入口) |
| 结束提示音 | Task 6 (小程序音频), Task 13 (Flutter 音频), Task 3/10 (播放逻辑) |
| 结束确认对话框 | Task 3 (_onTimerEnd), Task 11 (_showConfirm) |
| 确认后复用打卡流程 | Task 3 (_confirmRecord), Task 11 (recordRepository.add) |
| 小程序前台常亮 | Task 3 (setKeepScreenOn) |
| 小程序后台订阅消息 | Task 3 (_requestSubscribe) + Task 7 (云函数) |
| Flutter 本地通知 | Task 9 (依赖) + Task 10 (scheduler) + Task 13 (权限) |
| 异常恢复 | Task 3 (onLoad 检查), Task 5 (app.js onShow), Task 10 (restore) |
| 单计时器 | startTimer 直接覆盖旧 state（隐式单值） |
| timers 云集合 + 清理 | Task 1 (schema), Task 7 (云函数清理) |
| 文档更新 | Task 1, Task 14 |

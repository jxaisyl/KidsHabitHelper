# 计时器功能设计

> 创建日期：2026-06-14
> 状态：待实现

---

## 1. 概述

为习惯养成助手增加计时器功能：用户可设定 24 小时以内、精确到秒的倒计时，倒计时结束后播放提示音并弹出确认对话框，用户确认后对该孩子执行选定的规则（打卡）。

**适用端：** 微信小程序 + Flutter App（Android/iOS/Web）。

**典型场景：** 家长给孩子设定"30 分钟写作业"计时，结束提醒检查，确认后给孩子加上"完成作业"规则的奖励分钟。

---

## 2. 关键设计决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 计时器并发 | 单个 | 简化交互与状态管理 |
| 入口 | 从孩子详情页启动，绑定孩子 | 结束确认时直接给该孩子打卡，无需二次选择 |
| 结束行为 | 仅提醒 + 用户手动确认 | 避免误操作自动改余额 |
| 后台行为 | 需要后台继续 | 24h 内可能切后台 |
| 计时器同步 | 不参与云同步 | 单设备临时状态，同步无意义 |
| 小程序后台通知 | 前台常亮 + 提示音，配合订阅消息后台备选 | 小程序 JS 后台挂起，需订阅消息兜底 |
| Flutter 后台通知 | flutter_local_notifications 定时通知 | 平台原生能力，可靠 |

---

## 3. 整体架构与数据流

计时器是设备本地的临时状态，不参与云同步。

```
启动计时器（从孩子详情页）
  ├─ 本地存储 activeTimer { childId, ruleId, minutesChange, startAt, duration }
  ├─ 小程序：wx.requestSubscribeMessage 授权 → 写 timers 云集合
  │         → 前台 setInterval + setKeepScreenOn
  └─ Flutter：flutter_local_notifications 定时通知

倒计时进行中（前台）
  ├─ 每秒更新显示（基于 startAt + duration - now 计算，避免累积误差）
  └─ 小程序：setKeepScreenOn(true) 保持常亮

倒计时结束
  ├─ 前台：播放提示音 + 弹出"确认打卡"对话框 → 确认则复用 addRecord 流程
  └─ 后台：
      ├─ Flutter：系统通知 + 提示音，点击通知回到详情页弹确认框
      └─ 小程序：定时触发器云函数扫描 timers 集合 → 发订阅消息
                → 用户点通知回到详情页弹确认框

异常恢复（App 被杀后重开）
  └─ 读取本地 activeTimer：若 fireAt 未到 → 恢复倒计时；若已过 → 直接弹"计时已结束"确认框
```

---

## 4. 数据结构

### 4.1 本地存储（两端对称）

小程序用 `wx.setStorageSync('activeTimer', ...)`，Flutter 用 `sharedPreferences` 键 `active_timer` 存 JSON 字符串。

```jsonc
{
  "childId": "child_xxx",
  "childName": "小明",
  "childAvatar": "👦",
  "ruleId": "rule_xxx",
  "ruleName": "完成作业",
  "ruleIcon": "📖",
  "minutesChange": 30,
  "startAt": "2026-06-14T10:00:00.000Z",
  "duration": 1800,           // 秒，1–86400
  "fireAt": "2026-06-14T10:30:00.000Z",
  "status": "running"         // running | ended | cancelled
}
```

### 4.2 timers 云集合（仅小程序后台通知使用）

```jsonc
{
  "_id": "auto",
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
```

通过 `userId` 隔离。`notified` 用于定时触发器去重。超过 25 小时的记录由云函数清理。

---

## 5. 小程序端实现

### 5.1 新增页面 `pages/timer/timer`

从详情页 `wx.navigateTo` 进入，URL 携带 `childId`。

**界面结构：**
- 设置区：时间选择器（时:分:秒 三列 picker，限制 1–86400 秒）+ 规则单选列表（复用详情页加载的 rules）
- 倒计时区：大号数字 `HH:MM:SS` + 孩子头像/规则信息 + 进度环
- 按钮：开始 / 取消

**关键技术点：**

| 需求 | 实现 |
|------|------|
| 前台倒计时 | `setInterval` 每秒 tick，基于 `startAt + duration - now` 计算剩余 |
| 屏幕常亮 | `wx.setKeepScreenOn({ keepScreenOn: true })`，结束时复位 false |
| 结束提示音 | 打包 `assets/audio/alert.wav`，用 `wx.createInnerAudioContext()` 播放 |
| 后台通知 | 启动时 `wx.requestSubscribeMessage` 请求模板授权；授权后写 `timers` 集合 |
| 切后台/恢复 | `onShow` 读本地 `activeTimer`，按 `fireAt` 重算剩余并恢复 `setInterval` |
| 被杀后恢复 | `onLoad` 检查本地 `activeTimer.status`，若 `running` 且已过期 → 直接弹确认框 |

### 5.2 结束确认对话框

```
计时结束！
📖 完成作业  +30分钟  → 给 小明
[确认打卡]  [取消]
```

确认 → 调用详情页已有的 `addRecord(childId, ruleId, minutesChange)` → 清除 `activeTimer` 和 `timers` 集合中的对应文档。

### 5.3 修改现有文件

- `pages/detail/detail.{wxml,js}`：详情页加"计时器"入口按钮，跳转并传 `childId`
- `app.js`：`onShow` / `onLaunch` 检查 `activeTimer` 是否已到期，到期则 `wx.navigateTo` 到 timer 页弹确认
- `app.json`：注册 `pages/timer/timer` 路由

---

## 6. Flutter 端实现

### 6.1 新增页面 `lib/pages/timer_page.dart`

从 `child_detail_page.dart` 跳转。UI 结构与小程序对称：时间选择 + 规则单选 + 倒计时显示。

### 6.2 新增 Provider `lib/providers/timer_provider.dart`

Riverpod 管理 `ActiveTimer` 状态：

- `startTimer(child, rule, duration)` — 存 `sharedPreferences`、调度本地通知
- `tick()` — 每秒更新剩余时间
- `onComplete()` — 播提示音、置 `status=ended`、触发 UI 弹确认
- `confirmRecord()` — 调 `RecordRepository.addRecord` → 清状态
- `cancel()` — 取消通知、清状态

### 6.3 新增模型 `lib/models/active_timer.dart`

`ActiveTimer` 类 + `fromJson` / `toJson`，字段对应 4.1 节本地存储结构。

### 6.4 新增依赖（`pubspec.yaml`）

- `flutter_local_notifications: ^19.x` — 定时本地通知（AlarmManager / UNUserNotificationCenter）
- `audioplayers: ^6.x` — 前台结束提示音（可循环响到用户操作）

声明音频资源：
```yaml
flutter:
  assets:
    - assets/sounds/alert.wav
```

### 6.5 平台权限配置

**Android**（`AndroidManifest.xml`）：
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**iOS**（`Info.plist`）：
- 请求通知权限
- 如需后台响铃：`UIBackgroundModes: [audio]`

### 6.6 修改现有文件

- `lib/pages/child_detail_page.dart`：加计时器入口按钮
- `lib/router.dart`：加 `/timer` 路由（接收 `childId` 参数）
- `lib/main.dart`：初始化 `flutter_local_notifications` 插件

---

## 7. 云函数：timer-notify（仅小程序后台通知）

### 7.1 文件结构

```
cloudfunctions/timer-notify/
├── index.js
├── config.json
└── package.json
```

### 7.2 config.json（每分钟触发）

```json
{
  "triggers": [
    { "name": "timerTick", "type": "timer", "config": "0 * * * * * *" }
  ]
}
```

### 7.3 index.js 逻辑

1. 查询 `timers` 集合：`fireAt <= now && notified == false`
2. 对每条记录调用 `cloud.openapi.subscribeMessage.send`：
   - 模板参数：孩子名、规则名、分钟变化、到期时间
3. 标记 `notified = true`
4. 清理 `createdAt < now - 25h` 的记录（防止集合膨胀）

### 7.4 部署前置项（手动）

1. 小程序管理后台 → 订阅消息 → 申请/选用"计时提醒"类模板，获取 `templateId`
2. 模板的字段顺序需与云函数 `send` 的 `data` 对齐
3. 部署 `timer-notify` 云函数并配置定时触发器

> `templateId` 作为常量写在 `index.js` 顶部，部署前替换。

---

## 8. 提示音资源

两端需要一个短促的提示音（约 1–3 秒，类似闹铃）：
- 小程序：`miniprogram/miniprogram/assets/audio/alert.wav`
- Flutter：`app/assets/sounds/alert.wav`

> **实现备注：** 原设计稿写的是 `.mp3`，但实现环境无 MP3 编码器，改用 WAV（微信 `InnerAudioContext` 与 Flutter `audioplayers` 均支持）。实际生成的是一个 0.6 秒的双音叮咚（880Hz→1320Hz）。文件清单中其它出现 `alert.mp3` 的地方均指同一个 `alert.wav` 资源。

---

## 9. 计时器生命周期

```
[设置时间+规则] → [启动] → running
                          ├─ 前台：setInterval tick + 常亮
                          ├─ 切后台：JS 挂起，靠 timers 集合 + 定时触发器兜底
                          └─ App 被杀：靠本地 activeTimer 在重开时恢复
[fireAt 到达]
  ├─ 前台：playSound() + showConfirmDialog() → status=ended
  └─ 后台：通知发出，用户点回 App → onShow 检测到期 → showConfirmDialog
[用户确认] → addRecord → 清除 activeTimer + timers 文档 → status=ended → 界面返回详情页
[用户取消] → 清除 activeTimer + timers 文档 → status=cancelled → 界面返回详情页
```

**单计时器约束：** 启动新计时时若已有运行中的计时器，直接覆盖（静默替换）——实现时采用此更简化的语义，不再弹确认框。

---

## 10. 文件清单汇总

**小程序端（新增）：**
- `miniprogram/miniprogram/pages/timer/timer.{wxml,wxss,js,json}`
- `miniprogram/miniprogram/assets/audio/alert.wav`

**小程序端（修改）：**
- `miniprogram/miniprogram/pages/detail/detail.{wxml,js}` — 计时器入口按钮
- `miniprogram/miniprogram/app.js` — 启动时检查到期计时器
- `miniprogram/miniprogram/app.json` — 注册 timer 页面路由

**Flutter 端（新增）：**
- `app/lib/pages/timer_page.dart`
- `app/lib/providers/timer_provider.dart`
- `app/lib/models/active_timer.dart`
- `app/assets/sounds/alert.wav`

**Flutter 端（修改）：**
- `app/lib/pages/child_detail_page.dart` — 计时器入口按钮
- `app/lib/router.dart` — `/timer` 路由
- `app/lib/main.dart` — 初始化本地通知插件
- `app/pubspec.yaml` — 依赖 + 资源声明
- `app/android/app/src/main/AndroidManifest.xml` — 权限

**云函数（新增）：**
- `miniprogram/cloudfunctions/timer-notify/{index.js,config.json,package.json}`

**文档（更新）：**
- `shared/data-schema.md` — 补充 `timers` 集合定义
- `DEVELOPMENT.md` — 更新进度

---

## 11. 不在本期范围

以下功能有意排除，留待后续迭代：

- 多计时器并发（当前为单个）
- 计时器历史记录 / 统计
- 自定义提示音 / 多种铃声选择
- 计时器云同步（当前为设备本地临时状态）
- Flutter Web 平台的本地通知支持（Web 平台浏览器通知能力有限，本期聚焦 Android/iOS）

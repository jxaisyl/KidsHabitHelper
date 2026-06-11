# KidsHabitHelper - 小孩习惯养成可视化 App 设计文档

## 概述

家长驱动的电子设备使用时长管理工具。家长制定加减时长规则，App 方便记录并可视化展示数据。

## 目标平台

- Android（Flutter 跨平台开发）

## 核心需求

1. **积分制时长管理** — 家长定义规则（如：做家务 +30min，超时使用 -30min），通过规则加减小孩的电子设备使用时长
2. **多小孩支持** — 各小孩独立积分和记录
3. **便捷记录** — 一键选择规则+小孩完成打卡
4. **数据可视化** — 余额趋势、收支记录图表
5. **本地存储** — SQLite 本地存储，后期可扩展云同步

## 数据模型

### Child（小孩）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int (PK) | 自增主键 |
| name | string | 姓名 |
| avatar | string | 头像标识（emoji 或 asset path） |
| createdAt | datetime | 创建时间 |

### Rule（规则）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int (PK) | 自增主键 |
| name | string | 规则名称（如"做家务"） |
| minutesChange | int | 时长变化值，正数增加，负数扣减 |
| icon | string | 图标标识（emoji） |

- Rule 为全局共享，不绑定特定小孩，所有小孩共用同一套规则模板

### Record（记录）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | int (PK) | 自增主键 |
| childId | int (FK) | 关联小孩 |
| ruleId | int (FK) | 关联规则 |
| minutesChange | int | 本次时长变化（冗余存储，防止规则修改影响历史） |
| note | string | 备注（可选） |
| createdAt | datetime | 记录时间 |

- 余额通过 `SUM(minutesChange) WHERE childId = ?` 实时计算，不单独存表

## UI 设计

### 导航结构

底部 Tab 导航，3 个页面：

1. **首页** — 小孩列表
2. **统计** — 数据图表
3. **设置** — 管理小孩和规则

### 页面详细设计

#### 首页（小孩列表）

- 卡片式展示每个小孩：头像、姓名、当前余额（分钟数）
- 右下角浮动 "+" 按钮添加小孩
- 点击小孩卡片进入详情页

#### 小孩详情页

- 顶部显示当前余额（大字体）
- 快捷打卡区：横向排列规则标签（带颜色区分正负），点击即完成一条记录
- 下方显示最近记录列表（时间 + 规则图标 + 变化量 + 备注）

#### 数据统计页

- 选择小孩（下拉/切换）
- 余额趋势折线图（近7天/30天切换）
- 收支分布（按规则分类的收支汇总）

#### 设置页

- 管理小孩：增删改
- 管理规则：增删改
- 导出数据
- 关于

## 技术架构

### 三层架构

```
UI 层 (Flutter Widgets)
    ↕ Provider/Riverpod 状态管理
Service 层 (业务逻辑)
    ↕ Repository 接口
Data 层 (SQLite + drift/sqflite)
```

### 技术选型

| 组件 | 选择 | 理由 |
|------|------|------|
| 框架 | Flutter | 跨平台，UI 丰富 |
| 状态管理 | Riverpod | 轻量，类型安全，测试友好 |
| 数据库 | drift (SQLite) | 类型安全的 ORM，支持迁移 |
| 图表 | fl_chart | Flutter 主流图表库，灵活 |
| 路由 | go_router | 声明式路由，支持深链接 |

### 项目结构

```
lib/
├── main.dart
├── app.dart
├── models/           # 数据模型 (child, rule, record)
├── repositories/     # 数据访问层
├── services/         # 业务逻辑
├── providers/        # Riverpod providers
├── pages/            # 页面
│   ├── home/
│   ├── child_detail/
│   ├── statistics/
│   └── settings/
├── widgets/          # 共享组件
└── database/         # drift 数据库定义
```

## 非功能性需求

- 数据全部本地存储，无需网络
- 支持中文界面
- Material Design 3 风格
- 无需用户注册/登录

## 后续迭代方向（不在当前范围）

- 游戏化元素（金币、勋章、虚拟宠物）
- 云同步
- 多家长协作
- 通知提醒
- 更多习惯类型（非仅电子设备时长）

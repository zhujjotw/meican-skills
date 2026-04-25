---
name: meican
description: 美餐自动点餐、历史查询、健康推荐、习惯学习
license: MIT
compatibility: opencode
---

美餐企业订餐平台的 AI 接入 skill。登录后可以查菜单、下单、看历史、做健康推荐，并且持续学习用户习惯。

调用此 skill 后，先确认用户是否已登录（检查 MEICAN_USERNAME+MEICAN_PASSWORD 环境变量），未登录则提示用户设置。

## Capabilities

### 登录认证
登录美餐并持久化 Cookie。

- `scripts/login.sh` — 账号密码登录，Cookie 自动持久化
- POST `/account/directlogin` — Cookie-based Session 认证

### 菜单查询
查询排期、餐厅和菜品。

- `scripts/menu.sh` — 查排期日历 / 餐厅列表 / 菜品详情
- `GET /preorder/api/v2.1/calendarItems/list`
- `GET /preorder/api/v2.1/restaurants/list`
- `GET /preorder/api/v2.1/restaurants/show`

### 历史分析
查看历史订单和消费统计。

- `scripts/history.sh summary` — 过去 30 天订单汇总
- `scripts/history.sh date YYYY-MM-DD` — 查某天订单
- 数据来自 `calendarItems` 的 `corpOrderUser` 字段

### 自动点餐
下单和订单状态。

- `scripts/order.sh status` — 今日订单状态
- `scripts/order.sh order <dish_id> <tab_id> <target_time>` — 下单
- ⚠️ 下单前必须人类确认，禁止自动执行

### 健康推荐
录入健康约束并生成推荐。

- `scripts/health.sh set '{"max_calories": 600}'` — 设置约束
- `scripts/health.sh recommend` — 基于今日菜单推荐
- `scripts/health.sh goals` — 查看当前约束

### 习惯学习
持续学习用户偏好，越用越准。

- `scripts/learn.sh from-history` — 从历史订单自动学习
- `scripts/learn.sh prefer dish="牛肉"` — 手动录入偏好
- `scripts/learn.sh avoid dish="猪肉"` — 手动录入禁忌
- `scripts/learn.sh show` — 查看当前学习结果
- 存储于 `profile/habits.json`，可读可改

## Environment

| Variable | Description | Required |
|---|---|---|
| MEICAN_USERNAME | 美餐账号（邮箱/手机号） | Yes |
| MEICAN_PASSWORD | 美餐密码 | Yes |
| MEICAN_COOKIE_FILE | Cookie 文件路径，默认 /tmp/meican_cookie.txt | No |

## Security

所有凭证通过环境变量传递，禁止在任何文件、prompt、脚本、命令参数中硬编码密码。

---
name: meican
description: 美餐自动点餐，历史查询，健康推荐
license: MIT
compatibility: opencode
---

## Capabilities

### 登录认证
- 通过 `scripts/login.sh` 使用账号密码登录
- 使用 `POST /account/directlogin` 进行 Cookie-based Session 认证
- Cookie 自动持久化，后续 API 调用复用

### 菜单查询
- 获取排期日历：`GET /preorder/api/v2.1/calendarItems/list`
- 获取餐厅列表：`GET /preorder/api/v2.1/restaurants/list`
- 获取菜品详情：`GET /preorder/api/v2.1/restaurants/show`

### 自动点餐
- 按菜品 ID 提交订单：`POST /preorder/api/v2.1/orders/add`
- 今日订单状态查询
- 默认只预览，需人类确认后才执行

### 历史分析
- 拉取历史订单记录
- 汇总统计消费数据

### 健康推荐
- 录入健康约束（低卡、低脂、过敏源等）
- 根据约束+今日菜单生成推荐

## Workflow

1. 登录 → `scripts/login.sh`（需先设置 MEICAN_USERNAME + MEICAN_PASSWORD）
2. 查菜单 → `scripts/menu.sh`（排期 → 餐厅 → 菜品）
3. 下单 → `scripts/order.sh order <dish_id> <tab_id> <target_time>`
4. 分析 → `scripts/history.sh summary`
5. 健康 → `scripts/health.sh recommend`

## Environment

| Variable | Description | Required |
|---|---|---|
| MEICAN_USERNAME | 美餐账号（邮箱/手机号） | Yes |
| MEICAN_PASSWORD | 美餐密码 | Yes |
| MEICAN_COOKIE_FILE | Cookie 文件路径 | No |
| MEICAN_HEALTH_FILE | 健康目标配置路径 | No |

## Auth API Reference

```
POST https://meican.com/account/directlogin
Content-Type: application/x-www-form-urlencoded

username=<email>&password=<pwd>&loginType=username&remember=true
```

## Menu API Reference

```
GET /preorder/api/v2.1/calendarItems/list
GET /preorder/api/v2.1/restaurants/list?tabUniqueId=<id>&targetTime=<ts>
GET /preorder/api/v2.1/restaurants/show?restaurantUniqueId=<id>&tabUniqueId=<id>&targetTime=<ts>
POST /preorder/api/v2.1/orders/add
    order=[{"count":"1","dishId":"<id>"}]
    tabUniqueId=<id>
    targetTime=<ts>
```

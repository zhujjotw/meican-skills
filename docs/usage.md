# 美餐自动点餐 Skill 使用指南

## 目录结构

```
meican-skills/
  .opencode/skills/meican/SKILL.md   # skill 定义
  scripts/
    login.sh        # 登录认证
    menu.sh         # 菜单查询
    order.sh        # 下单 + 订单状态
    history.sh      # 历史订单
    health.sh       # 健康推荐
  tests/
    test_login.sh   # 测试脚本
  docs/
    usage.md        # 本文件
  prompts/
    order.txt       # 点餐 prompt
    health.txt      # 健康推荐 prompt
  .env.example      # 环境变量模板
```

## 快速开始

### 1. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env，填入 MEICAN_USERNAME 和 MEICAN_PASSWORD
```

### 2. 登录

```bash
source .env
./scripts/login.sh
```

### 3. 查菜单

```bash
# 获取排期日历
./scripts/menu.sh

# 获取餐厅列表
./scripts/menu.sh <tab_id> <target_time>

# 获取菜品
./scripts/menu.sh <restaurant_id> <tab_id> <target_time>
```

### 4. 下单

```bash
# 查看今日订单状态
./scripts/order.sh status

# 下单
./scripts/order.sh order <dish_id> <tab_id> <target_time>
```

### 5. 历史查询

```bash
./scripts/history.sh summary
```

### 6. 健康推荐

```bash
./scripts/health.sh set '{"max_calories": 600, "avoid": ["pork"]}'
./scripts/health.sh recommend
```

## 注意事项

- 美餐使用 Cookie-based Session 认证，登录后 Cookie 保存在本地文件
- 所有 POST 请求使用 `application/x-www-form-urlencoded`
- GET 请求可附加 `noHttpGetCache` 时间戳参数防缓存
- 登录失败请检查响应体是否包含"用户名或密码错误"文本

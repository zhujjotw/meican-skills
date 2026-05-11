# 🍱 美餐自动点餐 Skill

![美餐自动点餐](meican-hero.png)

**美餐企业订餐的 AI 智能体接入 skill。点餐、查历史、健康推荐、习惯学习，全自动。**

---

## 特色

### 🤖 智能自动点餐
全新引入自动点餐功能，基于历史习惯智能推荐菜品并自动下单。

```
# 设置每天上午10点自动点餐
# 支持基于历史偏好的智能推荐
# 自动发送钉钉通知点餐结果
bash scripts/auto-order.sh
```

### 🧠 习惯越用越聪明
不是死板地调 API。每次下单都是学习机会——自动记录你爱吃什么、不吃什么、在哪吃、花多少。用得越久，推荐越准。

```
# 学习过去 90 天的点餐习惯
bash scripts/learn.sh from-history

# 查看学会了什么
bash scripts/learn.sh show
```

### 🔐 安全第一，凭证不进代码
所有敏感信息通过环境变量传递，禁止硬编码。`.env` 和 `profile/` 都在 `.gitignore` 中，不会误提交。

```
export MEICAN_USERNAME="your@email.com"
export MEICAN_PASSWORD="your_password"
```

### 📦 Agent 无关，即插即用
不绑定任何 AI agent 框架。`SKILL.md` 在仓库根目录，随意 symlink 到任意 skills 路径：

```bash
# opencode
ln -s ~/meican-skills ~/.config/opencode/skills/meican

# claude code
ln -s ~/meican-skills ~/.claude/skills/meican

# 任何兼容 skill 的 agent
```

### 🔍 真实 API，不猜不捏造
所有接口来自对美餐网页端的抓包分析 + 开源社区 SDK 验证。Cookie-based Session 认证，稳定可靠。

### 🛡 下单前必确认
涉及支付的操作，默认只输出预览，人类确认后才执行。不会偷偷帮你点餐。

---

## 快速开始

```bash
# 1. 设置环境变量
export MEICAN_USERNAME="your@email.com"
export MEICAN_PASSWORD="your_password"

# 2. 登录
bash scripts/login.sh

# 3. 查今日菜单
bash scripts/menu.sh

# 4. 看历史订单
bash scripts/history.sh summary

# 5. 让 skill 学习你的习惯
bash scripts/learn.sh from-history
```

## 🤖 智能自动点餐

### 功能特性
- **🧠 历史习惯学习** - 自动分析您的历史订单，学习口味偏好
- **⚡ 智能推荐算法** - 多维度评分系统（价格、口味、套餐类型）
- **📱 钉钉通知** - 点餐成功后自动发送通知到钉钉
- **🔄 定时执行** - 支持cron定时任务，每天自动点餐

### 推荐评分机制
- **价格匹配** (40分) - 符合您的价格偏好
- **口味偏好** (40分) - 包含您喜欢的菜品类型
- **套餐类型** (20分) - 优选套餐类型
- **配菜加分** (10分) - 配饮品/小菜/时蔬

### 使用方法

#### 手动测试
```bash
# 设置环境变量
export MEICAN_USERNAME="your@email.com"
export MEICAN_PASSWORD="your_password"

# 执行自动点餐
bash scripts/auto-order.sh
```

#### 设置定时任务
```bash
# 使用cron每天上午10点自动点餐
0 10 * * * bash /path/to/meican-skills/scripts/auto-order.sh
```

### 钉钉通知配置
自动点餐成功后会发送钉钉通知，包含：
- 菜品名称和价格
- AI推荐评分
- 推荐理由

确保已安装 `send-dingtalk-message` skill 并配置好钉钉凭据。

---

## 目录结构

```
meican-skills/
  SKILL.md              # skill 定义（agent 加载入口）
  scripts/
    login.sh            # 登录认证
    menu.sh             # 排期 → 餐厅 → 菜品
    order.sh            # 下单 + 订单状态
    auto-order.sh       # 智能自动点餐（NEW!）
    history.sh          # 历史订单 + 消费统计
    health.sh           # 健康约束 + 推荐
    learn.sh            # 习惯学习系统
    verify.sh           # 功能验证
  profile/
    habits.json         # 习惯数据库（持续学习）
    habits.json.example # 习惯数据模板
  docs/
    usage.md            # 完整使用文档
  tests/
    test_login.sh       # 脚本语法测试
  prompts/
    order.txt           # 点餐 prompt
    health.txt          # 健康推荐 prompt
  .env.example          # 环境变量模板
  .gitignore            # 忽略敏感文件
```

---

## 功能一览

| 功能 | 脚本 | 说明 |
|------|------|------|
| 登录 | `login.sh` | 账号密码 → Cookie-based Session |
| 菜单 | `menu.sh` | 日历排期 → 餐厅 → 菜品详情 |
| 下单 | `order.sh` | 提交订单 / 今日订单状态 |
| **自动点餐** | `auto-order.sh` | **基于历史习惯的智能推荐 + 自动下单 + 钉钉通知** |
| 历史 | `history.sh` | 过去 30 天 / 指定日期订单 |
| 健康 | `health.sh` | 录入约束 → 今日菜单推荐 |
| 学习 | `learn.sh` | 自动学习 + 手动录入偏好 |

---

## 技术细节

- **认证**: `POST /account/directlogin` — Cookie-based Session
- **菜单**: `GET /preorder/api/v2.1/calendarItems/list`
- **下单**: `POST /preorder/api/v2.1/orders/add`
---

## 安全

- 所有凭证通过环境变量传递
- `.env` 和 `profile/` 在 `.gitignore` 中
- 下单操作必须人类确认
- 脚本使用 `set -euo pipefail`，变量未设置时立即报错

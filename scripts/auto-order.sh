#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COOKIE_FILE="${MEICAN_COOKIE_FILE:-/tmp/meican_cookie.txt}"

# 确保已登录
if [[ ! -f "$COOKIE_FILE" ]]; then
    echo "未登录，正在登录..."
    bash "$SCRIPT_DIR/login.sh"
fi

echo "=== 开始自动点餐流程 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 1. 获取今日菜单
echo "正在获取今日菜单..."
MENU_JSON=$(bash "$SCRIPT_DIR/menu.sh" 2>&1)

if echo "$MENU_JSON" | grep -qiE "(error|fail|未登录)"; then
    echo "获取菜单失败，尝试重新登录..."
    bash "$SCRIPT_DIR/login.sh"
    MENU_JSON=$(bash "$SCRIPT_DIR/menu.sh" 2>&1)
fi

# 2. 基于原始meican skills的智能推荐系统
echo "正在基于历史习惯进行AI推荐..."

# 确保习惯数据已学习
HABITS_FILE="$SCRIPT_DIR/../profile/habits.json"
if [[ ! -f "$HABITS_FILE" ]]; then
    echo "首次使用，正在学习历史订单..."
    bash "$SCRIPT_DIR/learn.sh" from-history
fi

# 从habits.json中读取用户偏好
if [[ -f "$HABITS_FILE" ]]; then
    # 使用Python解析JSON并提取偏好
    PREFERENCES=$(python3 - "$HABITS_FILE" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
habits = data.get('habits', {})

# 提取偏好信息
proteins = habits.get('dish_preferences', {}).get('protein', [])
cuisines = habits.get('dish_preferences', {}).get('favorite_cuisines', [])
budget = habits.get('budget', {})
avg_price = budget.get('average_price_in_cent', 3000) / 100
price_range = budget.get('preferred_range', [2500, 3500])
preferred_corp = habits.get('ordering_patterns', {}).get('preferred_corp', '')

# 构建关键词匹配模式
keywords = []
keywords.extend(proteins)
keywords.extend(cuisines)
keyword_pattern = '|'.join(keywords) if keywords else '套餐|配饮品'

# 输出推荐参数
print(f"{avg_price}|{price_range[0]/100}|{price_range[1]/100}|{keyword_pattern}|{preferred_corp}")
PYEOF
)

    # 解析偏好参数
    IFS='|' read -r avg_price price_min price_max keywords preferred_corp <<< "$PREFERENCES"

    echo "用户偏好设置:"
    echo "  - 平均价格: ¥$avg_price"
    echo "  - 价格范围: ¥$price_min - ¥$price_max"
    echo "  - 喜好关键词: $keywords"
    echo "  - 偏好餐厅: $preferred_corp"

    # 3. 智能选择菜品
    echo "正在分析今日菜单..."

    # 从菜单中提取菜品信息并评分
    DISH_INFO=$(echo "$MENU_JSON" | grep -oP '"name":"[^"]+","priceInCent":[0-9]+,"id":[0-9]+' | head -20)

    if [[ -z "$DISH_INFO" ]]; then
        echo "错误: 未能获取到今日菜单"
        exit 1
    fi

    best_dish=""
    best_score=0
    best_dish_id=""
    best_dish_price_cent=0

    while IFS= read -r dish_match; do
        dish_name=$(echo "$dish_match" | grep -oP '"name":"\K[^"]+' | head -1)
        dish_price_cent=$(echo "$dish_match" | grep -oP '"priceInCent":\K[0-9]+' | head -1)
        dish_id=$(echo "$dish_match" | grep -oP '"id":\K[0-9]+' | head -1)

        if [[ -z "$dish_name" || -z "$dish_id" ]]; then
            continue
        fi

        dish_price=$((dish_price_cent / 100))
        score=0

        # 价格匹配评分 (40分)
        if (( dish_price >= price_min && dish_price <= price_max )); then
            score=$((score + 40))
        elif (( dish_price >= price_min - 5 && dish_price <= price_max + 5 )); then
            score=$((score + 20))
        fi

        # 关键词匹配评分 (40分)
        if [[ "$dish_name" =~ $keywords ]]; then
            score=$((score + 40))
        fi

        # 套餐类型评分 (20分)
        if [[ "$dish_name" =~ 套餐 ]]; then
            score=$((score + 20))
        fi

        # 配菜加分 (10分)
        if [[ "$dish_name" =~ (配饮品|配小菜|时蔬|米饭) ]]; then
            score=$((score + 10))
        fi

        echo "分析: $dish_name (¥$dish_price) - 评分: $score"

        if (( score > best_score )); then
            best_score=$score
            best_dish="$dish_name"
            best_dish_id="$dish_id"
            best_dish_price_cent="$dish_price_cent"
        fi
    done <<< "$DISH_INFO"

    if [[ -n "$best_dish" ]]; then
        DISH_NAME="$best_dish"
        DISH_ID="$best_dish_id"
        DISH_PRICE_CENT="$best_dish_price_cent"

        echo ""
        echo "=== 🎯 智能推荐结果 ==="
        echo "菜品: $DISH_NAME"
        echo "价格: ¥$((DISH_PRICE_CENT / 100))"
        echo "评分: $best_score/100"

        if (( best_score >= 80 )); then
            echo "推荐理由: ✅ 强烈推荐 - 完美匹配您的口味偏好"
        elif (( best_score >= 60 )); then
            echo "推荐理由: ✅ 推荐 - 符合您的大部分偏好"
        else
            echo "推荐理由: ⚠️ 备选 - 今日菜单暂无更符合您偏好的菜品"
        fi
    else
        echo "未找到合适的菜品"
        exit 1
    fi
else
    echo "错误: 无法读取用户偏好数据"
    exit 1
fi

# 获取tab ID（从菜单中获取）
TAB_ID=$(echo "$MENU_JSON" | grep -oP '"uniqueId":"[^"]*","name"[^}]*"openingTime"' | grep -oP '"uniqueId":"\K[^"]+' | head -1)

if [[ -z "$TAB_ID" ]]; then
    echo "错误: 无法获取Tab ID"
    exit 1
fi

echo "Tab ID: $TAB_ID"

# 4. 下单
echo "正在下单..."
ORDER_RESULT=$(bash "$SCRIPT_DIR/order.sh" order "$DISH_ID" "$TAB_ID" "evening" 2>&1)

if echo "$ORDER_RESULT" | grep -qiE "(success|成功|订单已提交|USER_RECEIVED)"; then
    echo "✅ 下单成功!"

    # 5. 发送钉钉通知
    DINGTALK_CONTENT="菜品: $DISH_NAME
价格: ¥$((DISH_PRICE_CENT / 100))
时间: $(date '+%Y-%m-%d %H:%M')
AI评分: $best_score/100
推荐理由: 基于您的历史口味偏好学习
状态: 自动点餐成功"

    # 尝试发送钉钉通知
    if [[ -d "$HOME/.claude/skills/send-dingtalk-message/scripts" ]]; then
        python3 "$HOME/.claude/skills/send-dingtalk-message/scripts/send.py" \
            --type markdown \
            --title "自动点餐成功" \
            --content "$DINGTALK_CONTENT" \
            --user jiajia.zhu 2>/dev/null || echo "钉钉通知发送失败"
    fi

    echo "订单完成: $DISH_NAME (¥$((DISH_PRICE_CENT / 100)))"
else
    echo "❌ 下单失败: $ORDER_RESULT"

    # 发送失败通知
    FAIL_CONTENT="自动点餐失败
时间: $(date '+%Y-%m-%d %H:%M')
错误: $ORDER_RESULT
请手动点餐"

    if [[ -d "$HOME/.claude/skills/send-dingtalk-message/scripts" ]]; then
        python3 "$HOME/.claude/skills/send-dingtalk-message/scripts/send.py" \
            --type markdown \
            --title "自动点餐失败" \
            --content "$FAIL_CONTENT" \
            --user jiajia.zhu 2>/dev/null || true
    fi

    exit 1
fi

echo "=== 自动点餐流程完成 ==="

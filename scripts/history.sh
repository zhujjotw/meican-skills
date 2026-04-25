#!/usr/bin/env bash
set -euo pipefail

COOKIE_FILE="${MEICAN_COOKIE_FILE:-/tmp/meican_cookie.txt}"
BASE_URL="https://meican.com"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

api_get() {
    local path="$1"
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "${BASE_URL}${path}"
}

get_orders() {
    local begin="${1:-$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '-30 days' +%Y-%m-%d 2>/dev/null)}"
    local end="${2:-$(date +%Y-%m-%d)}"
    api_get "/preorder/api/v2.1/calendarItems/list?beginDate=${begin}&endDate=${end}&withOrderDetail=true&noHttpGetCache=$(date +%s%3N)"
}

format_orders() {
    local data
    data=$(cat)
    echo "$data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
found = 0
for day in data.get('dateList', []):
    date = day['date']
    for item in day.get('calendarItemList', []):
        order = item.get('corpOrderUser')
        if order and order.get('restaurantItemList'):
            for ri in order.get('restaurantItemList', []):
                for di in ri.get('dishItemList', []):
                    dish = di.get('dish', {})
                    name = dish.get('name', '?')
                    count = dish.get('count', di.get('count', 1))
                    price = dish.get('priceInCent', 0)
                    price_yuan = price / 100 if price else 0
                    print(f'{date} | {item.get(\"title\",\"?\")} | {name} x{count} | \${price_yuan:.2f}')
                    found += 1
if found == 0:
    print('No orders found in this date range')
" 2>/dev/null
}

get_summary() {
    echo "=== History Orders ==="
    local data
    data=$(get_orders "${1:-}" "${2:-}")
    echo "$data" | format_orders

    echo ""
    echo "=== Stats ==="
    echo "$data" | python3 -c "
import json, sys
from collections import Counter
data = json.load(sys.stdin)
dishes = []
total = 0
total_price = 0
for day in data.get('dateList', []):
    for item in day.get('calendarItemList', []):
        order = item.get('corpOrderUser')
        if order and order.get('restaurantItemList'):
            for ri in order.get('restaurantItemList', []):
                for di in ri.get('dishItemList', []):
                    dish = di.get('dish', {})
                    name = dish.get('name', '?')
                    price = dish.get('priceInCent', 0)
                    count = dish.get('count', di.get('count', 1))
                    dishes.append(name)
                    total += count
                    total_price += price * count
print(f'Total orders: {total}')
print(f'Total spent: \${total_price/100:.2f}')
print(f'Unique dishes: {len(set(dishes))}')
print(f'Most ordered: {Counter(dishes).most_common(3)}')
" 2>/dev/null
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ ! -f "$COOKIE_FILE" ]]; then
        echo "Error: Not logged in. Run login.sh first" >&2
        exit 1
    fi

    mode="${1:-summary}"
    case "$mode" in
        summary)
            get_summary "${2:-}" "${3:-}"
            ;;
        raw)
            get_orders "${2:-}" "${3:-}"
            ;;
        date)
            d="${2:-$(date +%Y-%m-%d)}"
            get_orders "$d" "$d"
            ;;
        *)
            echo "Usage: $0 {summary [begin_date] [end_date]|raw [begin] [end]|date [yyyy-mm-dd]}"
            exit 1
            ;;
    esac
fi

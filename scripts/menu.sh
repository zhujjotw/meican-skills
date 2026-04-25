#!/usr/bin/env bash
set -euo pipefail

COOKIE_FILE="${MEICAN_COOKIE_FILE:-/tmp/meican_cookie.txt}"
BASE_URL="https://meican.com"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

api_get() {
    local path="$1"
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" \
        "${BASE_URL}${path}"
}

get_calendar() {
    echo "=== 获取排期日历 ==="
    local today
    today=$(date +%Y-%m-%d)
    local next_week
    next_week=$(date -v+7d +%Y-%m-%d 2>/dev/null || date -d "+7 days" +%Y-%m-%d 2>/dev/null)
    api_get "/preorder/api/v2.1/calendarItems/list?beginDate=${today}&endDate=${next_week}&withOrderDetail=false&noHttpGetCache=$(date +%s%3N)"
}

get_restaurants() {
    local tab_id="$1"
    local target_time="$2"
    echo "=== 餐厅列表 ==="
    api_get "/preorder/api/v2.1/restaurants/list?tabUniqueId=${tab_id}&targetTime=${target_time}&noHttpGetCache=$(date +%s%3N)"
}

get_dishes() {
    local restaurant_id="$1"
    local tab_id="$2"
    local target_time="$3"
    echo "=== 菜品列表 ==="
    api_get "/preorder/api/v2.1/restaurants/show?restaurantUniqueId=${restaurant_id}&tabUniqueId=${tab_id}&targetTime=${target_time}&noHttpGetCache=$(date +%s%3N)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ ! -f "$COOKIE_FILE" ]]; then
        echo "Error: Not logged in. Run login.sh first" >&2
        exit 1
    fi

    tab_id="${1:-}"
    target_time="${2:-}"
    restaurant_id="${3:-}"

    if [[ -n "$restaurant_id" ]]; then
        get_dishes "$restaurant_id" "$tab_id" "$target_time"
    elif [[ -n "$tab_id" ]]; then
        get_restaurants "$tab_id" "$target_time"
    else
        get_calendar
    fi
fi

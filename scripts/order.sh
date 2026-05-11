#!/usr/bin/env bash
set -euo pipefail

COOKIE_FILE="${MEICAN_COOKIE_FILE:-/tmp/meican_cookie.txt}"
BASE_URL="https://meican.com"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

place_order() {
    local dish_id="$1"
    local tab_id="$2"
    local target_time="$3"
    local corp_addr_id="${4:-}"
    local user_addr_id="${5:-}"

    local order_data
    order_data=$(printf '{"count":"1","dishId":"%s"}' "$dish_id")

    echo "Placing order for dish: $dish_id"

    local resp
    resp=$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" \
        -d "order=[${order_data}]" \
        -d "tabUniqueId=${tab_id}" \
        -d "targetTime=${target_time}" \
        ${corp_addr_id:+-d "corpAddressUniqueId=${corp_addr_id}"} \
        ${user_addr_id:+-d "userAddressUniqueId=${user_addr_id}"} \
        "${BASE_URL}/preorder/api/v2.1/orders/add")

    echo "$resp"
}

check_order_status() {
    echo "=== 今日订单状态 ==="
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" \
        "${BASE_URL}/forward/api" \
        -d "action=user/orders/today"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ ! -f "$COOKIE_FILE" ]]; then
        echo "Error: Not logged in. Run login.sh first" >&2
        exit 1
    fi

    action="${1:-status}"

    case "$action" in
        status)
            check_order_status
            ;;
        order)
            place_order "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}"
            ;;
        *)
            echo "Usage: $0 {status|order <dish_id> <tab_id> <target_time> [corp_addr_id] [user_addr_id]}"
            exit 1
            ;;
    esac
fi

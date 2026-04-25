#!/usr/bin/env bash
set -euo pipefail

COOKIE_FILE="${MEICAN_COOKIE_FILE:-/tmp/meican_cookie.txt}"
BASE_URL="https://meican.com"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

get_history() {
    local action="${1:-user/orders/history}"
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" \
        -d "action=${action}" \
        "${BASE_URL}/forward/api"
}

get_summary() {
    echo "=== 历史订单汇总 ==="
    local data
    data=$(get_history)
    echo "$data" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    orders = d if isinstance(d, list) else d.get('list', [])
    total = len(orders)
    print(f'Total orders: {total}')
    for o in orders[:10]:
        print(f\"  - {o.get('date', '?')}: {o.get('restaurant', {}).get('name', '?')} | {o.get('status', '?')}\")
except:
    print(d)
" 2>/dev/null || echo "$data"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ ! -f "$COOKIE_FILE" ]]; then
        echo "Error: Not logged in. Run login.sh first" >&2
        exit 1
    fi

    local mode="${1:-summary}"
    case "$mode" in
        summary) get_summary ;;
        raw)     get_history "${2:-user/orders/history}" ;;
        *)
            echo "Usage: $0 {summary|raw [action]}"
            exit 1
            ;;
    esac
fi

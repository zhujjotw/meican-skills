#!/usr/bin/env bash
set -euo pipefail

COOKIE_FILE="${MEICAN_COOKIE_FILE:-/tmp/meican_cookie.txt}"
BASE_URL="https://meican.com"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

HEALTH_FILE="${MEICAN_HEALTH_FILE:-/tmp/meican_health.json}"

set_health_goals() {
    local goals="$1"
    echo "$goals" > "$HEALTH_FILE"
    echo "Health goals saved to: $HEALTH_FILE"
}

get_health_goals() {
    if [[ ! -f "$HEALTH_FILE" ]]; then
        echo "{}"
        return
    fi
    cat "$HEALTH_FILE"
}

get_today_menu() {
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" \
        "${BASE_URL}/preorder/api/v2.1/calendarItems/list?noHttpGetCache=$(date +%s%3N)"
}

recommend() {
    local goals
    goals=$(get_health_goals)
    echo "=== 健康推荐 ==="
    echo "Current health goals: $goals"
    echo ""
    get_today_menu | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    items = d.get('dateList', [])
    print(f'Found {len(items)} date(s) with menu items')
    for dt in items:
        for ci in dt.get('calendarItemList', []):
            print(f\"  - {ci.get('title', '?')}: {ci.get('status', '?')}\")
except:
    print('Unable to parse menu for recommendation')
" 2>/dev/null
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    local cmd="${1:-help}"

    case "$cmd" in
        set)
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 set '{\"max_calories\": 600, \"avoid\": [\"pork\"]}'"
                exit 1
            fi
            set_health_goals "${2}"
            ;;
        goals)
            get_health_goals
            ;;
        recommend)
            recommend
            ;;
        *)
            echo "Usage: $0 {set|goals|recommend}"
            exit 1
            ;;
    esac
fi

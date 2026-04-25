#!/usr/bin/env bash
set -euo pipefail

COOKIE_FILE="${MEICAN_COOKIE_FILE:-/tmp/meican_cookie.txt}"
BASE_URL="https://meican.com"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
HABITS_FILE="$(cd "$(dirname "$0")/.." && pwd)/profile/habits.json"

ensure_habits() {
    if [[ ! -f "$HABITS_FILE" ]]; then
        mkdir -p "$(dirname "$HABITS_FILE")"
        cat > "$HABITS_FILE" << 'EOF'
{
  "version": 1,
  "learned_since": "",
  "last_updated": "",
  "habits": {
    "dish_preferences": { "protein": [], "avoid": [], "favorite_cuisines": [], "never_order": [] },
    "ordering_patterns": { "most_ordered": [], "preferred_meal_time": "", "preferred_corp": "", "weekday_ordering": true, "weekend_ordering": false },
    "location": { "default_corp": "", "default_address_uid": "", "used_locations": [] },
    "budget": { "average_price_in_cent": 0, "max_price_in_cent": 0, "preferred_range": [] },
    "health": { "dietary_restrictions": [], "calorie_preference": "normal", "allergies": [] }
  }
}
EOF
    fi
}

show_habits() {
    ensure_habits
    python3 - "$HABITS_FILE" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
h = d['habits']
print('=== Habits Profile ===')
print('Last updated:', d.get('last_updated', 'never'))
print()

dp = h['dish_preferences']
print('Dish Preferences:')
print('  Protein:', ', '.join(dp['protein']) if dp['protein'] else '(none)')
print('  Avoid:', ', '.join(dp['avoid']) if dp['avoid'] else '(none)')
print('  Never order:', ', '.join(dp['never_order']) if dp['never_order'] else '(none)')
print()

op = h['ordering_patterns']
print('Ordering Patterns:')
print('  Preferred meal:', op['preferred_meal_time'] or '(unknown)')
print('  Preferred corp:', op['preferred_corp'] or '(unknown)')
print('  Weekday ordering:', op['weekday_ordering'])
if op['most_ordered']:
    print('  Most ordered:')
    for item in op['most_ordered'][:5]:
        print('    -', item['dish'], '(x' + str(item['count']) + ')')
print()

loc = h['location']
print('Location:')
print('  Default corp:', loc['default_corp'] or '(unknown)')
if loc['used_locations']:
    print('  Used locations:')
    for l in loc['used_locations']:
        print('    -', l['corp'], '(x' + str(l['count']) + ')')
print()

b = h['budget']
print('Budget:')
print('  Average: $' + format(b['average_price_in_cent']/100, '.2f'))
print('  Max: $' + format(b['max_price_in_cent']/100, '.2f'))
print()

hl = h['health']
print('Health:')
print('  Restrictions:', ', '.join(hl['dietary_restrictions']) if hl['dietary_restrictions'] else '(none)')
print('  Allergies:', ', '.join(hl['allergies']) if hl['allergies'] else '(none)')
PYEOF
}

learn_from_history() {
    ensure_habits
    if [[ ! -f "$COOKIE_FILE" ]]; then
        echo "Error: Not logged in. Run login.sh first" >&2
        return 1
    fi

    echo "Learning from order history..."
    local begin="${1:-$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '-90 days' +%Y-%m-%d 2>/dev/null)}"
    local end="${2:-$(date +%Y-%m-%d)}"

    local tmpfile
    tmpfile=$(mktemp)
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" \
        "${BASE_URL}/preorder/api/v2.1/calendarItems/list?beginDate=${begin}&endDate=${end}&withOrderDetail=true&noHttpGetCache=$(date +%s%3N)" > "$tmpfile"

    python3 - "$tmpfile" "$HABITS_FILE" "$end" "$begin" << 'PYEOF'
import json, sys
from collections import Counter

data_file = sys.argv[1]
habits_file = sys.argv[2]
end_date = sys.argv[3]
begin_date = sys.argv[4]

with open(data_file) as f:
    data = json.load(f)

with open(habits_file) as f:
    profile = json.load(f)

h = profile['habits']
dish_counter = Counter()
corp_counter = Counter()
total_price = 0
total_count = 0
price_list = []
proteins = set()

for day in data.get('dateList', []):
    for item in day.get('calendarItemList', []):
        order = item.get('corpOrderUser')
        if order and order.get('restaurantItemList'):
            title = item.get('title', '')
            for ri in order.get('restaurantItemList', []):
                for di in ri.get('dishItemList', []):
                    dish = di.get('dish', {})
                    name = dish.get('name', '?')
                    price = dish.get('priceInCent', 0)
                    count = dish.get('count', di.get('count', 1))
                    dish_counter[name] += count
                    total_price += price * count
                    total_count += count
                    price_list.append(price)
                    for kw in ['牛肉', '鸡胸', '鸡', '鸭', '鱼', '虾', '猪肉']:
                        if kw in name:
                            proteins.add(kw)
                            break
            corp_name = title.split('加班晚餐')[0].split('早餐')[0].split('午餐')[0].split('晚餐')[0].strip()
            if not corp_name:
                corp_name = title
            corp_counter[corp_name] += 1

h['ordering_patterns']['most_ordered'] = [
    {'dish': d, 'count': c, 'last': end_date}
    for d, c in dish_counter.most_common(10)
]
h['location']['used_locations'] = [
    {'corp': c, 'count': cnt}
    for c, cnt in corp_counter.most_common()
]
if corp_counter:
    h['location']['default_corp'] = corp_counter.most_common(1)[0][0]
if price_list:
    h['budget']['average_price_in_cent'] = total_price // total_count if total_count else 0
    h['budget']['max_price_in_cent'] = max(price_list)
    h['budget']['preferred_range'] = [min(price_list), max(price_list)]
known = set(h['dish_preferences']['protein'])
known.update(proteins)
h['dish_preferences']['protein'] = sorted(known)
profile['last_updated'] = end_date
if not profile['learned_since']:
    profile['learned_since'] = begin_date

with open(habits_file, 'w') as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)

print(f'Learned {total_count} dishes from {len(dish_counter)} unique items')
print(f'Updated habits: {habits_file}')
PYEOF

    rm -f "$tmpfile"
}

add_prefer() {
    ensure_habits
    local key="$1"
    local value="$2"
    python3 - "$HABITS_FILE" "$key" "$value" << 'PYEOF'
import json, sys
habits_file = sys.argv[1]
key = sys.argv[2]
value = sys.argv[3]
with open(habits_file) as f:
    profile = json.load(f)
h = profile['habits']
if key == 'dish':
    if value not in h['dish_preferences']['protein']:
        h['dish_preferences']['protein'].append(value)
elif key == 'cuisine':
    if value not in h['dish_preferences']['favorite_cuisines']:
        h['dish_preferences']['favorite_cuisines'].append(value)
elif key == 'corp':
    h['location']['default_corp'] = value
import datetime
profile['last_updated'] = datetime.date.today().isoformat()
with open(habits_file, 'w') as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
print('Added preference:', key, '=', value)
PYEOF
}

add_avoid() {
    ensure_habits
    local key="$1"
    local value="$2"
    python3 - "$HABITS_FILE" "$key" "$value" << 'PYEOF'
import json, sys
habits_file = sys.argv[1]
key = sys.argv[2]
value = sys.argv[3]
with open(habits_file) as f:
    profile = json.load(f)
h = profile['habits']
target = h['dish_preferences']['never_order'] if key == 'dish' else h['dish_preferences']['avoid']
if value not in target:
    target.append(value)
import datetime
profile['last_updated'] = datetime.date.today().isoformat()
with open(habits_file, 'w') as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
print('Added avoidance:', key, '=', value)
PYEOF
}

reset_habits() {
    rm -f "$HABITS_FILE"
    ensure_habits
    echo "Habits profile reset to default"
}

case "${1:-help}" in
    show)
        show_habits
        ;;
    from-history)
        learn_from_history "${2:-}" "${3:-}"
        ;;
    prefer)
        shift
        local key="${1:-}"
        local value="${2:-}"
        local reason="${3:-}"
        if [[ -z "$key" || -z "$value" ]]; then
            echo "Usage: $0 prefer <type=dish|cuisine|corp> <value> [reason]"
            echo "Example: $0 prefer dish 牛肉 常点"
            exit 1
        fi
        add_prefer "$key" "$value" "$reason"
        ;;
    avoid)
        shift
        local key="${1:-}"
        local value="${2:-}"
        local reason="${3:-}"
        if [[ -z "$key" || -z "$value" ]]; then
            echo "Usage: $0 avoid <type=dish|cuisine|ingredient> <value> [reason]"
            echo "Example: $0 avoid dish 猪肉 不喜欢"
            exit 1
        fi
        add_avoid "$key" "$value" "$reason"
        ;;
    reset)
        reset_habits
        ;;
    *)
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  show                         View current habits profile"
        echo "  from-history [begin] [end]   Learn from order history"
        echo "  prefer <type> <value>        Add a preference (dish/cuisine/corp)"
        echo "  avoid <type> <value>         Add an avoidance (dish/ingredient)"
        echo "  reset                        Reset all learned habits"
        echo ""
        echo "Examples:"
        echo "  $0 from-history"
        echo "  $0 prefer dish 牛肉"
        echo "  $0 avoid dish 猪肉"
        echo "  $0 prefer corp 天数智芯（浦江）"
        exit 1
        ;;
esac

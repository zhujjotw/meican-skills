#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXIT_CODE=0
PASS=0
FAIL=0

print_result() {
    local name="$1"
    local status="$2"
    if [[ "$status" -eq 0 ]]; then
        echo "  PASS  $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $name"
        FAIL=$((FAIL + 1))
        EXIT_CODE=1
    fi
}

echo "=== Meican Skill Verification ==="
echo ""

# 1. Check SKILL.md
echo "[Check] SKILL.md exists and is valid"
if [[ -f "$ROOT_DIR/.opencode/skills/meican/SKILL.md" ]]; then
    if head -1 "$ROOT_DIR/.opencode/skills/meican/SKILL.md" | grep -q "^---"; then
        print_result "SKILL.md front matter" 0
    else
        print_result "SKILL.md front matter" 1
    fi
else
    print_result "SKILL.md exists" 1
fi

# 2. Shell syntax check
echo "[Check] Shell script syntax"
for script in "$ROOT_DIR/scripts/"*.sh; do
    name=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
        print_result "Syntax: $name" 0
    else
        print_result "Syntax: $name" 1
    fi
done

# 3. Check env var coverage
echo "[Check] Environment variables in login.sh"
if grep -q "MEICAN_USERNAME" "$ROOT_DIR/scripts/login.sh" && \
   grep -q "MEICAN_PASSWORD" "$ROOT_DIR/scripts/login.sh"; then
    print_result "login.sh reads MEICAN_USERNAME and MEICAN_PASSWORD" 0
else
    print_result "login.sh reads env vars" 1
fi

# 4. Check .env.example
echo "[Check] .env.example"
if [[ -f "$ROOT_DIR/.env.example" ]]; then
    required_vars=("MEICAN_USERNAME" "MEICAN_PASSWORD" "MEICAN_TOKEN")
    all_found=0
    for var in "${required_vars[@]}"; do
        if grep -q "$var" "$ROOT_DIR/.env.example" 2>/dev/null; then
            :
        else
            echo "  MISSING: $var in .env.example"
            all_found=1
        fi
    done
    print_result ".env.example complete" $all_found
else
    print_result ".env.example exists" 1
fi

# 5. Check docs
echo "[Check] Documentation files"
for doc in "$ROOT_DIR/docs/usage.md"; do
    if [[ -f "$doc" ]]; then
        print_result "Doc: $(basename "$doc")" 0
    else
        print_result "Doc: $(basename "$doc")" 1
    fi
done

# 6. Check tests directory
echo "[Check] Tests directory"
if [[ -d "$ROOT_DIR/tests" ]]; then
    if ls "$ROOT_DIR/tests/"*.sh &>/dev/null 2>&1; then
        for t in "$ROOT_DIR/tests/"*.sh; do
            if bash -n "$t" 2>/dev/null; then
                print_result "Test syntax: $(basename "$t")" 0
            else
                print_result "Test syntax: $(basename "$t")" 1
            fi
        done
    else
        print_result "Tests directory (empty, ok)" 0
    fi
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
exit "$EXIT_CODE"

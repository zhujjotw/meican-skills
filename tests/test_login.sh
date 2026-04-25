#!/usr/bin/env bash
set -euo pipefail

echo "Test 1: login without env vars"
MEICAN_USERNAME="" MEICAN_PASSWORD="" \
  bash "$(dirname "$0")/../scripts/login.sh" 2>&1 && { echo "FAIL: should have errored"; exit 1; } || echo "PASS"

echo "Test 2: login script syntax check"
bash -n "$(dirname "$0")/../scripts/login.sh" && echo "PASS" || { echo "FAIL: syntax error"; exit 1; }

echo "Test 3: menu script syntax check"
bash -n "$(dirname "$0")/../scripts/menu.sh" && echo "PASS" || { echo "FAIL: syntax error"; exit 1; }

echo "Test 4: order script syntax check"
bash -n "$(dirname "$0")/../scripts/order.sh" && echo "PASS" || { echo "FAIL: syntax error"; exit 1; }

echo "Test 5: history script syntax check"
bash -n "$(dirname "$0")/../scripts/history.sh" && echo "PASS" || { echo "FAIL: syntax error"; exit 1; }

echo "Test 6: health script syntax check"
bash -n "$(dirname "$0")/../scripts/health.sh" && echo "PASS" || { echo "FAIL: syntax error"; exit 1; }

echo "All tests passed!"

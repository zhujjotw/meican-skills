#!/usr/bin/env bash
set -euo pipefail

COOKIE_FILE="${MEICAN_COOKIE_FILE:-/tmp/meican_cookie.txt}"
BASE_URL="https://meican.com"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

meican_login() {
    local username="${MEICAN_USERNAME:-}"
    local password="${MEICAN_PASSWORD:-}"

    if [[ -z "$username" ]]; then
        echo "Error: MEICAN_USERNAME is not set" >&2
        return 1
    fi
    if [[ -z "$password" ]]; then
        echo "Error: MEICAN_PASSWORD is not set" >&2
        return 1
    fi

    echo "Logging in as: $username"

    local resp
    resp=$(curl -s -c "$COOKIE_FILE" \
        -A "$USER_AGENT" \
        -d "username=${username}" \
        -d "password=${password}" \
        -d "loginType=username" \
        -d "remember=true" \
        "${BASE_URL}/account/directlogin")

    if echo "$resp" | grep -qiE "(用户名或密码错误|login fail)"; then
        echo "Error: Login failed — incorrect username or password" >&2
        rm -f "$COOKIE_FILE"
        return 1
    fi

    echo "Login successful, cookie saved to: $COOKIE_FILE"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    meican_login "$@"
fi

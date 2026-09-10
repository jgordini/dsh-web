#!/bin/sh
# Regenerate .env from the varlock global store (run after a key rotation).
set -eu
cd "$(dirname "$0")"
eval "$(varlock global --format shell --compact)"
[ -n "${DEEPSEEK_API_KEY:-}" ] || { echo "DEEPSEEK_API_KEY missing from varlock store" >&2; exit 1; }
umask 077
printf 'DEEPSEEK_API_KEY=%s\n' "$DEEPSEEK_API_KEY" > .env
chmod 600 .env
echo ".env refreshed ($(wc -c < .env | tr -d ' ') bytes)"

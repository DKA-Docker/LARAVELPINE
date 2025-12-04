#!/bin/sh
# URL health endpoint
URL="http://127.0.0.1/up"
# Cek endpoint /up harus HTTP 200
STATUS=$(wget -q --server-response --spider "$URL" 2>&1 | awk '/HTTP\/1/{print $2}' | tail -1)
[ "$STATUS" = "200" ] && exit 0 || exit 1

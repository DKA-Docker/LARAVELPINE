#!/bin/bash
set -e

ENV=${APP_ENV:-local}

# Cek dependencies penting
command -v composer >/dev/null 2>&1 || { echo >&2 "❌ Composer not found."; exit 1; }
command -v yarn >/dev/null 2>&1 || { echo >&2 "❌ Yarn not found."; exit 1; }


running_prod_server() {
  echo "🚀 Starting production server stack..."
  php-fpm83 -F &
  php_pid=$!
  nginx &
  nginx_pid=$!
  echo "📈 Monitoring PHP-FPM (PID: $php_pid) and Nginx (PID: $nginx_pid)"
  # Trap biar bisa shutdown bersih
  trap "echo '🛑 Caught signal, stopping...'; kill $php_pid $nginx_pid; exit 1" SIGTERM SIGINT
  # Tunggu salah satu mati (wait -n = tunggu 1 proses exit)
  wait -n
  echo "⚠️ One process exited. Shutting down the other..."
  kill $php_pid $nginx_pid
  # Tunggu keduanya selesai beneran sebelum exit
  wait
}

running_prod_server

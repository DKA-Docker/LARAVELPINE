#!/bin/bash
set -e

ENV=${APP_ENV:-local}
PHP_ENGINE=${DKA_PHP_OCTANE_ENGINE:-frankenphp}
PHP_MAX_REQUEST=${DKA_PHP_OCTANE_MAX_REQUEST:-1000}
PHP_WORKER=${DKA_PHP_OCTANE_WORKER:-4}
PHP_HOST=${DKA_INTERNAL_HOST:-0.0.0.0}
PHP_PORT=${DKA_INTERNAL_PORT:-80}
PHP_ADMIN_PORT=${DKA_INTERNAL_ADMIN_PORT:-2019}

# Cek dependencies penting
command -v composer >/dev/null 2>&1 || { echo >&2 "❌ Composer not found."; exit 1; }
command -v bun >/dev/null 2>&1 || { echo >&2 "❌ Bun not found."; exit 1; }

running_dev_server() {
  echo "🛠️ Running local dev servers..."
  if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
    echo "🟢 Starting Vite dev server..."
    bun run dev --host 0.0.0.0 --cors &  # Run Vite in background
  elif [ -f "webpack.mix.js" ]; then
    echo "🟢 Starting Laravel Mix watcher..."
    bun run watch --host 0.0.0.0 --cors &  # Run watcher in background
  else
    echo "⚠️ No dev server config detected."
  fi
  echo "🚀 Starting development queue stack..."
  php artisan queue:work --sleep=3 --tries=1 &
  echo "🚀 Starting development webserver stack..."
  [ -f "frankenphp" ] && chmod +x frankenphp
  php artisan octane:start --server=$PHP_ENGINE --host=$PHP_HOST --port=$PHP_PORT --admin-port=$PHP_ADMIN_PORT --watch --max-requests=1 --workers=1 || php artisan serve --host=$PHP_HOST --port=$PHP_PORT &
  echo "📈 Health monitoring active."
  wait
}

running_prod_server() {
  echo "🚀 Starting production queue stack..."
  php artisan queue:work --sleep=3 --tries=3 &
  echo "🚀 Starting production webserver stack..."
  [ -f "frankenphp" ] && chmod +x frankenphp
  php artisan octane:start --server=$PHP_ENGINE --max-requests=$PHP_MAX_REQUEST --workers=$PHP_WORKER --host=$PHP_HOST --port=$PHP_PORT --admin-port=$PHP_ADMIN_PORT &
  echo "📈 Health monitoring active."
  wait
}

running_server() {
  echo "🧭 Starting Laravel App in $ENV mode..."
  if [ "$ENV" = "production" ]; then
    running_prod_server
  else
    running_dev_server
  fi
}

running_server

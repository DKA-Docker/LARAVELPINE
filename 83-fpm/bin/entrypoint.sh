#!/bin/bash
set -e

# =============================================================================
# DKA Laravel Entrypoint — FPM variant
# =============================================================================
# wait -n memastikan jika salah satu proses mati, container ikut exit
# → Docker/K8s melakukan restart otomatis.
# =============================================================================

# --- Core Configurations ---
ENV=${APP_ENV:-local}
PHP_ENGINE=${DKA_PHP_OCTANE_ENGINE:-frankenphp}
PHP_MAX_REQUEST=${DKA_PHP_OCTANE_MAX_REQUEST:-1000}
PHP_WORKER=${DKA_PHP_OCTANE_WORKER:-4}
PHP_HOST=${DKA_INTERNAL_HOST:-0.0.0.0}
PHP_PORT=${DKA_INTERNAL_PORT:-80}
PHP_ADMIN_PORT=${DKA_INTERNAL_ADMIN_PORT:-2019}

# --- Logger ---
log()  { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;32mINFO\033[0m  ▶ $1"; }
warn() { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;33mWARN\033[0m  ▶ $1"; }
err()  { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;31mERROR\033[0m ▶ $1"; }

# --- System Info ---
LARAVEL_VER=$(php artisan --version 2>/dev/null | awk '{print $3}')
MEM_USAGE=$([ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ] \
  && awk '{printf "%.2f MB", $1/1024/1024}' /sys/fs/cgroup/memory/memory.usage_in_bytes \
  || free -m | awk '/Mem:/ { print $3 " MB" }')

echo "╔══════════════════════════════════════════════════╗"
log  " Laravel : v$LARAVEL_VER  |  Env: $ENV  |  RAM: $MEM_USAGE"
log  " Mode    : FPM + Octane"
echo "╚══════════════════════════════════════════════════╝"

# --- Graceful Shutdown ---
cleanup() {
  log "🛑 Shutting down gracefully..."
  local pids
  pids=$(jobs -p 2>/dev/null)
  if [ -n "$pids" ]; then
    kill -TERM $pids 2>/dev/null || true
    sleep 5
    kill -KILL $pids 2>/dev/null || true
  fi
  wait 2>/dev/null || true
  log "✅ All processes stopped."
  exit 0
}

trap cleanup SIGINT SIGTERM

# --- Pre-flight Checks ---
command -v composer >/dev/null 2>&1 || { err "Composer not found."; exit 1; }
command -v bun      >/dev/null 2>&1 || { err "Bun not found.";      exit 1; }

# --- Start ---
[ -f "frankenphp" ] && chmod +x frankenphp

if [ "$ENV" = "production" ]; then
  log "⚙️  Starting Queue Worker..."
  php artisan queue:work --sleep=3 --tries=3 &

  log "🚀 Starting Octane [production] on $PHP_HOST:$PHP_PORT..."
  (
    php artisan octane:start \
      --server="$PHP_ENGINE" \
      --host="$PHP_HOST" \
      --port="$PHP_PORT" \
      --admin-port="$PHP_ADMIN_PORT" \
      --max-requests="$PHP_MAX_REQUEST" \
      --workers="$PHP_WORKER" \
    || {
      warn "Octane failed. Falling back to 'php artisan serve'..."
      php artisan serve --host="$PHP_HOST" --port="$PHP_PORT"
    }
  ) &
else
  if [ -d "node_modules" ]; then
    if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
      log "🟢 Starting Vite..."
      bun run dev -- --host 0.0.0.0 --cors &
    elif [ -f "webpack.mix.js" ]; then
      log "🟢 Starting Laravel Mix..."
      bun run watch -- --host 0.0.0.0 --cors &
    fi
  fi

  log "⚙️  Starting Queue Worker [dev]..."
  php artisan queue:work --sleep=3 --tries=1 &

  log "🚀 Starting Octane [dev/watch] on $PHP_HOST:$PHP_PORT..."
  (
    php artisan octane:start \
      --server="$PHP_ENGINE" \
      --host="$PHP_HOST" \
      --port="$PHP_PORT" \
      --admin-port="$PHP_ADMIN_PORT" \
      --watch \
      --max-requests=1 \
      --workers=1 \
    || {
      warn "Octane failed. Falling back to 'php artisan serve'..."
      php artisan serve --host="$PHP_HOST" --port="$PHP_PORT"
    }
  ) &
fi

log "📈 All services running. Monitoring via wait -n (event-driven)..."

wait -n 2>/dev/null || true

err "⚠️  A process exited unexpectedly. Container will stop."
cleanup

#!/bin/bash
set -e

# =============================================================================
# DKA Laravel Entrypoint — 82-fpm (Nginx + PHP-FPM)
# =============================================================================
# wait -n: jika nginx atau php-fpm mati, container exit → Docker restart.
# =============================================================================

log()  { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;32mINFO\033[0m  ▶ $1"; }
warn() { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;33mWARN\033[0m  ▶ $1"; }
err()  { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;31mERROR\033[0m ▶ $1"; }

MEM_USAGE=$([ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ] \
  && awk '{printf "%.2f MB", $1/1024/1024}' /sys/fs/cgroup/memory/memory.usage_in_bytes \
  || free -m | awk '/Mem:/ { print $3 " MB" }')

echo "╔══════════════════════════════════════════════════╗"
log  " Mode  : Nginx + PHP-FPM  |  RAM: $MEM_USAGE"
echo "╚══════════════════════════════════════════════════╝"

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

log "🐘 Starting PHP-FPM..."
php-fpm83 -F &

log "🌐 Starting Nginx..."
nginx &

# Jika dipanggil dengan argumen (exec override), jalankan argumen tsb
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

log "📈 Monitoring via wait -n (event-driven)..."

wait -n 2>/dev/null || true

err "⚠️  A process exited. Container will stop."
cleanup

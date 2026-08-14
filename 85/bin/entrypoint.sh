#!/bin/bash
set -e

# --- Configurations ---
ENV=${APP_ENV:-local}
PHP_ENGINE=${DKA_PHP_OCTANE_ENGINE:-frankenphp}
PHP_MAX_REQUEST=${DKA_PHP_OCTANE_MAX_REQUEST:-1000}
PHP_WORKER=${DKA_PHP_OCTANE_WORKER:-4}
PHP_HOST=${DKA_INTERNAL_HOST:-0.0.0.0}
PHP_PORT=${DKA_INTERNAL_PORT:-80}
PHP_ADMIN_PORT=${DKA_INTERNAL_ADMIN_PORT:-2019}

# --- System Info & Logger ---
log() {
  echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;32mINFO\033[0m ▶ $1"
}

# Resource detection (LXC/Docker/K8s friendly)
LARAVEL_VER=$(php artisan --version 2>/dev/null | awk '{print $3}')
MEM_USAGE=$([ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ] && awk '{printf "%.2f MB", $1/1024/1024}' /sys/fs/cgroup/memory/memory.usage_in_bytes || free -m | awk '/Mem:/ { print $3 " MB" }')
CPU_LOAD=$(top -bn1 | grep "CPU" | awk '{print $2 + $4 "%"}' | head -n1)

echo "--------------------------------------------------------"
log "Laravel: v$LARAVEL_VER | Env: $ENV"
log "System: CPU $CPU_LOAD | RAM $MEM_USAGE"
echo "--------------------------------------------------------"

# --- Process Management ---
# Fungsi untuk mematikan semua background process saat container distop
cleanup() {
  log "🛑 Shutting down gracefully..."
  kill $(jobs -p) 2>/dev/null
  exit 0
}

# Trap signals for Docker/K8s/LXC
trap cleanup SIGINT SIGTERM

# Check dependencies
command -v composer >/dev/null 2>&1 || { log "❌ Composer not found."; exit 1; }
command -v bun >/dev/null 2>&1 || { log "❌ Bun not found."; exit 1; }

# Fungsi untuk cek apakah perintah Artisan tersedia
has_artisan_command() {
  php artisan list | grep "$1" > /dev/null 2>&1
}

running_dev_server() {
  log "🛠️ Starting local dev stack..."
  if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
    log "🟢 Starting Vite..."
    bun run dev -- --host 0.0.0.0 --cors &
  elif [ -f "webpack.mix.js" ]; then
    log "🟢 Starting Laravel Mix..."
    bun run watch -- --host 0.0.0.0 --cors &
  fi

  # --- Tambahan untuk Reverb ---
  if has_artisan_command "reverb:start"; then
    log "📡 Starting Reverb server (debug mode)..."
    php artisan reverb:start --debug &
  fi
  # -----------------------------


  # --- Tambahan untuk WhatsApp ---
  if has_artisan_command "whatsapp:web:listen"; then
    log "💬 Starting WhatsApp sidecar and listener (debug mode)..."
    php artisan whatsapp:sidecar:start &
    sleep 2
    php artisan whatsapp:web:listen &
  fi
  # -----------------------------

  log "🚀 Starting Queue & Octane (Watch Mode)..."
  php artisan queue:work --sleep=3 --tries=1 &
  [ -f "frankenphp" ] && chmod +x frankenphp
  # Versi dengan failback tetap terjaga
  php artisan octane:start --server=$PHP_ENGINE --host=$PHP_HOST --port=$PHP_PORT --admin-port=$PHP_ADMIN_PORT --watch --max-requests=1 --workers=1 \
  || php artisan serve --host=$PHP_HOST --port=$PHP_PORT &
}

running_prod_server() {
  # --- Tambahan untuk Reverb ---
  if has_artisan_command "reverb:start"; then
    log "📡 Starting Reverb server..."
    php artisan reverb:start &
  fi
  # -----------------------------


  # --- Tambahan untuk WhatsApp ---
  if has_artisan_command "whatsapp:web:listen"; then
    log "💬 Starting WhatsApp sidecar and listener..."
    php artisan whatsapp:sidecar:start &
    sleep 2
    php artisan whatsapp:web:listen &
  fi
  # -----------------------------

  log "🚀 Starting production stack..."
  php artisan queue:work --sleep=3 --tries=3 &

  [ -f "frankenphp" ] && chmod +x frankenphp
  php artisan octane:start --server=$PHP_ENGINE --max-requests=$PHP_MAX_REQUEST --workers=$PHP_WORKER --host=$PHP_HOST --port=$PHP_PORT --admin-port=$PHP_ADMIN_PORT &
}

# --- Execution ---
if [ "$ENV" = "production" ]; then
  running_prod_server
else
  running_dev_server
fi

log "📈 Service is up and monitoring."

# Pengganti 'wait' statis: Loop efisien yang responsif terhadap signal
# Script akan tetap jalan selama ada background jobs
while jobs > /dev/null 2>&1; do
  sleep 2
done

log "⚠️ All processes have exited."
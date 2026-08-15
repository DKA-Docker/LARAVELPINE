#!/bin/bash
set -e

# =============================================================================
# DKA Laravel Entrypoint — Optimized Process Manager
# =============================================================================
#
# Process Feature Flags (all default: false = DISABLED)
#   DKA_ENABLE_QUEUE      → php artisan queue:work
#   DKA_ENABLE_VITE       → bun run dev / watch  (dev env only)
#   DKA_ENABLE_REVERB     → php artisan reverb:start
#   DKA_ENABLE_WHATSAPP   → php artisan whatsapp:sidecar:start + whatsapp:web:listen
#   DKA_ENABLE_SCHEDULER  → php artisan schedule:work
#
# Web server (Octane / artisan serve) is ALWAYS ON and cannot be disabled.
#
# Design notes:
#   - All optional processes run in the background (&).
#   - The web server runs in the FOREGROUND as the "critical" process.
#     If it exits/crashes, the entrypoint exits → Docker/K8s restarts the container.
#   - cleanup() sends SIGTERM → waits 5s → SIGKILL to all child processes.
# =============================================================================

# --- Core Configurations ---
ENV=${APP_ENV:-local}
PHP_ENGINE=${DKA_PHP_OCTANE_ENGINE:-frankenphp}
PHP_MAX_REQUEST=${DKA_PHP_OCTANE_MAX_REQUEST:-1000}
PHP_WORKER=${DKA_PHP_OCTANE_WORKER:-4}
PHP_HOST=${DKA_INTERNAL_HOST:-0.0.0.0}
PHP_PORT=${DKA_INTERNAL_PORT:-80}
PHP_ADMIN_PORT=${DKA_INTERNAL_ADMIN_PORT:-2019}

# --- Process Feature Flags ---
DKA_ENABLE_OCTANE=${DKA_ENABLE_OCTANE:-true}       # Web server — default ON
DKA_ENABLE_QUEUE=${DKA_ENABLE_QUEUE:-false}
DKA_ENABLE_VITE=${DKA_ENABLE_VITE:-false}
DKA_ENABLE_REVERB=${DKA_ENABLE_REVERB:-false}
DKA_ENABLE_WHATSAPP=${DKA_ENABLE_WHATSAPP:-false}
DKA_ENABLE_SCHEDULER=${DKA_ENABLE_SCHEDULER:-false}

# --- Logger ---
log()  { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;32mINFO\033[0m  ▶ $1"; }
warn() { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;33mWARN\033[0m  ▶ $1"; }
err()  { echo -e "\e[90m$(date +'%H:%M:%S')\e[0m \033[0;31mERROR\033[0m ▶ $1"; }

# --- System Info ---
LARAVEL_VER=$(php artisan --version 2>/dev/null | awk '{print $3}')
MEM_USAGE=$([ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ] \
  && awk '{printf "%.2f MB", $1/1024/1024}' /sys/fs/cgroup/memory/memory.usage_in_bytes \
  || free -m | awk '/Mem:/ { print $3 " MB" }')
CPU_LOAD=$(top -bn1 | grep "CPU" | awk '{print $2 + $4 "%"}' | head -n1)

_on()  { echo -e "\033[0;32m ON\033[0m"; }
_off() { echo -e "\033[0;90moff\033[0m"; }

echo "╔══════════════════════════════════════════════════╗"
log  " Laravel    : v$LARAVEL_VER  |  Env: $ENV"
log  " System     : CPU $CPU_LOAD  |  RAM $MEM_USAGE"
log  " Processes  :"
log  "   octane / serve  →  $([ "$DKA_ENABLE_OCTANE"   = "true" ] && _on || _off)  [DKA_ENABLE_OCTANE]"
log  "   queue:work      →  $([ "$DKA_ENABLE_QUEUE"     = "true" ] && _on || _off)  [DKA_ENABLE_QUEUE]"
log  "   reverb:start    →  $([ "$DKA_ENABLE_REVERB"    = "true" ] && _on || _off)  [DKA_ENABLE_REVERB]"
log  "   whatsapp        →  $([ "$DKA_ENABLE_WHATSAPP"  = "true" ] && _on || _off)  [DKA_ENABLE_WHATSAPP]"
log  "   schedule:work   →  $([ "$DKA_ENABLE_SCHEDULER" = "true" ] && _on || _off)  [DKA_ENABLE_SCHEDULER]"
if [ "$ENV" != "production" ]; then
  log "   vite / mix      →  $([ "$DKA_ENABLE_VITE" = "true" ] && _on || _off)  [DKA_ENABLE_VITE]"
fi
echo "╚══════════════════════════════════════════════════╝"

# --- Graceful Shutdown ---
cleanup() {
  log "🛑 Shutting down gracefully..."
  local pids
  pids=$(jobs -p 2>/dev/null)
  if [ -n "$pids" ]; then
    # Portable kill — tidak pakai xargs -r karena busybox tidak mengenal flag -r
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

# Cache artisan command list sekali — menghindari multiple Laravel boots
# (setiap php artisan list ~200-500ms)
ARTISAN_LIST=$(php artisan list 2>/dev/null)

has_artisan_command() {
  echo "$ARTISAN_LIST" | grep -q "$1"
}

is_enabled() { [ "$1" = "true" ]; }

# --- Background Processes ---
start_background_processes() {
  local MODE=$1  # "dev" or "prod"

  # ── Vite / Laravel Mix (dev only) ─────────────────────────────────────────
  if [ "$MODE" = "dev" ] && is_enabled "$DKA_ENABLE_VITE"; then
    if [ -d "node_modules" ]; then
      if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
        log "🟢 Starting Vite..."
        bun run dev -- --host 0.0.0.0 --cors &
      elif [ -f "webpack.mix.js" ]; then
        log "🟢 Starting Laravel Mix..."
        bun run watch -- --host 0.0.0.0 --cors &
      fi
    else
      warn "node_modules not found. Skipping Vite/Mix. Run: bun install"
    fi
  fi

  # ── Queue Worker ───────────────────────────────────────────────────────────
  if is_enabled "$DKA_ENABLE_QUEUE"; then
    log "⚙️  Starting Queue Worker..."
    if [ "$MODE" = "dev" ]; then
      php artisan queue:work --sleep=3 --tries=1 &
    else
      php artisan queue:work --sleep=3 --tries=3 &
    fi
  fi

  # ── Laravel Reverb (WebSocket) ─────────────────────────────────────────────
  if is_enabled "$DKA_ENABLE_REVERB" && has_artisan_command "reverb:start"; then
    log "📡 Starting Reverb WebSocket Server..."
    if [ "$MODE" = "dev" ]; then
      php artisan reverb:start --debug &
    else
      php artisan reverb:start &
    fi
  fi

  # ── WhatsApp Sidecar ───────────────────────────────────────────────────────
  if is_enabled "$DKA_ENABLE_WHATSAPP" && has_artisan_command "whatsapp:web:listen"; then
    log "💬 Starting WhatsApp Sidecar..."
    php artisan whatsapp:sidecar:start &
    # Poll health sidecar sampai siap (max 15 detik), lebih reliable dari sleep hardcoded
    _wa_timeout=15
    until php artisan whatsapp:health --exit-code >/dev/null 2>&1 || [ "$_wa_timeout" -eq 0 ]; do
      sleep 1
      _wa_timeout=$((_wa_timeout - 1))
    done
    [ "$_wa_timeout" -eq 0 ] && warn "WhatsApp sidecar health check timed out, starting listener anyway..."
    php artisan whatsapp:web:listen &
  fi

  # ── Laravel Scheduler ─────────────────────────────────────────────────────
  if is_enabled "$DKA_ENABLE_SCHEDULER" && has_artisan_command "schedule:work"; then
    log "🕐 Starting Laravel Scheduler..."
    php artisan schedule:work &
  fi
}

# --- Web Server (BACKGROUND — runs alongside other processes) ---
# Uses a subshell (...)& so the octane→serve fallback stays contained
# in one job. If both fail, the subshell exits → wait -n triggers → container restarts.
start_web_server() {
  local MODE=$1

  [ -f "frankenphp" ] && chmod +x frankenphp

  if [ "$MODE" = "dev" ]; then
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
  else
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
  fi
}

# --- Main Execution ---
# All processes (including Octane) run as background jobs (&).
# wait -n is event-driven (OS SIGCHLD) — zero CPU polling.
# The FIRST process to die triggers cleanup → container exits → Docker/K8s restarts.
# This catches all failure modes uniformly: Octane crash, worker crash, etc.

if [ "$ENV" = "production" ]; then
  start_background_processes "prod"
  is_enabled "$DKA_ENABLE_OCTANE" && start_web_server "prod"
else
  start_background_processes "dev"
  is_enabled "$DKA_ENABLE_OCTANE" && start_web_server "dev"
fi

# Guard: if nothing was started, bail out
if [ -z "$(jobs -p 2>/dev/null)" ]; then
  err "No processes were enabled. Set at least one DKA_ENABLE_* to true."
  exit 1
fi

log "📈 All services running. Monitoring via wait -n (event-driven)..."

# Block here until any ONE child process exits
wait -n 2>/dev/null || true

err "⚠️  A process exited unexpectedly. Container will stop and be restarted by Docker/K8s."
cleanup

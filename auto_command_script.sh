#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/pipeline.log"

mkdir -p "$LOG_DIR"
cd "$SCRIPT_DIR"

log() {
    printf '%s %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

run_step() {
  local name="$1"
  shift
  log "START $name"
  local start_sec
  start_sec=$(date +%s)
  if "$@" 2>&1 | tee -a "$LOG_FILE"; then
    local status=0
  else
    local status=$?
  fi
  local end_sec
  end_sec=$(date +%s)
  local duration=$((end_sec - start_sec))
  if [[ $status -ne 0 ]]; then
    log "ERROR $name exited with status=$status after ${duration}s"
    return $status
  fi
  log "END   $name duration=${duration}s"
}

log "PIPELINE START"
run_step "main" python3 -u "$SCRIPT_DIR/main.py"
log "PIPELINE COMPLETE"

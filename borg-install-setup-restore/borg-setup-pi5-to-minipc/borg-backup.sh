#!/usr/bin/env bash
set -euo pipefail

########## CONFIG ##########

# Immich media location on Pi5
UPLOAD_LOCATION="/data/media/photos/library"

# Local backup storage on Pi5 (repo on Pi-attached HDD or local storage)
# Change this if your local backup disk is mounted elsewhere.
LOCAL_REPO_DIR="/home/pi5/immich-backups/immich-borg"

# Local working area on Pi5 for logs and DB dumps
LOCAL_BACKUP_ROOT="/home/pi5/immich-backups"
LOG_ROOT="${LOCAL_BACKUP_ROOT}/logs"

# Database dump settings
DB_USERNAME="postgres"
PG_CONTAINER="immich_postgres"
DB_DUMP_DIR="${LOCAL_BACKUP_ROOT}/db-dumps"
DB_DUMP_FILE="${DB_DUMP_DIR}/immich-database.sql"

# Remote mini-PC SSH targets from ~/.ssh/config
REMOTE_SSH_HOST_LAN="pc"
REMOTE_SSH_HOST_TS="pc-ca"

# Remote username (mainly for rsync target formatting)
REMOTE_USER="hossein"

# Borg repository path on mini-PC
REMOTE_REPO_PATH="/data/borg/immich-borg"

# Standalone DB dump copies on mini-PC
REMOTE_DB_DIR="/data/borg/db-dumps"
REMOTE_DB_KEEP=10

# Borg settings
BORG_REMOTE_PATH="borg"
BORG_COMPRESSION="lz4"
BORG_PRUNE_OPTS=(--keep-weekly=4 --keep-monthly=3)
SSH_CONNECT_TIMEOUT=5

########## END CONFIG ##########

MODE="${1:-both}"   # local | remote | both
STAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

mkdir -p "$LOG_ROOT" "$DB_DUMP_DIR"
LOG_FILE="${LOG_ROOT}/${STAMP}_${MODE}.log"

timestamp_output() {
  while IFS= read -r line; do
    echo "$(date -Is) $line"
  done
}

log() {
  echo "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 127
  }
}

pick_remote_host() {
  if ssh -o BatchMode=yes -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
    "${REMOTE_SSH_HOST_LAN}" "true" >/dev/null 2>&1; then
    echo "${REMOTE_SSH_HOST_LAN}"
    return 0
  fi

  if ssh -o BatchMode=yes -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
    "${REMOTE_SSH_HOST_TS}" "true" >/dev/null 2>&1; then
    echo "${REMOTE_SSH_HOST_TS}"
    return 0
  fi

  return 1
}

do_dump() {
  log "[DB] Dumping Postgres from container '${PG_CONTAINER}'..."
  mkdir -p "$DB_DUMP_DIR"

  docker exec -t "$PG_CONTAINER" \
    pg_dumpall --clean --if-exists --username="$DB_USERNAME" \
    > "$DB_DUMP_FILE"

  log "[DB] Dump saved to $DB_DUMP_FILE"
}

do_local() {
  log "[LOCAL] Creating archive..."
  borg create \
    --stats \
    --show-rc \
    --compression "$BORG_COMPRESSION" \
    "${LOCAL_REPO_DIR}::{hostname}-${STAMP}" \
    "$UPLOAD_LOCATION" \
    "$DB_DUMP_FILE"

  log "[LOCAL] Pruning old archives..."
  borg prune \
    --show-rc \
    "${BORG_PRUNE_OPTS[@]}" \
    "$LOCAL_REPO_DIR"

  log "[LOCAL] Compacting repo..."
  borg compact --show-rc "$LOCAL_REPO_DIR"
}

do_remote_copy_db() {
  local ssh_host="$1"
  local remote_file="${REMOTE_DB_DIR}/immich-database-${STAMP}.sql"
  local prune_start=$((REMOTE_DB_KEEP + 1))

  log "[REMOTE-DB] Ensuring remote DB dump directory exists..."
  ssh "$ssh_host" "mkdir -p '${REMOTE_DB_DIR}'"

  log "[REMOTE-DB] Copying DB dump to ${ssh_host}:${remote_file} ..."
  rsync -t "$DB_DUMP_FILE" "${ssh_host}:${remote_file}"

  log "[REMOTE-DB] Pruning old standalone DB dumps..."
  ssh "$ssh_host" "
    sh -lc 'cd \"${REMOTE_DB_DIR}\" &&
    ls -1t immich-database-*.sql 2>/dev/null |
    tail -n +${prune_start} |
    xargs -r rm --'
  "
}

do_remote() {
  local ssh_host="$1"
  local repo="${ssh_host}:${REMOTE_REPO_PATH}"

  export BORG_REMOTE_PATH
  export BORG_RSH="ssh"

  log "[REMOTE] Creating archive on ${repo} ..."
  borg create \
    --stats \
    --show-rc \
    --compression "$BORG_COMPRESSION" \
    "${repo}::{hostname}-${STAMP}" \
    "$UPLOAD_LOCATION" \
    "$DB_DUMP_FILE"

  log "[REMOTE] Pruning old archives..."
  borg prune \
    --show-rc \
    "${BORG_PRUNE_OPTS[@]}" \
    "$repo"

  log "[REMOTE] Compacting repo..."
  borg compact --show-rc "$repo"
}

main() {
  require_cmd borg
  require_cmd docker
  require_cmd ssh
  require_cmd rsync

  if [[ -z "${BORG_PASSCOMMAND:-}" && -z "${BORG_PASSPHRASE:-}" ]]; then
    log "[WARN] BORG_PASSCOMMAND/BORG_PASSPHRASE is not set."
    log "[WARN] Encrypted repo operations will prompt for a passphrase."
  fi

  log "=== $(date -Is) Immich Borg backup start (mode=${MODE}) ==="

  do_dump

  case "$MODE" in
    local)
      do_local
      ;;
    remote)
      host="$(pick_remote_host)" || {
        log "[REMOTE] Could not reach mini-PC via LAN alias '${REMOTE_SSH_HOST_LAN}' or Tailscale alias '${REMOTE_SSH_HOST_TS}'."
        exit 3
      }
      log "[REMOTE] Using host alias: ${host}"
      do_remote_copy_db "$host"
      do_remote "$host"
      ;;
    both)
      host="$(pick_remote_host)" || {
        log "[REMOTE] Could not reach mini-PC via LAN alias '${REMOTE_SSH_HOST_LAN}' or Tailscale alias '${REMOTE_SSH_HOST_TS}'."
        exit 3
      }
      log "[REMOTE] Using host alias: ${host}"
      do_remote_copy_db "$host"
      do_local
      do_remote "$host"
      ;;
    *)
      echo "Usage: $0 {local|remote|both}" >&2
      exit 2
      ;;
  esac

  log "=== $(date -Is) Done (mode=${MODE}) ==="
}

main 2>&1 | timestamp_output >> "$LOG_FILE"
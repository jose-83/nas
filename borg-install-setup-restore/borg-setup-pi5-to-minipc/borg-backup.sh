#!/usr/bin/env bash
set -euo pipefail

########## CONFIG ##########
export BORG_PASSPHRASE=$(sudo cat /root/.config/borg/passphrase)

# Immich media location on Pi5
UPLOAD_LOCATION="/data/media/photos/library"

# Local Borg repo on Pi5
LOCAL_REPO_DIR="/hdd12tb/borg"

# Local working area on Pi5
LOCAL_BACKUP_ROOT="/home/pi5/immich-backups"
LOG_ROOT="${LOCAL_BACKUP_ROOT}/logs"

# Database dump settings
DB_USERNAME="postgres"
PG_CONTAINER="immich_postgres"
DB_DUMP_DIR="${LOCAL_BACKUP_ROOT}/db-dumps"
DB_DUMP_FILE="${DB_DUMP_DIR}/immich-database.sql"

# Optional retention for local standalone DB dumps
LOCAL_DB_KEEP=8

# Remote mini-PC SSH aliases from ~/.ssh/config
REMOTE_SSH_HOST_LAN="pc"
REMOTE_SSH_HOST_TS="pc-ca"

# Remote storage paths on mini-PC
REMOTE_REPO_PATH="/data/borg/immich-borg"
REMOTE_DB_DIR="/data/borg/db-dumps"
REMOTE_DB_KEEP=8

# Borg settings
BORG_REMOTE_PATH="borg"
BORG_COMPRESSION="lz4"
BORG_PRUNE_OPTS=(--keep-weekly=4 --keep-monthly=3)
SSH_CONNECT_TIMEOUT=5

########## END CONFIG ##########

MODE="${1:-}"
STAMP="$(date +'%Y-%m-%d_%H-%M-%S')"

mkdir -p "$LOG_ROOT" "$DB_DUMP_DIR"
LOG_FILE="${LOG_ROOT}/${STAMP}_${MODE:-unknown}.log"

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

usage() {
  cat <<'EOF'
Usage:
  immich_borg_backup.sh local       # media only -> local Borg repo
  immich_borg_backup.sh remote      # media only -> remote Borg repo
  immich_borg_backup.sh local_db    # DB only -> local dump storage
  immich_borg_backup.sh remote_db   # DB only -> remote dump storage
EOF
}

pick_remote_host() {
  if ssh -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
    "${REMOTE_SSH_HOST_LAN}" "exit 0" >/dev/null 2>&1; then
    echo "${REMOTE_SSH_HOST_LAN}"
    return 0
  fi

  if ssh -o ConnectTimeout="${SSH_CONNECT_TIMEOUT}" \
    "${REMOTE_SSH_HOST_TS}" "exit 0" >/dev/null 2>&1; then
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

prune_local_db_dumps() {
  local keep="${LOCAL_DB_KEEP}"
  local prune_start=$((keep + 1))

  log "[LOCAL-DB] Pruning old local DB dumps (keep ${keep})..."
  (
    cd "$DB_DUMP_DIR" &&
    ls -1t immich-database-*.sql 2>/dev/null | tail -n +"${prune_start}" | xargs -r rm --
  )
}

rotate_current_dump_to_timestamped_local_copy() {
  local local_copy="${DB_DUMP_DIR}/immich-database-${STAMP}.sql"
  cp -f "$DB_DUMP_FILE" "$local_copy"
  log "[LOCAL-DB] Timestamped DB copy saved to $local_copy"
}

do_local_media() {
  log "[LOCAL] Creating media archive..."
  borg create \
    --stats \
    --show-rc \
    --compression "$BORG_COMPRESSION" \
    "${LOCAL_REPO_DIR}::{hostname}-${STAMP}" \
    "$UPLOAD_LOCATION"

  log "[LOCAL] Pruning old archives..."
  borg prune \
    --show-rc \
    "${BORG_PRUNE_OPTS[@]}" \
    "$LOCAL_REPO_DIR"

  log "[LOCAL] Compacting repo..."
  borg compact --show-rc "$LOCAL_REPO_DIR"
}

do_remote_media() {
  local ssh_host="$1"
  local repo="${ssh_host}:${REMOTE_REPO_PATH}"

  export BORG_REMOTE_PATH
  export BORG_RSH="ssh"

  log "[REMOTE] Creating media archive on ${repo} ..."
  borg create \
    --stats \
    --show-rc \
    --compression "$BORG_COMPRESSION" \
    "${repo}::{hostname}-${STAMP}" \
    "$UPLOAD_LOCATION"

  log "[REMOTE] Pruning old archives..."
  borg prune \
    --show-rc \
    "${BORG_PRUNE_OPTS[@]}" \
    "$repo"

  log "[REMOTE] Compacting repo..."
  borg compact --show-rc "$repo"
}

do_remote_db() {
  local ssh_host="$1"
  local remote_file="${REMOTE_DB_DIR}/immich-database-${STAMP}.sql"
  local prune_start=$((REMOTE_DB_KEEP + 1))

  log "[REMOTE-DB] Ensuring remote DB dump directory exists..."
  ssh "$ssh_host" "mkdir -p '${REMOTE_DB_DIR}'"

  log "[REMOTE-DB] Copying DB dump to ${ssh_host}:${remote_file} ..."
  rsync -t "$DB_DUMP_FILE" "${ssh_host}:${remote_file}"

  log "[REMOTE-DB] Pruning old remote DB dumps (keep ${REMOTE_DB_KEEP})..."
  ssh "$ssh_host" "
    sh -lc 'cd \"${REMOTE_DB_DIR}\" &&
    ls -1t immich-database-*.sql 2>/dev/null |
    tail -n +${prune_start} |
    xargs -r rm --'
  "
}

main() {
  require_cmd borg
  require_cmd docker
  require_cmd ssh
  require_cmd rsync

  case "${MODE}" in
    local)
      if [[ -z "${BORG_PASSCOMMAND:-}" && -z "${BORG_PASSPHRASE:-}" ]]; then
        log "[WARN] BORG_PASSCOMMAND/BORG_PASSPHRASE is not set."
        log "[WARN] Borg may prompt for the repository passphrase."
      fi
      log "=== $(date -Is) Immich media backup start (mode=local) ==="
      do_local_media
      log "=== $(date -Is) Done (mode=local) ==="
      ;;
    remote)
      if [[ -z "${BORG_PASSCOMMAND:-}" && -z "${BORG_PASSPHRASE:-}" ]]; then
        log "[WARN] BORG_PASSCOMMAND/BORG_PASSPHRASE is not set."
        log "[WARN] Borg may prompt for the repository passphrase."
      fi
      log "=== $(date -Is) Immich media backup start (mode=remote) ==="
      host="$(pick_remote_host)" || {
        log "[REMOTE] Could not reach mini-PC via LAN alias '${REMOTE_SSH_HOST_LAN}' or Tailscale alias '${REMOTE_SSH_HOST_TS}'."
        exit 3
      }
      log "[REMOTE] Using host alias: ${host}"
      do_remote_media "$host"
      log "=== $(date -Is) Done (mode=remote) ==="
      ;;
    local_db)
      log "=== $(date -Is) Immich DB backup start (mode=local_db) ==="
      do_dump
      rotate_current_dump_to_timestamped_local_copy
      prune_local_db_dumps
      log "=== $(date -Is) Done (mode=local_db) ==="
      ;;
    remote_db)
      log "=== $(date -Is) Immich DB backup start (mode=remote_db) ==="
      host="$(pick_remote_host)" || {
        log "[REMOTE-DB] Could not reach mini-PC via LAN alias '${REMOTE_SSH_HOST_LAN}' or Tailscale alias '${REMOTE_SSH_HOST_TS}'."
        exit 3
      }
      log "[REMOTE-DB] Using host alias: ${host}"
      do_dump
      do_remote_db "$host"
      log "=== $(date -Is) Done (mode=remote_db) ==="
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main 2>&1 | tee -a "$LOG_FILE"
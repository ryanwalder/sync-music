#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ -n "${PUID:-}" ]] && [[ -n "${PGID:-}" ]]; then

  # Check if group exists
  if ! getent group appuser >/dev/null; then
    groupadd -g "${PGID}" appuser
  fi

  # Check if user exists
  if ! id appuser >/dev/null 2>&1; then
    useradd -u "${PUID}" -g "${PGID}" -m appuser
  fi

  # Ensure proper ownership of mounted volumes
  chown appuser:appuser /output

  # Set default values for environment variables
  export INPUT_DIR="${INPUT_DIR:-/input}"
  export OUTPUT_DIR="${OUTPUT_DIR:-/output}"
  export LOG_LEVEL="${LOG_LEVEL:-INFO}"
  export LAME_QUALITY="${LAME_QUALITY:-0}"
  export LOOP="${LOOP:-true}"
  export SLEEP_TIME="${SLEEP_TIME:-900}"
  export STABILITY_CHECK_TIME="${STABILITY_CHECK_TIME:-2}"
  export MAX_WAIT_TIME="${MAX_WAIT_TIME:-300}"

  # Ensure UMASK is in correct octal format
  UMASK_VALUE="${UMASK:-0022}"
  if [[ ! "${UMASK_VALUE}" =~ ^0[0-7]{3}$ ]]; then
    echo "Invalid UMASK format: ${UMASK_VALUE}. Using default 0022" >&2
    UMASK_VALUE="0022"
  fi

  exec su-exec appuser:appuser sh -c "umask ${UMASK_VALUE} && exec /usr/local/bin/sync-music.sh"
else
  echo "PUID and PGID must be set." >&2
  exit 1
fi

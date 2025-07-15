#!/usr/bin/env bash
set -euo pipefail

# Convert/move audio files from INPUT_DIR to OUTPUT_DIR
#   Converts FLAC > MP3
#   Copies MP3s
#   Removes files from OUTPUT_DIR if deleted from INPUT_DIR

# Global variables
INPUT_DIR="${INPUT_DIR:-/input}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
LAME_QUALITY="${LAME_QUALITY:-0}"
LOOP="${LOOP:-true}"
SLEEP_TIME="${SLEEP_TIME:-900}"

declare -A LOG_LEVELS=(["ERROR"]=0 ["WARN"]=1 ["INFO"]=2 ["DEBUG"]=3)
LOG_LEVEL="${LOG_LEVEL:-INFO}"
TMP_DIR=$(mktemp -d)

# Logging helper
log() {
  local level
  local message

  level=${1^^}
  message="$2"

  if [[ ${LOG_LEVELS[$level]} -le ${LOG_LEVELS[$CURRENT_LOG_LEVEL]} ]]; then
    case $level in
    "ERROR")
      echo -e "[${level}] ${message}"
      ;;
    "WARN")
      echo -e "[${level}] ${message}"
      ;;
    "INFO")
      echo -e "[${level}] ${message}"
      ;;
    "DEBUG")
      echo -e "[${level}] ${message}"
      ;;
    esac
  fi
}

setup_cleanup() {
  trap 'rm -rf "${TMP_DIR}"; rm -f "${LOCK_FILE}"; exit' INT TERM EXIT
}

# Generate a list of flac and mp3 files, remove the extension so we can diff
# later when checking for removed files
generate_file_list() {
  local dir
  local list

  dir="$1"
  list="$2"

  log "DEBUG" "Generating file list for ${dir}"

  find \
    "${dir}" \
    -type f \
    \( -name "*.mp3" -o -name "*.flac" \) |
    sed "s|^${dir}/||" |
    sed 's/\.[^.]*$//' |
    sort >"${TMP_DIR}/${list}"
}

# Compare the input and output file lists, delete any from OUTPUT_DIR that do
# not exist in INPUT_DIR
remove_files() {
  local output_dir
  local input_list
  local output_list

  output_dir="$1"
  input_list="$2"
  output_list="$3"

  local files_to_delete

  mapfile -t files_to_delete < <(grep -vxFf "${input_list}" "${output_list}" || true)

  log "DEBUG" "Checking for files to remove"

  # If we have files to delete, delete them
  if [[ "${#files_to_delete[@]}" -gt 0 ]]; then
    for file in "${files_to_delete[@]}"; do
      full_path="${output_dir}/${file}.mp3"
      if [[ -f "${full_path}" ]]; then
        log "INFO" "Deleting removed file: ${file}"
        rm -rf "${full_path}"
      fi
    done

    # Remove any empty dirs left over from the above deletions
    log "DEBUG" "Cleaning up empty directories"
    find "${output_dir}" -type d -empty -delete
  fi
}

# Convert/Copy file based on extension
convert_file() {
  local input_file
  local output_file
  local filetype

  input_file="$1"
  output_file="$2"

  if [[ -f "${input_file}.flac" ]]; then
    filetype="flac"
    input_file="${input_file}.flac"
  elif [[ -f "${input_file}.mp3" ]]; then
    filetype="mp3"
    input_file="${input_file}.mp3"
  else
    log "ERROR" "Unknown filetype for: ${input_file}"
  fi

  # Convert to mp3
  if [[ "${filetype}" == "flac" ]]; then
    log "DEBUG" "Converting ${input_file}"
    if ! ffmpeg \
      -i "${input_file}" \
      -codec:a libmp3lame \
      -q:a "${LAME_QUALITY}" \
      -map_metadata 0 \
      -id3v2_version 3 \
      "${output_file}" \
      -hide_banner \
      -loglevel error; then
      log "ERROR" "Failed to convert: ${input_file}"
    fi
  fi

  # Copy mp3
  if [[ "${filetype}" == "mp3" ]]; then
    log "DEBUG" "Moving ${input_file}"
    cp "${input_file}" "${output_file}"
  fi
}

process_files() {
  local input_dir
  local output_dir
  local input_list
  local output_list

  input_dir="$1"
  output_dir="$2"
  input_list="$3"
  output_list="$4"

  local files_to_process
  local file
  local input_file
  local output_file
  local output_path

  log "DEBUG" "Processing files"

  mapfile -t files_to_process < <(grep -vxFf "${output_list}" "${input_list}" || true)

  if [[ "${#files_to_process[@]}" -gt 0 ]]; then
    log "INFO" "Processing ${#files_to_process[@]} files"
    for file in "${files_to_process[@]}"; do
      input_file="${input_dir}/${file}"
      output_file="${output_dir}/${file}.mp3"
      output_path="$(dirname "${output_file}")"

      if ! mkdir -p "${output_path}"; then
        log "ERROR" "Unable the create output directory: '${output_path}'"
        exit 1
      fi

      convert_file "${input_file}" "${output_file}"
    done
  else
    log "INFO" "No files to process"
  fi
}

main() {
  log "INFO" "Starting music conversion process"

  lock
  setup_cleanup
  generate_file_list "${INPUT_DIR}" "input"
  generate_file_list "${OUTPUT_DIR}" "output"
  remove_files "${OUTPUT_DIR}" "${TMP_DIR}/input" "${TMP_DIR}/output"
  process_files "${INPUT_DIR}" "${OUTPUT_DIR}" "${TMP_DIR}/input" "${TMP_DIR}/output"

  log "INFO" "Music conversion process completed"
}

# Check if we're supposed to be looping
if [[ "${LOOP}" == "true" ]]; then
  while true; do
    main
    sleep "${SLEEP_TIME}"
  done
else
  main
fi

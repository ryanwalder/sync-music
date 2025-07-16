#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Convert/move audio files from INPUT_DIR to OUTPUT_DIR
#   Converts FLAC > MP3
#   Copies MP3s
#   Removes files from OUTPUT_DIR if deleted from INPUT_DIR

# User defined global variables
INPUT_DIR="${INPUT_DIR:-/input}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
LAME_QUALITY="${LAME_QUALITY:-0}"
LOOP="${LOOP:-true}"
SLEEP_TIME="${SLEEP_TIME:-900}"
STABILITY_CHECK_TIME="${STABILITY_CHECK_TIME:-2}"
STABILITY_MAX_WAIT="${STABILITY_MAX_WAIT:-300}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Immutable global variables
declare -A LOG_LEVELS=(["ERROR"]=0 ["WARN"]=1 ["INFO"]=2 ["DEBUG"]=3)
TMP_DIR=$(mktemp -d)

# Logging helper
log() {
  local level
  local message
  local timestamp

  level=${1^^}
  message="$2"
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  if [[ ${LOG_LEVELS[$level]} -le ${LOG_LEVELS[$LOG_LEVEL]} ]]; then
    echo -e "${timestamp} [${level}] ${message}"
  fi
}

setup_cleanup() {
  trap 'rm -rf "${TMP_DIR}"; exit' INT TERM EXIT
}

# Generate a list of flac and mp3 files, remove the extension so we can diff
# later when checking for removed files
generate_file_list() {
  local dir
  local list

  dir="$1"
  list="$2"

  log "DEBUG" "Generating file list for ${dir}"

  find "${dir}" -type f \( -iname "*.mp3" -o -iname "*.flac" \) |
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

  if [[ "${#files_to_delete[@]}" -gt 0 ]]; then
    log "DEBUG" "Files to delete: ${files_to_delete[*]}"
  fi

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
    filetype="unknown"
    log "ERROR" "Unknown filetype for: ${input_file}"
  fi

  # Wait for file to become stable
  if ! wait_for_file_stable "${input_file}" "${STABILITY_CHECK_TIME}" "${STABILITY_MAX_WAIT}"; then
    log "WARN" "File not stable after maximum wait time, skipping: ${input_file}"
    return
  fi

  case "${filetype,,}" in
  flac)
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
    ;;
  mp3)
    log "DEBUG" "Moving ${input_file}"
    if ! cp "${input_file}" "${output_file}"; then
      log "ERROR" "Failed to copy ${input_file} to ${output_file}"
    fi
    ;;
  *)
    # handle files that go missing while processing
    log "DEBUG" "Unknown file type for '${file}', skipping."
    ;;
  esac
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

  # If output list is empty, process all input files
  if [[ ! -s "${output_list}" ]]; then
    log "DEBUG" "Output list is empty, processing all files"
    mapfile -t files_to_process <"${input_list}"
  else
    # Otherwise do the comparison
    mapfile -t files_to_process < <(grep -vxFf "${output_list}" "${input_list}" || true)
  fi

  log "DEBUG" "Files to process count: ${#files_to_process[@]}"

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

# Wait for a file to become stable
# Make sure we're not converting/copying a file which is in the process of being
# written to or has been deleted
wait_for_file_stable() {
  local file
  local check_interval
  local max_wait

  file="$1"
  check_interval="${2:-5}"
  max_wait="${3:-300}"

  local start_time
  local current_time
  local size1
  local size2

  start_time=$(date +%s)

  # Disable if check_interval is 0
  if [[ "${check_interval}" -ne 0 ]]; then
    while true; do
      # Check if we've exceeded max wait time
      current_time=$(date +%s)
      if ((current_time - start_time > max_wait)); then
        log "WARN" "Exceeded maximum wait time of ${max_wait}s for file: ${file}"
        return 0
      fi

      # Check the file exists in case it has been deleted since we started
      if [[ -f "${file}" ]]; then
        size1=$(stat -c %s "${file}" 2>/dev/null || echo "0")

        # Check for zero or very small files
        if [[ "${size1}" == "0" ]] || [[ "${size1}" -lt 1024 ]]; then
          log "ERROR" "Input file '${file}' is too small (${size1} bytes), skipping."
          return 0
        fi

        sleep "${check_interval}"

        size2=$(stat -c %s "${file}" 2>/dev/null || echo "0")

        if [[ "${size1}" -eq "${size2}" ]]; then
          return 0
        elif [[ "${size1}" -gt "${size2}" ]]; then
          # Handle degenerate case where the file is deleted during processing
          log "WARN" "Input file '${file}' has gotten smaller, skipping."
          return 0
        fi
      else
        log "WARN" "Input file '${file}' does not exist, skipping."
        return 0
      fi

      log "DEBUG" "File size changed from ${size1} to ${size2}, waiting: ${file}"
    done
  else
    log "DEBUG" "STABILITY_CHECK_TIME set to 0, not running checks for file '${file}'."
  fi
}

main() {
  log "INFO" "Starting music conversion process"

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
    log "INFO" "Sleeping for ${SLEEP_TIME} seconds."
    sleep "${SLEEP_TIME}"
  done
else
  main
fi

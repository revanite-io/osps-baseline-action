#!/usr/bin/env bash
set -euo pipefail

# Prepare the scanner's SARIF file for upload to GitHub Code Scanning.
#
# Finds the SARIF file in the results directory, optionally filters it down
# to failed controls only (error-level results), and writes the sarif_file
# step output consumed by the upload step. The output is empty when there is
# nothing to upload.
#
# A SARIF file with zero results is still uploaded: GitHub closes an alert only
# when a newer analysis in the same category no longer reports it, so skipping
# clean scans would leave previously failed controls open forever.
#
# Required environment variables:
#   RESULTS_DIR         - Path to the evaluation_results directory (default: evaluation_results)
#   SARIF_ONLY_FAILURES - "true" to keep only error-level (failed control) results
#   GITHUB_OUTPUT       - Path to the GitHub Actions step output file

RESULTS_DIR="${RESULTS_DIR:-evaluation_results}"
SARIF_ONLY_FAILURES="${SARIF_ONLY_FAILURES:-true}"

write_output() {
  echo "sarif_file=$1" >> "$GITHUB_OUTPUT"
}

SARIF_FILE=$(find "$RESULTS_DIR" -name "*.sarif" -type f 2>/dev/null | head -1)

if [ -z "$SARIF_FILE" ] || [ ! -f "$SARIF_FILE" ]; then
  echo "⚠️  No SARIF file found in ${RESULTS_DIR} directory"
  write_output ""
  exit 0
fi

if ! TOTAL_COUNT=$(jq '[.runs[]?.results[]?] | length' "$SARIF_FILE" 2>/dev/null); then
  echo "⚠️  SARIF file ${SARIF_FILE} is not valid JSON. Skipping upload."
  write_output ""
  exit 0
fi

if [ "$(jq 'if (.runs | type) == "array" then (.runs | length) else 0 end' "$SARIF_FILE")" -eq 0 ]; then
  echo "⚠️  SARIF file ${SARIF_FILE} contains no runs. Skipping upload."
  write_output ""
  exit 0
fi

if [ "$SARIF_ONLY_FAILURES" = "true" ]; then
  # Keep only error-level results (failed controls). Needs-review and passed
  # controls never close as Code Scanning alerts, so they stay in the workflow
  # summary and results files instead of the Security tab.
  FILTERED_FILE="${SARIF_FILE%.sarif}.failures.sarif"
  jq '.runs = (.runs | map(.results = ((.results // []) | map(select(.level == "error")))))' \
    "$SARIF_FILE" > "$FILTERED_FILE"
  SARIF_FILE="$FILTERED_FILE"
  RESULT_COUNT=$(jq '[.runs[].results[]] | length' "$SARIF_FILE")
  echo "Filtered SARIF to failed controls only: kept ${RESULT_COUNT} of ${TOTAL_COUNT} result(s)"
else
  RESULT_COUNT=$TOTAL_COUNT
  if [ "$(jq '[.runs[] | select(.results == null)] | length' "$SARIF_FILE")" -gt 0 ]; then
    # Give every run an explicit results array so an empty run still reads as "no findings".
    NORMALIZED_FILE="${SARIF_FILE%.sarif}.normalized.sarif"
    jq '.runs = (.runs | map(.results = (.results // [])))' "$SARIF_FILE" > "$NORMALIZED_FILE"
    SARIF_FILE="$NORMALIZED_FILE"
  fi
fi

if [ "$RESULT_COUNT" -gt 0 ]; then
  echo "✅ SARIF file contains ${RESULT_COUNT} result(s)"
elif [ "$SARIF_ONLY_FAILURES" = "true" ]; then
  echo "✅ No failed controls. Uploading an empty SARIF so GitHub closes alerts from earlier failed scans."
else
  echo "✅ No results. Uploading an empty SARIF so GitHub closes alerts from earlier scans."
fi
write_output "$SARIF_FILE"

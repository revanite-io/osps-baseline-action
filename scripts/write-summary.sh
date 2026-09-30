#!/usr/bin/env bash
set -euo pipefail

# Write OSPS assessment results to the GitHub workflow summary.
#
# Required environment variables:
#   OWNER            - Repository owner
#   REPO             - Repository name
#   CATALOG          - OSPS catalog name used for the scan
#   GITHUB_STEP_SUMMARY - Path to the GitHub step summary file
#   GITHUB_OUTPUT    - Path to the GitHub step output file
#   RESULTS_DIR      - Path to the evaluation_results directory (default: evaluation_results)

RESULTS_DIR="${RESULTS_DIR:-evaluation_results}"

LOG_FILE=$(find "$RESULTS_DIR" -name "*.log" -type f 2>/dev/null | head -1)

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
  {
    echo "## OSPS Baseline Assessment Results"
    echo ""
    echo "**Repository:** \`${OWNER}/${REPO}\` | **Catalog:** \`${CATALOG}\`"
    echo ""
    echo ":x: **Scanner failed to produce output.** No log file found in \`${RESULTS_DIR}\`."
    echo "Check that the scanner container ran successfully."
  } >> "$GITHUB_STEP_SUMMARY"
  echo "::error::OSPS scanner produced no log file — the container may have failed to start or run"
  exit 1
fi

# Parse OSPS control result lines from the log.
# Format: TIMESTAMP [LEVEL]  OSPS-XX-YY.ZZ: description
CONTROL_LINES=$(grep -E '\[INFO\].*OSPS-|\[WARN\].*OSPS-|\[ERROR\].*OSPS-' "$LOG_FILE" || true)

if [ -z "$CONTROL_LINES" ]; then
  # Surface any ERROR lines from the scanner to help diagnose the failure
  SCANNER_ERRORS=$(grep '\[ERROR\]' "$LOG_FILE" || true)

  {
    echo "## OSPS Baseline Assessment Results"
    echo ""
    echo "**Repository:** \`${OWNER}/${REPO}\` | **Catalog:** \`${CATALOG}\`"
    echo ""
    echo ":x: **No OSPS control results found.** The scanner ran but produced no control output."
    echo ""
    if [ -n "$SCANNER_ERRORS" ]; then
      echo "### Scanner Errors"
      echo ""
      echo '```'
      echo "$SCANNER_ERRORS"
      echo '```'
    else
      echo "No error output was found in the log. Check the scanner configuration and catalog name."
    fi
  } >> "$GITHUB_STEP_SUMMARY"
  echo "::error::OSPS scanner produced no control results — check catalog name and scanner configuration"
  exit 1
fi

# Extract the summary line (e.g. "pvtr_osps-baseline: 16 Passed, 0 Warnings, 0 Failed, 40 Possible")
SUMMARY_LINE=$(grep '> pvtr_' "$LOG_FILE" | sed 's/.*> //' || true)

# Parse counts from the summary line
PASSED=$(echo "$SUMMARY_LINE" | sed -n 's/.*\([0-9][0-9]*\) Passed.*/\1/p')
WARNINGS=$(echo "$SUMMARY_LINE" | sed -n 's/.*\([0-9][0-9]*\) Warnings.*/\1/p')
FAILED=$(echo "$SUMMARY_LINE" | sed -n 's/.*\([0-9][0-9]*\) Failed.*/\1/p')
PASSED=${PASSED:-0}
WARNINGS=${WARNINGS:-0}
FAILED=${FAILED:-0}

# Write markdown header and results
{
  echo "## OSPS Baseline Assessment Results"
  echo ""
  echo "**Repository:** \`${OWNER}/${REPO}\` | **Catalog:** \`${CATALOG}\`"
  echo ""
  echo "| Passed | Warnings | Failed |"
  echo "|:------:|:--------:|:------:|"
  echo "| ${PASSED} | ${WARNINGS} | ${FAILED} |"
  echo ""
  echo "### Control Results"
  echo ""
  echo "| Status | Control | Finding |"
  echo "|:------:|---------|---------|"
} >> "$GITHUB_STEP_SUMMARY"

echo "$CONTROL_LINES" | while IFS= read -r line; do
  if echo "$line" | grep -q '\[ERROR\]'; then
    ICON=":x:"
  elif echo "$line" | grep -q '\[WARN\]'; then
    ICON=":warning:"
  else
    ICON=":white_check_mark:"
  fi

  CONTROL=$(echo "$line" | sed -n 's/.*\(OSPS-[A-Z]*-[0-9]*\.[0-9]*\).*/\1/p')
  DESCRIPTION="${line#*"${CONTROL}: "}"

  if [ -n "$CONTROL" ]; then
    echo "| ${ICON} | ${CONTROL} | ${DESCRIPTION} |" >> "$GITHUB_STEP_SUMMARY"
  fi
done

# Expose the failed count so a later step can apply fail-on-error after the
# SARIF upload has run
echo "failed=${FAILED}" >> "$GITHUB_OUTPUT"

#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/write-summary.sh"
  RESULTS_DIR="$(mktemp -d)"
  GITHUB_STEP_SUMMARY="$(mktemp)"
  GITHUB_OUTPUT="$(mktemp)"
  export OWNER="test-owner"
  export REPO="test-repo"
  export CATALOG="osps-baseline-2026-02"
  export GITHUB_STEP_SUMMARY
  export GITHUB_OUTPUT
  export RESULTS_DIR
}

teardown() {
  rm -rf "$RESULTS_DIR"
  rm -f "$GITHUB_STEP_SUMMARY"
  rm -f "$GITHUB_OUTPUT"
}

@test "exits 1 when no log file is found in results directory" {
  # RESULTS_DIR is empty — no log file produced (e.g. docker failure)
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "summary mentions scanner failure when no log file found" {
  run bash "$SCRIPT"
  grep -qi "scanner" "$GITHUB_STEP_SUMMARY"
}

@test "exits 1 when log exists but has no OSPS control lines and no scanner errors" {
  # Log file exists but catalog lookup failed silently
  echo "2026-01-01T00:00:00Z [INFO]  starting scan" > "$RESULTS_DIR/run.log"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "exits 1 and surfaces scanner error when catalog not found" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [INFO]  starting scan
2026-01-01T00:00:01Z [ERROR] catalog not found: osps-baseline-2026-02
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  grep -q "catalog not found" "$GITHUB_STEP_SUMMARY"
}

@test "summary includes scanner error lines when no control results" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [INFO]  starting scan
2026-01-01T00:00:01Z [ERROR] catalog not found: osps-baseline-2026-02
EOF
  run bash "$SCRIPT"
  grep -q "catalog not found" "$GITHUB_STEP_SUMMARY"
}

@test "exits 0 when OSPS control lines are present and no failures" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [INFO]  OSPS-AC-01.01: access control enabled
2026-01-01T00:00:01Z [INFO]  OSPS-AC-01.02: mfa enforced
> pvtr_osps-baseline-2026-02: 2 Passed, 0 Warnings, 0 Failed, 0 Possible
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 0 when FAILED controls exist so later steps still run" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [INFO]  OSPS-AC-01.01: access control enabled
2026-01-01T00:00:01Z [ERROR] OSPS-AC-01.02: mfa not enforced
> pvtr_osps-baseline-2026-02: 1 Passed, 0 Warnings, 1 Failed, 0 Possible
EOF
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "writes the failed control count to GITHUB_OUTPUT" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [INFO]  OSPS-AC-01.01: access control enabled
2026-01-01T00:00:01Z [ERROR] OSPS-AC-01.02: mfa not enforced
> pvtr_osps-baseline-2026-02: 1 Passed, 0 Warnings, 1 Failed, 0 Possible
EOF
  run bash "$SCRIPT"
  grep -qx "failed=1" "$GITHUB_OUTPUT"
}

@test "writes failed=0 to GITHUB_OUTPUT when all controls pass" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [INFO]  OSPS-AC-01.01: access control enabled
> pvtr_osps-baseline-2026-02: 1 Passed, 0 Warnings, 0 Failed, 0 Possible
EOF
  run bash "$SCRIPT"
  grep -qx "failed=0" "$GITHUB_OUTPUT"
}

@test "summary table shows full multi-digit counts" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [ERROR] OSPS-AC-01.02: mfa not enforced
> pvtr_osps-baseline-2026-02: 14 Passed, 3 Warnings, 12 Failed, 41 Possible
EOF
  run bash "$SCRIPT"
  grep -qF "| 14 | 3 | 12 |" "$GITHUB_STEP_SUMMARY"
}

@test "writes a multi-digit failed control count to GITHUB_OUTPUT" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [ERROR] OSPS-AC-01.02: mfa not enforced
> pvtr_osps-baseline-2026-02: 14 Passed, 3 Warnings, 12 Failed, 41 Possible
EOF
  run bash "$SCRIPT"
  grep -qx "failed=12" "$GITHUB_OUTPUT"
}

@test "summary table is written with passing control results" {
  cat > "$RESULTS_DIR/run.log" <<'EOF'
2026-01-01T00:00:00Z [INFO]  OSPS-AC-01.01: access control enabled
> pvtr_osps-baseline-2026-02: 1 Passed, 0 Warnings, 0 Failed, 0 Possible
EOF
  run bash "$SCRIPT"
  grep -q "OSPS-AC-01.01" "$GITHUB_STEP_SUMMARY"
}

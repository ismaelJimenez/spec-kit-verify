#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SCRIPT_UNDER_TEST="${SCRIPT_DIR}/scripts/bash/load-config.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  unset SPECKIT_VERIFY_MAX_FINDINGS
}

teardown() {
  rm -rf "$TEST_DIR"
}

create_config() {
  local value="$1"
  mkdir -p .specify/extensions/verify
  cat > .specify/extensions/verify/verify-config.yml <<EOF
report:
  max_findings: ${value}
EOF
}

create_config_raw() {
  mkdir -p .specify/extensions/verify
  cat > .specify/extensions/verify/verify-config.yml <<EOF
${1}
EOF
}

create_extension_yml() {
  local value="${1:-50}"
  mkdir -p .specify/extensions/verify
  cat > .specify/extensions/verify/extension.yml <<EOF
defaults:
  report:
    max_findings: ${value}
EOF
}

# --- Group A: Config file missing ---

@test "exits 1 when config file and extension.yml do not exist" {
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration not found"* ]]
}

@test "missing config error suggests install command" {
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"specify extension add verify"* ]]
}

@test "loads defaults from extension.yml when config missing" {
  create_extension_yml 50
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"using defaults from extension.yml"* ]]
  [[ "$output" == *"max_findings=50"* ]]
}

@test "loads custom default from extension.yml when config missing" {
  create_extension_yml 75
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=75"* ]]
}

@test "env var overrides extension.yml default when config missing" {
  create_extension_yml 50
  SPECKIT_VERIFY_MAX_FINDINGS=200 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=200"* ]]
}

# --- Group B: Successful load ---

@test "loads max_findings from config file" {
  create_config 25
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=25"* ]]
}

@test "loads default value 50 from config" {
  create_config 50
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=50"* ]]
}

# --- Group C: Environment variable override ---

@test "env var overrides config value" {
  create_config 25
  SPECKIT_VERIFY_MAX_FINDINGS=100 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=100"* ]]
}

@test "env var provides value when config returns null" {
  create_config null
  SPECKIT_VERIFY_MAX_FINDINGS=42 run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=42"* ]]
}

@test "empty env var does not override config value" {
  create_config 25
  # ${VAR:-default} substitutes when VAR is unset OR empty,
  # so empty string falls back to the config value
  SPECKIT_VERIFY_MAX_FINDINGS="" run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=25"* ]]
}

# --- Group D: Validation failures ---

@test "exits 1 when max_findings is empty string in config" {
  create_config '""'
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration value not set"* ]]
}

@test "exits 1 when max_findings is explicit null keyword" {
  create_config null
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration value not set"* ]]
}

@test "exits 1 when max_findings has bare missing value" {
  create_config_raw "report:
  max_findings:"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration value not set"* ]]
}

@test "exits 1 when report section has no max_findings key" {
  create_config_raw "report:
  other_key: value"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration value not set"* ]]
}

@test "exits 1 when config file is empty" {
  create_config_raw ""
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration value not set"* ]]
}

@test "validation error suggests editing config file" {
  create_config null
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Edit"* ]]
  [[ "$output" == *"report.max_findings"* ]]
}

# --- Group E: Edge / boundary cases ---

@test "exits 1 when config has explicit YAML null (~)" {
  create_config "~"
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Configuration value not set"* ]]
}

@test "exits 1 when max_findings is non-numeric" {
  create_config abc
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a positive integer"* ]]
}

@test "zero value loads successfully" {
  create_config 0
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=0"* ]]
}

@test "exits 1 when max_findings is negative" {
  create_config -1
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a positive integer"* ]]
}

@test "exits 1 when max_findings contains spaces" {
  create_config '"hello world"'
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a positive integer"* ]]
}

@test "exits 1 when env var override is non-numeric" {
  create_config 50
  SPECKIT_VERIFY_MAX_FINDINGS=abc run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must be a positive integer"* ]]
}

@test "large numeric value loads successfully" {
  create_config 99999
  run bash "$SCRIPT_UNDER_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"max_findings=99999"* ]]
}



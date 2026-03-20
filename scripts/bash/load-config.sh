#!/usr/bin/env bash
# load-config.sh — Load and validate the verify extension configuration.
#
# Reads report.max_findings from the YAML config file using yq,
# normalises YAML null sentinels, applies an optional environment
# variable override (SPECKIT_VERIFY_MAX_FINDINGS), and validates
# that a value is present before exporting it.
#
# Exit codes:
#   0 — configuration loaded successfully
#   1 — config file missing, required value not set, or invalid value
#
# Dependencies: yq (https://github.com/mikefarah/yq)

config_file=".specify/extensions/verify/verify-config.yml"

if [ ! -f "$config_file" ]; then
  echo "❌ Error: Configuration not found at $config_file"
  echo "Run 'specify extension add verify' to install and configure"
  exit 1
fi

# Read configuration values

max_findings=$(yq eval '.report.max_findings' "$config_file")

# Treat yq sentinel values as empty
if [ "$max_findings" = "null" ] || [ "$max_findings" = "~" ]; then
  max_findings=""
fi

# Apply environment variable overrides

max_findings="${SPECKIT_VERIFY_MAX_FINDINGS:-$max_findings}"

# Validate configuration

if [ -z "$max_findings" ]; then
  echo "❌ Error: Configuration value not set"
  echo "Edit $config_file and set 'report.max_findings'"
  exit 1
fi

if ! [[ "$max_findings" =~ ^[0-9]+$ ]]; then
  echo "❌ Error: 'report.max_findings' must be a positive integer, got '$max_findings'"
  echo "Edit $config_file and set 'report.max_findings' to a number (e.g. 50)"
  exit 1
fi

echo "📋 Configuration loaded: max_findings=$max_findings"
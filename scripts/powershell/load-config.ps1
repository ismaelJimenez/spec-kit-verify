# load-config.ps1 — Load and validate the verify extension configuration.
#
# Reads report.max_findings from the YAML config file using yq,
# normalises YAML null sentinels, applies an optional environment
# variable override (SPECKIT_VERIFY_MAX_FINDINGS), and validates
# that a value is present before exporting it.
#
# Usage:  load-config.ps1
#
# Exit codes:
#   0 — configuration loaded successfully
#   1 — config file missing, required value not set, or invalid value
#
# Dependencies: yq (https://github.com/mikefarah/yq)

$configFile = ".specify/extensions/verify/verify-config.yml"
$extensionFile = ".specify/extensions/verify/extension.yml"
$usingDefaults = $false

if (-not (Test-Path $configFile)) {
    if (Test-Path $extensionFile) {
        $usingDefaults = $true
    } else {
        Write-Host "❌ Error: Configuration not found at $configFile"
        Write-Host "Run 'specify extension add verify' to install and configure"
        exit 1
    }
}

# Read configuration values

if ($usingDefaults) {
    $maxFindings = yq eval '.defaults.report.max_findings' $extensionFile
} else {
    $maxFindings = yq eval '.report.max_findings' $configFile
}

# Treat yq sentinel values as empty
if ($maxFindings -eq 'null' -or $maxFindings -eq '~') {
    $maxFindings = ''
}

# Apply environment variable overrides

if ($env:SPECKIT_VERIFY_MAX_FINDINGS -ne $null -and $env:SPECKIT_VERIFY_MAX_FINDINGS -ne '') {
    $maxFindings = $env:SPECKIT_VERIFY_MAX_FINDINGS
}

# Validate configuration

if (-not $maxFindings) {
    Write-Host "❌ Error: Configuration value not set"
    Write-Host "Edit $configFile and set 'report.max_findings'"
    exit 1
}

if ($maxFindings -notmatch '^\d+$') {
    Write-Host "❌ Error: 'report.max_findings' must be a positive integer, got '$maxFindings'"
    Write-Host "Edit $configFile and set 'report.max_findings' to a number (e.g. 50)"
    exit 1
}

if ($usingDefaults) {
    Write-Host "⚠️  No config file found; using defaults from extension.yml"
}

Write-Host "📋 Configuration loaded: max_findings=$maxFindings"
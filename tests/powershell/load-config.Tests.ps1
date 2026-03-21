BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../scripts/powershell/load-config.ps1' | Resolve-Path
}

Describe 'load-config.ps1' {
    BeforeEach {
        $script:TestDir = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName()))
        Push-Location $script:TestDir
    }

    AfterEach {
        Pop-Location
        Remove-Item -Recurse -Force $script:TestDir.FullName -ErrorAction SilentlyContinue
    }

    function script:New-TestConfig {
        param([string]$Value)
        $dir = New-Item -ItemType Directory -Path '.specify/extensions/verify' -Force
        @"
report:
  max_findings: $Value
"@ | Set-Content (Join-Path $dir.FullName 'verify-config.yml')
    }

    function script:New-TestConfigRaw {
        param([string]$Content)
        $dir = New-Item -ItemType Directory -Path '.specify/extensions/verify' -Force
        $Content | Set-Content (Join-Path $dir.FullName 'verify-config.yml')
    }

    function script:New-ExtensionYml {
        param([string]$Value = '50')
        $dir = New-Item -ItemType Directory -Path '.specify/extensions/verify' -Force
        @"
defaults:
  report:
    max_findings: $Value
"@ | Set-Content (Join-Path $dir.FullName 'extension.yml')
    }

    function script:Invoke-LoadConfig {
        param(
            [hashtable]$EnvOverrides = @{}
        )

        $envSetup = foreach ($kv in $EnvOverrides.GetEnumerator()) {
            "`$env:$($kv.Key) = '$($kv.Value)'"
        }
        $envBlock = if ($envSetup) { ($envSetup -join '; ') + '; ' } else { '' }
        $cwd = (Get-Location).Path

        $output = & pwsh -NoProfile -Command "${envBlock}Set-Location -LiteralPath '${cwd}'; & '${script:ScriptPath}'" 2>&1
        [PSCustomObject]@{
            Output   = $output -join "`n"
            ExitCode = $LASTEXITCODE
        }
    }

    # --- Group A: Config file missing ---

    Context 'Config file missing' {
        It 'exits 1 when config file and extension.yml do not exist' {
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'Configuration not found'
        }

        It 'missing config error suggests install command' {
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'specify extension add verify'
        }

        It 'loads defaults from extension.yml when config missing' {
            New-ExtensionYml '50'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'using defaults from extension.yml'
            $r.Output | Should -Match 'max_findings=50'
        }

        It 'loads custom default from extension.yml when config missing' {
            New-ExtensionYml '75'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=75'
        }

        It 'env var overrides extension.yml default when config missing' {
            New-ExtensionYml '50'
            $r = Invoke-LoadConfig -EnvOverrides @{ SPECKIT_VERIFY_MAX_FINDINGS = '200' }
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=200'
        }
    }

    # --- Group B: Successful load ---

    Context 'Successful load' {
        It 'loads max_findings from config file' {
            New-TestConfig '25'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=25'
        }

        It 'loads default value 50 from config' {
            New-TestConfig '50'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=50'
        }
    }

    # --- Group C: Environment variable override ---

    Context 'Environment variable override' {
        It 'env var overrides config value' {
            New-TestConfig '25'
            $r = Invoke-LoadConfig -EnvOverrides @{ SPECKIT_VERIFY_MAX_FINDINGS = '100' }
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=100'
        }

        It 'env var provides value when config returns null' {
            New-TestConfig 'null'
            $r = Invoke-LoadConfig -EnvOverrides @{ SPECKIT_VERIFY_MAX_FINDINGS = '42' }
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=42'
        }

        It 'empty env var does not override config value' {
            New-TestConfig '25'
            $r = Invoke-LoadConfig -EnvOverrides @{ SPECKIT_VERIFY_MAX_FINDINGS = '' }
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=25'
        }
    }

    # --- Group D: Validation failures ---

    Context 'Validation failures' {
        It 'exits 1 when max_findings is empty string in config' {
            New-TestConfig '""'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'Configuration value not set'
        }

        It 'exits 1 when max_findings is explicit null keyword' {
            New-TestConfig 'null'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'Configuration value not set'
        }

        It 'exits 1 when max_findings has bare missing value' {
            New-TestConfigRaw "report:`n  max_findings:"
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'Configuration value not set'
        }

        It 'exits 1 when report section has no max_findings key' {
            New-TestConfigRaw "report:`n  other_key: value"
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'Configuration value not set'
        }

        It 'exits 1 when config file is empty' {
            New-TestConfigRaw ''
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'Configuration value not set'
        }

        It 'validation error suggests editing config file' {
            New-TestConfig 'null'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'Edit'
            $r.Output | Should -Match 'report\.max_findings'
        }
    }

    # --- Group E: Edge / boundary cases ---

    Context 'Edge / boundary cases' {
        It 'exits 1 when config has explicit YAML null (~)' {
            New-TestConfig '~'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'Configuration value not set'
        }

        It 'exits 1 when max_findings is non-numeric' {
            New-TestConfig 'abc'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'must be a positive integer'
        }

        It 'zero value loads successfully' {
            New-TestConfig '0'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=0'
        }

        It 'exits 1 when max_findings is negative' {
            New-TestConfig '-1'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'must be a positive integer'
        }

        It 'exits 1 when max_findings contains spaces' {
            New-TestConfig '"hello world"'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'must be a positive integer'
        }

        It 'exits 1 when env var override is non-numeric' {
            New-TestConfig '50'
            $r = Invoke-LoadConfig -EnvOverrides @{ SPECKIT_VERIFY_MAX_FINDINGS = 'abc' }
            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'must be a positive integer'
        }

        It 'large numeric value loads successfully' {
            New-TestConfig '99999'
            $r = Invoke-LoadConfig
            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'max_findings=99999'
        }
    }

}

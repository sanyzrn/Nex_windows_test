param(
  [ValidateSet('PrePush', 'Validate', 'Desktop', 'Ui', 'CoreData', 'Ai', 'Build', 'Package', 'Native', 'Update', 'Runtime')]
  [string]$Stage = 'PrePush',
  [switch]$Offline,
  [switch]$NoRestore,
  [switch]$IncludeQuarantined,
  [ValidateRange(30, 600)][int]$TestTimeoutSeconds = 120,
  [ValidateRange(1, 8)][int]$Concurrency = 2,
  [string]$OutputDirectory,
  [string]$ISCC
)
$ErrorActionPreference = 'Stop'
$runnerShell = (Get-Process -Id $PID).Path
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $workspace 'apps/desktop/build/local-ci' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$results = [Collections.Generic.List[object]]::new()
$stages = if ($Stage -eq 'PrePush') { @('Validate', 'Desktop', 'Ui', 'CoreData', 'Ai', 'Build', 'Package') } else { @($Stage) }
$excluded = if ($IncludeQuarantined) { 'golden || review' } else { 'golden || review || quarantined' }

function Invoke-Check([string]$Name, [string]$Directory, [string]$Command, [string[]]$CommandArguments) {
  $logPath = Join-Path $OutputDirectory ($Name + '.log')
  $watch = [Diagnostics.Stopwatch]::StartNew()
  Write-Host "[RUN] $Name"
  $code = 0
  Push-Location (Join-Path $workspace $Directory)
  try {
    $global:LASTEXITCODE = 0
    & $Command @CommandArguments *> $logPath
    $code = $LASTEXITCODE
  } catch {
    $_ | Out-String | Add-Content -LiteralPath $logPath
    $code = 1
  } finally { Pop-Location }
  $watch.Stop()
  $results.Add([pscustomobject]@{
    name = $Name; exitCode = $code; seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1)
    command = $Command; arguments = $CommandArguments; log = $logPath
  })
  if ($code -eq 0) { Write-Host "[PASS] $Name ($([math]::Round($watch.Elapsed.TotalSeconds, 1))s)" }
  else {
    Write-Host "[FAIL] $Name; log: $logPath"
    Get-Content -LiteralPath $logPath -Tail 24 | Write-Host
  }
  return $code -eq 0
}

function Restore-Package([string]$Name, [string]$Directory, [string]$Tool) {
  if ($NoRestore) { return $true }
  $restoreArguments = @('pub', 'get', '--enforce-lockfile')
  if ($Offline) { $restoreArguments += '--offline' }
  return Invoke-Check "$Name-restore" $Directory $Tool $restoreArguments
}

function Test-Package([string]$Name, [string]$Directory, [string]$Tool) {
  if (-not (Restore-Package $Name $Directory $Tool)) { return }
  $analyzeArguments = @('analyze')
  if ($Tool -eq 'flutter') { $analyzeArguments += '--no-pub' }
  $null = Invoke-Check "$Name-analyze" $Directory $Tool $analyzeArguments
  $testArguments = @('test', '--timeout', ($TestTimeoutSeconds.ToString() + 's'), '--concurrency', "$Concurrency", '--reporter', 'expanded')
  if ($Tool -eq 'flutter') { $testArguments += @('--no-pub', "--dart-define=NEX_TEST_TIMEOUT_SECONDS=$TestTimeoutSeconds") }
  if ($Name -eq 'desktop') { $testArguments += @('--exclude-tags', $excluded) }
  $null = Invoke-Check "$Name-tests" $Directory $Tool $testArguments
}

foreach ($currentStage in $stages) {
  switch ($currentStage) {
    'Validate' {
      $null = Invoke-Check 'package-hosts' '.' $runnerShell @('-NoProfile', '-File', 'tools/check_package_hosts.ps1')
      $null = Invoke-Check 'localization' '.' 'python' @('tools/check_l10n_parity.py')
      $null = Invoke-Check 'localization-checker' '.' 'python' @('-m', 'unittest', 'discover', '-s', 'tools', '-p', 'test_check_l10n_parity.py')
      $null = Invoke-Check 'ui-hygiene' '.' $runnerShell @('-NoProfile', '-File', 'tools/check_ui_hygiene.ps1', '-LibDir', 'lib')
      $null = Invoke-Check 'release-automation' '.' $runnerShell @('-NoProfile', '-File', 'apps/desktop/tools/test_publish_release.ps1')
    }
    'Desktop' { Test-Package 'desktop' 'apps/desktop' 'flutter' }
    'Ui' { Test-Package 'ui' 'packages/ui' 'flutter' }
    'CoreData' {
      Test-Package 'core' 'packages/core' 'dart'
      Test-Package 'data' 'packages/data' 'dart'
    }
    'Ai' { Test-Package 'ai' 'packages/ai' 'flutter' }
    'Build' {
      $null = Invoke-Check 'windows-release' 'apps/desktop' 'flutter' @('build', 'windows', '--release', '--no-pub')
    }
    'Package' {
      $packageArguments = @('-NoProfile', '-File', 'apps/desktop/tools/build_installer.ps1', '-Output', (Join-Path $OutputDirectory 'installer'))
      if ($ISCC) { $packageArguments += @('-ISCC', $ISCC) }
      $null = Invoke-Check 'installer' '.' $runnerShell $packageArguments
    }
    'Native' {
      if (-not $env:RUNNER_TEMP) { $env:RUNNER_TEMP = $OutputDirectory }
      $null = Invoke-Check 'native-private' '.' $runnerShell @('-NoProfile', '-File', 'apps/desktop/tools/test_native_private.ps1')
      $null = Invoke-Check 'native-smoke' '.' $runnerShell @('-NoProfile', '-File', 'apps/desktop/tools/windows_smoke.ps1', '-Output', (Join-Path $OutputDirectory 'native-smoke.json'))
    }
    'Update' {
      if (-not $env:RUNNER_TEMP) { $env:RUNNER_TEMP = $OutputDirectory }
      $null = Invoke-Check 'update-handoff' '.' $runnerShell @('-NoProfile', '-File', 'apps/desktop/tools/test_update_handoff.ps1', '-InstallerDirectory', (Join-Path $OutputDirectory 'installer'))
    }
    'Runtime' {
      # Copy current saved source, including uncommitted fixes, but no builds,
      # secrets, ignored files or Git history. Never remove runtime files in place.
      $sandbox = Join-Path $OutputDirectory ('runtime-' + [guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $sandbox | Out-Null
      Push-Location $workspace
      try { $sourceFiles = @(git -c core.quotepath=false ls-files --cached --others --exclude-standard) }
      finally { Pop-Location }
      foreach ($relative in $sourceFiles) {
        $source = Join-Path $workspace $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
        $target = [IO.Path]::GetFullPath((Join-Path $sandbox $relative))
        if (-not $target.StartsWith($sandbox + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid source copy path.' }
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
      }
      $runtimeSpec = Join-Path $sandbox 'packages/ai/pubspec.yaml'
      (Get-Content -LiteralPath $runtimeSpec) | Where-Object { $_ -notmatch '^  flutter_litert_lm:' } | Set-Content -LiteralPath $runtimeSpec -Encoding utf8
      foreach ($runtimeFile in @('lib/nex_ai.dart', 'lib/src/litert_chat_adapter.dart', 'lib/src/local_chat_placeholder.dart')) {
        Remove-Item -LiteralPath (Join-Path $sandbox ('packages/ai/' + $runtimeFile))
      }
      $savedWorkspace = $workspace
      try {
        $workspace = $sandbox
        $runtimeRestore = @('pub', 'get')
        if ($Offline) { $runtimeRestore += '--offline' }
        if (Invoke-Check 'runtime-restore' 'apps/desktop' 'flutter' $runtimeRestore) {
          $null = Invoke-Check 'runtime-analyze' 'apps/desktop' 'flutter' @('analyze', '--no-pub')
          $null = Invoke-Check 'runtime-tests' 'apps/desktop' 'flutter' @('test', '--no-pub', "--dart-define=NEX_TEST_TIMEOUT_SECONDS=$TestTimeoutSeconds", '--exclude-tags', $excluded, '--timeout', ($TestTimeoutSeconds.ToString() + 's'), '--concurrency', "$Concurrency", '--reporter', 'expanded')
        }
      } finally { $workspace = $savedWorkspace }
      # Keep the isolated source beside its logs for diagnosing any failure.
    }
  }
}
$report = Join-Path $OutputDirectory ($Stage + '-report.json')
ConvertTo-Json -InputObject @($results.ToArray()) -Depth 6 | Set-Content -LiteralPath $report -Encoding utf8
$failed = @($results | Where-Object exitCode -NE 0)
Write-Host "Report: $report"
if ($Stage -eq 'PrePush') { Write-Host 'Native, Update and Runtime are separate stages; Native/Update require a disposable Windows account or VM.' }
if ($failed.Count) { Write-Host "$($failed.Count) checks failed."; exit 1 }
Write-Host "$($results.Count) checks passed."
exit 0

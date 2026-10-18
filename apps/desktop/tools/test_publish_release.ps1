$ErrorActionPreference = 'Stop'
$publisher = Join-Path $PSScriptRoot publish_release.ps1
$start = Get-Location
$envNames = @('GITHUB_REPOSITORY', 'RELEASE_AUTOMATIC', 'RELEASE_SHA', 'RELEASE_RUN_ID', 'RELEASE_BRANCH', 'RELEASE_TAG', 'GITHUB_STEP_SUMMARY')
$savedEnv = @{}
foreach ($key in $envNames) { $savedEnv[$key] = [Environment]::GetEnvironmentVariable($key) }
$global:NexReleaseTestState = @{checks = 0}

# Neither mock can fall through to the network or publish a real release.
function git {
    $global:LASTEXITCODE = 0
    if ($args.Count -eq 2 -and $args[1] -eq 'HEAD') { return $global:NexReleaseTestState.sourceSha }
    if ($args[0] -eq 'rev-parse' -and $args[1] -eq '--verify') {
        if ($global:NexReleaseTestState.tagTarget) { return $global:NexReleaseTestState.tagTarget }
        $global:LASTEXITCODE = 1
        return
    }
    throw "Unexpected git command: $args"
}
function gh {
    $global:LASTEXITCODE = 0
    if ($args[0] -eq 'api') {
        $endpoint = [string]$args[1]
        if ($endpoint.EndsWith('/actions/runs/42')) { return ($global:NexReleaseTestState.run | ConvertTo-Json -Depth 10 -Compress) }
        if ($endpoint.EndsWith('/git/ref/heads/main')) { return (@{object=@{sha=$global:NexReleaseTestState.tip}} | ConvertTo-Json -Compress) }
        if ($endpoint.EndsWith('/releases?per_page=100')) { return (ConvertTo-Json -InputObject $global:NexReleaseTestState.releases -Depth 10 -Compress) }
    }
    if ($args[0] -eq 'run' -and $args[1] -eq 'list') {
        return (ConvertTo-Json -InputObject @(@{databaseId=42;headSha=$global:NexReleaseTestState.sourceSha;conclusion='success'}) -Compress)
    }
    if ($args[0] -eq 'run' -and $args[1] -eq 'download') {
        if ($global:NexReleaseTestState.badDownload) { $global:LASTEXITCODE = 1; return }
        if ($args[2] -ne '42' -or $args[6] -ne "nex-windows-installer-$($global:NexReleaseTestState.sourceSha)") { throw 'Wrong CI artifact selected.' }
        $dest = [string]$args[8]
        $file = Join-Path $dest Nex-Windows-Setup-0.15.0-x64.exe
        [IO.File]::WriteAllBytes($file, [byte[]]@(0x4d, 0x5a, 1, 2, 3))
        $hash = (Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($global:NexReleaseTestState.badChecksum) { $hash = '0' * 64 }
        "$hash  Nex-Windows-Setup-0.15.0-x64.exe" | Set-Content (Join-Path $dest SHA256SUMS)
        if ($global:NexReleaseTestState.missingFile) { Remove-Item $file }
        if ($global:NexReleaseTestState.advanceDuringDownload) { $global:NexReleaseTestState.tip = 'b' * 40 }
        return
    }
    if ($args[0] -eq 'release' -and $args[1] -eq 'create') {
        $global:NexReleaseTestState.publishCalls++
        $target = [array]::IndexOf($args, '--target')
        $notes = [array]::IndexOf($args, '--notes-file')
        if ($args[2] -ne 'v0.15.0' -or $args[$target + 1] -ne $global:NexReleaseTestState.sourceSha) { throw 'Wrong release target.' }
        if ((Get-Content -LiteralPath $args[$notes + 1] -Raw).Trim() -ne '- This version.') { throw 'Wrong release notes.' }
        return
    }
    throw "Unexpected GitHub command: $args"
}

function Invoke-Case([string]$Name, [scriptblock]$Arrange, [bool]$Reject = $false, [int]$Publishes = 1) {
    $caseRoot = Join-Path ([IO.Path]::GetTempPath()) ('nex-publish-test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $caseRoot apps/desktop) -Force | Out-Null
    try {
        Set-Location $caseRoot
        'version: 0.15.0+12' | Set-Content apps/desktop/pubspec.yaml
        "# Changelog`n`n## 0.15.0 — today`n`n- This version.`n`n## 0.14.0 — before`n`n- Old version." | Set-Content apps/desktop/CHANGELOG.md
        $global:NexReleaseTestState.sourceSha = 'a' * 40
        $global:NexReleaseTestState.tip = $global:NexReleaseTestState.sourceSha
        $global:NexReleaseTestState.tagTarget = $null
        $global:NexReleaseTestState.publishCalls = 0
        $global:NexReleaseTestState.badChecksum = $false
        $global:NexReleaseTestState.badDownload = $false
        $global:NexReleaseTestState.missingFile = $false
        $global:NexReleaseTestState.advanceDuringDownload = $false
        $global:NexReleaseTestState.releases = @()
        $global:NexReleaseTestState.run = [pscustomobject]@{head_sha=$global:NexReleaseTestState.sourceSha;status='completed';conclusion='success';event='push';head_branch='main';head_repository=@{full_name='owner/repo'};path='.github/workflows/desktop.yml'}
        $env:GITHUB_REPOSITORY = 'owner/repo'
        $env:RELEASE_AUTOMATIC = 'true'
        $env:RELEASE_SHA = $global:NexReleaseTestState.sourceSha
        $env:RELEASE_RUN_ID = '42'
        $env:RELEASE_BRANCH = 'main'
        $env:RELEASE_TAG = ''
        $env:GITHUB_STEP_SUMMARY = ''
        & $Arrange
        $caught = $null
        try { & $publisher } catch { $caught = $_ }
        if ($Reject -and -not $caught) { throw "$Name should reject publication." }
        if (-not $Reject -and $caught) { throw $caught }
        if ($global:NexReleaseTestState.publishCalls -ne $Publishes) { throw "$Name published $($global:NexReleaseTestState.publishCalls) times, expected $Publishes." }
        $global:NexReleaseTestState.checks++
        Write-Host "PASS: $Name"
    } finally {
        Set-Location $start
        Remove-Item -LiteralPath $caseRoot -Recurse -Force
    }
}

try {
    Invoke-Case 'automatic release uses the exact tested installer and creates its tag' {}
    Invoke-Case 'manual retry uses successful main CI' { $env:RELEASE_AUTOMATIC = 'false'; $env:RELEASE_TAG = 'v0.15.0' }
    Invoke-Case 'failed CI cannot publish' { $global:NexReleaseTestState.run.conclusion = 'failure' } $true 0
    Invoke-Case 'wrong commit cannot publish' { $global:NexReleaseTestState.run.head_sha = 'b' * 40 } $true 0
    Invoke-Case 'pull request CI cannot publish' { $global:NexReleaseTestState.run.event = 'pull_request' } $true 0
    Invoke-Case 'foreign repository cannot publish' { $global:NexReleaseTestState.run.head_repository.full_name = 'foreign/repo' } $true 0
    Invoke-Case 'unrelated workflow cannot publish' { $global:NexReleaseTestState.run.path = '.github/workflows/other.yml' } $true 0
    Invoke-Case 'old completed run skips the newer checkout' { $env:RELEASE_SHA = 'b' * 40 } $false 0
    Invoke-Case 'superseded main cannot publish' { $global:NexReleaseTestState.tip = 'b' * 40 } $false 0
    Invoke-Case 'source advancing during download cannot publish' { $global:NexReleaseTestState.advanceDuringDownload = $true } $false 0
    Invoke-Case 'invalid checksum cannot publish' { $global:NexReleaseTestState.badChecksum = $true } $true 0
    Invoke-Case 'missing installer cannot publish' { $global:NexReleaseTestState.missingFile = $true } $true 0
    Invoke-Case 'failed download cannot publish' { $global:NexReleaseTestState.badDownload = $true } $true 0
    Invoke-Case 'existing tag cannot move to another commit' { $global:NexReleaseTestState.tagTarget = 'b' * 40 } $true 0
    Invoke-Case 'manual tag must match the source version' { $env:RELEASE_TAG = 'v0.14.0' } $true 0
    Invoke-Case 'published versions are idempotent' {
        $global:NexReleaseTestState.releases = @(@{tag_name='v0.15.0';draft=$false;prerelease=$false;assets=@(@{name='Nex-Windows-Setup-0.15.0-x64.exe'},@{name='SHA256SUMS'})})
    } $false 0
    Invoke-Case 'a newer public version cannot be downgraded' {
        $global:NexReleaseTestState.releases = @(@{tag_name='v0.16.0';draft=$false;prerelease=$false;assets=@()})
    } $false 0
    Write-Host "$($global:NexReleaseTestState.checks) release automation checks passed without network access or publication."
} finally {
    foreach ($key in $envNames) { [Environment]::SetEnvironmentVariable($key, $savedEnv[$key]) }
    Remove-Variable NexReleaseTestState -Scope Global
    Set-Location $start
}

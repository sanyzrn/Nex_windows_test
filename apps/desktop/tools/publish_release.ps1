$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-GhJson([string[]]$Command) {
    $value = & gh @Command
    if ($LASTEXITCODE -ne 0) { throw "GitHub command failed: $($Command[0])" }
    return ($value | ConvertFrom-Json)
}

$repo = $env:GITHUB_REPOSITORY
$automatic = $env:RELEASE_AUTOMATIC -eq 'true'
$sha = (git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[a-f0-9]{40}$') { throw 'Cannot identify release source.' }
if ($automatic -and $sha -ne $env:RELEASE_SHA) {
    Write-Host 'Skipping an older CI run; the current main commit must finish its own CI.'
    return
}

$versionMatch = Select-String -LiteralPath apps/desktop/pubspec.yaml -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)$'
if (-not $versionMatch) { throw 'Missing desktop version.' }
$version = $versionMatch.Matches[0].Groups[1].Value
$tag = "v$version"
if ($env:RELEASE_TAG -and $env:RELEASE_TAG -ne $tag) { throw 'Release tag and desktop source version differ.' }

if ($automatic) {
    $runId = $env:RELEASE_RUN_ID
    if ($runId -notmatch '^\d+$') { throw 'Missing successful CI run.' }
} else {
    $runs = @(Read-GhJson -Command @('run', 'list', '--repo', $repo, '--workflow', 'desktop.yml', '--commit', $sha, '--status', 'success', '--limit', '20', '--json', 'databaseId,headSha,conclusion'))
    $passed = @($runs | Where-Object { $_.headSha -eq $sha -and $_.conclusion -eq 'success' })
    if ($passed.Count -eq 0) { throw 'No successful Windows CI exists for this source commit.' }
    $runId = [string]$passed[0].databaseId
}
$run = Read-GhJson -Command @('api', "repos/$repo/actions/runs/$runId")
if ($run.head_sha -ne $sha -or $run.status -ne 'completed' -or
    $run.conclusion -ne 'success' -or $run.event -ne 'push' -or
    $run.head_branch -notin @('main', 'master') -or
    $run.head_repository.full_name -ne $repo -or
    $run.path -ne '.github/workflows/desktop.yml') {
    throw 'Release requires successful, trusted main-branch Windows CI for this exact commit.'
}
if ($automatic -and $run.head_branch -ne $env:RELEASE_BRANCH) { throw 'CI branch mismatch.' }

function Test-CurrentSource {
    if (-not $automatic) { return $true }
    $tip = Read-GhJson -Command @('api', "repos/$repo/git/ref/heads/$($run.head_branch)")
    return $tip.object.sha -eq $sha
}
if (-not (Test-CurrentSource)) { Write-Host 'Skipping superseded source.'; return }

$releases = @(Read-GhJson -Command @('api', "repos/$repo/releases?per_page=100"))
$existing = @($releases | Where-Object { $_.tag_name -eq $tag })
$name = "Nex-Windows-Setup-$version-x64.exe"
if ($existing.Count -gt 0) {
    $assetNames = @($existing[0].assets | ForEach-Object { $_.name })
    if ($existing[0].draft -or $existing[0].prerelease -or
        $name -notin $assetNames -or 'SHA256SUMS' -notin $assetNames) {
        throw 'An incomplete/draft release already uses this version; inspect it before retrying.'
    }
    Write-Host "$tag is already published. Published versions are not overwritten; bump the source version for the next update."
    return
}
foreach ($release in $releases) {
    if (-not $release.draft -and -not $release.prerelease -and
        $release.tag_name -match '^v(\d+\.\d+\.\d+)$' -and
        [version]$Matches[1] -gt [version]$version) {
        Write-Host 'Skipping an older version; the latest release must not move backwards.'
        return
    }
}
$tagSha = git rev-parse --verify --quiet "$tag`^{commit}"
if ($LASTEXITCODE -eq 0 -and $tagSha.Trim() -ne $sha) { throw 'Existing tag points to another source commit.' }

$assets = Join-Path ([IO.Path]::GetTempPath()) ('nex-release-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $assets | Out-Null
try {
    gh run download $runId --repo $repo --name "nex-windows-installer-$sha" --dir $assets
    if ($LASTEXITCODE -ne 0) { throw 'Could not download the tested installer artifact.' }
    $setup = Join-Path $assets $name
    $sums = Join-Path $assets SHA256SUMS
    if (-not (Test-Path -LiteralPath $setup) -or -not (Test-Path -LiteralPath $sums)) { throw 'Release artifact is incomplete.' }
    $checksum = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
    if ((Get-Content -LiteralPath $sums -Raw).Trim() -ne "$checksum  $name") { throw 'Installer checksum verification failed.' }
    $bytes = [IO.File]::ReadAllBytes($setup)
    if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) { throw 'Installer is not a Windows executable.' }
    $changelog = Get-Content -LiteralPath apps/desktop/CHANGELOG.md -Raw
    $section = [regex]::Match($changelog, '(?ms)^##\s+' + [regex]::Escape($version) + '[^\r\n]*\r?\n(.*?)(?=^## |\z)')
    if (-not $section.Success -or -not $section.Groups[1].Value.Trim()) { throw 'Missing release notes for this version.' }
    $notes = Join-Path $assets release-notes.md
    $section.Groups[1].Value.Trim() | Set-Content -LiteralPath $notes -Encoding utf8
    if (-not (Test-CurrentSource)) { Write-Host 'Skipping source superseded during artifact verification.'; return }
    # --target creates the tag at the tested commit when it does not exist yet.
    gh release create $tag $setup $sums --repo $repo --target $sha --title "Nex Windows $version" --notes-file $notes --latest
    if ($LASTEXITCODE -ne 0) { throw 'GitHub release publication failed.' }
    Write-Host "Published https://github.com/$repo/releases/tag/$tag"
    if ($env:GITHUB_STEP_SUMMARY) {
        "Published [Nex Windows $version](https://github.com/$repo/releases/tag/$tag) from verified CI run $runId." | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
    }
} finally {
    Remove-Item -LiteralPath $assets -Recurse -Force
}

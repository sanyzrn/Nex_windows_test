$ErrorActionPreference = 'Stop'
$tag = $env:RELEASE_TAG
if ($tag -notmatch '^v\d+\.\d+\.\d+$') { throw 'Expected a semantic version tag such as v0.12.2.' }
$versionMatch = Select-String -LiteralPath apps/desktop/pubspec.yaml -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)$'
if (-not $versionMatch) { throw 'Missing desktop version.' }
$version = $versionMatch.Matches[0].Groups[1].Value
if ($tag -ne "v$version") { throw 'Release tag and desktop source version differ.' }
$sha = (git rev-parse HEAD).Trim()
$tagSha = (git rev-parse "$tag`^{commit}").Trim()
if ($sha -ne $tagSha) { throw 'Checkout is not the requested release tag.' }
$runs = gh run list --repo $env:GITHUB_REPOSITORY --workflow desktop.yml --commit $sha --status success --limit 20 --json databaseId,headSha,conclusion | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Could not read CI results.' }
$passed = @($runs | Where-Object { $_.headSha -eq $sha -and $_.conclusion -eq 'success' })
if ($passed.Count -eq 0) { throw 'No successful Desktop Windows CI run exists for this exact source commit.' }
$existing = gh release list --repo $env:GITHUB_REPOSITORY --limit 100 --json tagName | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect existing releases.' }
if ($existing | Where-Object { $_.tagName -eq $tag }) { throw 'Release already exists; published assets are not overwritten.' }
New-Item -ItemType Directory -Path release-assets -Force | Out-Null
gh run download $passed[0].databaseId --repo $env:GITHUB_REPOSITORY --name "nex-windows-installer-$sha" --dir release-assets
if ($LASTEXITCODE -ne 0) { throw 'Could not download the tested installer artifact.' }
$name = "Nex-Windows-Setup-$version-x64.exe"
$setup = Join-Path release-assets $name
$sums = Join-Path release-assets SHA256SUMS
if (-not (Test-Path -LiteralPath $setup) -or -not (Test-Path -LiteralPath $sums)) { throw 'Release artifact is incomplete.' }
$checksum = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
$expected = (Get-Content -LiteralPath $sums -Raw).Trim()
if ($expected -ne "$checksum  $name") { throw 'Installer checksum verification failed.' }
gh release create $tag $setup $sums --repo $env:GITHUB_REPOSITORY --verify-tag --title "Nex Windows $version" --generate-notes --latest
if ($LASTEXITCODE -ne 0) { throw 'GitHub release publication failed.' }

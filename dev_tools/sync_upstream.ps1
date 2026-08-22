param(
    [switch]$Push
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BundledGit = Join-Path $ProjectRoot 'toolkit\Git\mingw64\bin\git.exe'
$Git = if (Test-Path -LiteralPath $BundledGit) { $BundledGit } else { 'git' }

function Invoke-Git {
    & $Git -c "safe.directory=$ProjectRoot" -C $ProjectRoot @args
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($args -join ' ')"
    }
}

$TrackedChanges = & $Git -c "safe.directory=$ProjectRoot" -C $ProjectRoot status --porcelain --untracked-files=no
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect the working tree.'
}
if ($TrackedChanges) {
    throw 'Tracked files contain uncommitted changes. Commit or stash them before syncing.'
}

$CurrentBranch = (& $Git -c "safe.directory=$ProjectRoot" -C $ProjectRoot branch --show-current).Trim()
if ($CurrentBranch -ne 'master') {
    throw "Switch to master before syncing. Current branch: $CurrentBranch"
}

Invoke-Git fetch --prune upstream master

& $Git -c "safe.directory=$ProjectRoot" -C $ProjectRoot merge-base --is-ancestor upstream/master HEAD
if ($LASTEXITCODE -eq 0) {
    Write-Host 'Already up to date with upstream/master.'
    exit 0
}

try {
    Invoke-Git merge --no-edit -X ours upstream/master
}
catch {
    & $Git -c "safe.directory=$ProjectRoot" -C $ProjectRoot merge --abort 2>$null
    throw 'Upstream has a structural conflict. The merge was aborted without changing your branch.'
}

if ($Push) {
    Invoke-Git push origin master
    Write-Host 'Upstream changes were merged and pushed to origin/master.'
}
else {
    Write-Host 'Upstream changes were merged locally. Review them, then push with:'
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\dev_tools\sync_upstream.ps1 -Push'
}


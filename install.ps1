#!/usr/bin/env pwsh
# Loop Engineering · 一键安装到目标项目(Windows)
# 注意:本文件需 PowerShell 7+(pwsh)。Windows PS 5.1 不支持。
#
# Usage:
#   pwsh -File .\install.ps1 -TargetProject 'C:\path\to\project'
#   pwsh -File .\install.ps1 -TargetProject 'C:\path\to\project' -SkipSkills

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetProject,

    [switch]$SkipSkills,

    [switch]$SkipCommands
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path -LiteralPath $TargetProject -PathType Container)) {
    Write-Error "Target directory does not exist: $TargetProject"
    exit 2
}

# 1. cp hooks
Write-Host "[1/3] Installing 10 hooks to $TargetProject\.claude\hooks\" -ForegroundColor Cyan
$hooksDest = Join-Path $TargetProject ".claude\hooks"
if (-not (Test-Path -LiteralPath $hooksDest)) {
    New-Item -ItemType Directory -Path $hooksDest -Force | Out-Null
}
Copy-Item -Path (Join-Path $ScriptDir "templates\hooks\*") -Destination $hooksDest -Recurse -Force
Write-Host "  ok"

# 2. cp skills
if (-not $SkipSkills) {
    $skillDest = if ($env:CODEX_SKILLS_DIR) { $env:CODEX_SKILLS_DIR } else { Join-Path $env:USERPROFILE ".codex\skills" }
    Write-Host "[2/3] Installing 3 skills to $skillDest" -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $skillDest)) {
        New-Item -ItemType Directory -Path $skillDest -Force | Out-Null
    }
    Get-ChildItem -Path (Join-Path $ScriptDir "templates\skills") -Directory | ForEach-Object {
        $skillName = $_.Name
        $skillMd = Join-Path $_.FullName "SKILL.md"
        if (Test-Path -LiteralPath $skillMd -PathType Leaf) {
            $destDir = Join-Path $skillDest $skillName
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $skillMd -Destination (Join-Path $destDir "SKILL.md") -Force
            Write-Host "  installed $skillName"
        } else {
            Write-Warning "$skillName has no SKILL.md, skipped"
        }
    }
} else {
    Write-Host "[2/3] Skills skipped (-SkipSkills)"
}

# 3. cp commands
if (-not $SkipCommands) {
    $cmdDest = if ($env:CLAUDE_COMMANDS_DIR) { $env:CLAUDE_COMMANDS_DIR } else { Join-Path $env:USERPROFILE ".claude\commands" }
    Write-Host "[3/3] Installing deploy-verify command to $cmdDest" -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $cmdDest)) {
        New-Item -ItemType Directory -Path $cmdDest -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $ScriptDir "templates\commands\deploy-verify.md") -Destination (Join-Path $cmdDest "deploy-verify.md") -Force
    Write-Host "  ok"
} else {
    Write-Host "[3/3] Commands skipped (-SkipCommands)"
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Installation complete" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Verify hooks:"
Write-Host "     bash $hooksDest\guard-rails-test.sh"
Write-Host ""
Write-Host "  2. Edit $TargetProject\.claude\settings.json to attach hooks to your project"
Write-Host "     (See templates\hooks\README.md for the settings.json schema)"
Write-Host ""
Write-Host "  3. Initialize LoopX in the target project:"
Write-Host "     cd $TargetProject"
Write-Host "     loopx doctor"
Write-Host ""
Write-Host "Docs: $ScriptDir\README.md"
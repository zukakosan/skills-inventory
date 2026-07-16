<#
.SYNOPSIS
  このリポジトリの .github/skills/ 配下の各スキルを ~/.copilot/skills/ へリンクする。

.DESCRIPTION
  各スキルフォルダを ~/.copilot/skills/<name> へジャンクション（既定）または
  シンボリックリンクで接続し、全ワークスペースから参照可能にする。
  リポジトリ側（.github/skills/）が「ソース（git 管理）」、~/.copilot/skills/ 側が「参照先」。
  ※このリポジトリを開いている間は .github/skills/ が自動認識されるため、
    リンクは「他のワークスペースからも使いたい」場合にのみ必要。

.PARAMETER Symbolic
  ジャンクションではなくシンボリックリンクを作成する（管理者権限か開発者モードが必要）。

.PARAMETER Force
  リンク先に既存のフォルダ/リンクがある場合でも作り直す。

.EXAMPLE
  ./link-skills.ps1
  ./link-skills.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Symbolic,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoSkills   = Join-Path $PSScriptRoot '.github\skills'
$globalSkills = Join-Path $env:USERPROFILE '.copilot\skills'

if (-not (Test-Path $repoSkills)) {
    throw ".github\skills フォルダが見つかりません: $repoSkills"
}
if (-not (Test-Path $globalSkills)) {
    New-Item -ItemType Directory -Path $globalSkills | Out-Null
    Write-Host "作成: $globalSkills" -ForegroundColor Green
}

$linkType = if ($Symbolic) { 'SymbolicLink' } else { 'Junction' }

Get-ChildItem -Path $repoSkills -Directory | ForEach-Object {
    $name   = $_.Name
    $source = $_.FullName
    $target = Join-Path $globalSkills $name

    if (-not (Test-Path (Join-Path $source 'SKILL.md'))) {
        Write-Host "スキップ（SKILL.md なし）: $name" -ForegroundColor DarkYellow
        return
    }

    $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($existing) {
        $isLink = $null -ne $existing.LinkType
        if ($isLink -and $existing.Target -eq $source -and -not $Force) {
            Write-Host "OK（既存リンク）: $name" -ForegroundColor DarkGray
            return
        }
        if (-not $isLink -and -not $Force) {
            Write-Host "警告（実体フォルダが存在。-Force で上書き）: $target" -ForegroundColor Yellow
            return
        }
        if ($isLink) {
            (Get-Item -LiteralPath $target).Delete()
        } else {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }

    New-Item -ItemType $linkType -Path $target -Target $source | Out-Null
    Write-Host "リンク作成: $name  ->  $source  ($linkType)" -ForegroundColor Green
}

Write-Host "`n完了。VS Code を再読み込みしてください（Developer: Reload Window）。" -ForegroundColor Cyan

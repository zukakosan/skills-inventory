<#
.SYNOPSIS
  このリポジトリのスキル（.github/skills/）とカスタムエージェント（.github/agents/）を
  ユーザープロファイルへリンクし、全ワークスペースから参照可能にする。

.DESCRIPTION
  - スキル: 各スキルフォルダを ~/.copilot/skills/<name> へジャンクション（既定）または
    シンボリックリンクで接続する。
  - エージェント: 各 *.agent.md を VS Code のユーザー prompts フォルダ
    (%APPDATA%\Code\User\prompts) へリンクする。エージェントは単一ファイルのため、
    既定はハードリンク（管理者権限不要・同一ボリューム限定）、-Symbolic 指定時はシンボリックリンク。
    別ボリューム等でリンクできない場合はコピーにフォールバックする。

  リポジトリ側（.github/）が「ソース（git 管理）」、ユーザープロファイル側が「参照先」。
  ※このリポジトリを開いている間は .github/skills/ と .github/agents/ が自動認識されるため、
    リンクは「他のワークスペースからも使いたい」場合にのみ必要。

.PARAMETER Symbolic
  ジャンクション/ハードリンクではなくシンボリックリンクを作成する（管理者権限か開発者モードが必要）。

.PARAMETER Force
  リンク先に既存のフォルダ/ファイル/リンクがある場合でも作り直す。

.EXAMPLE
  ./link-customizations.ps1
  ./link-customizations.ps1 -Force
  ./link-customizations.ps1 -Symbolic
#>
[CmdletBinding()]
param(
    [switch]$Symbolic,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoSkills   = Join-Path $PSScriptRoot '.github\skills'
$repoAgents   = Join-Path $PSScriptRoot '.github\agents'
$globalSkills = Join-Path $env:USERPROFILE '.copilot\skills'
$globalAgents = Join-Path $env:APPDATA 'Code\User\prompts'

# ---- スキルのリンク（フォルダ単位） ----
if (Test-Path $repoSkills) {
    if (-not (Test-Path $globalSkills)) {
        New-Item -ItemType Directory -Path $globalSkills | Out-Null
        Write-Host "作成: $globalSkills" -ForegroundColor Green
    }

    $skillLinkType = if ($Symbolic) { 'SymbolicLink' } else { 'Junction' }

    Write-Host "`n== スキル ==" -ForegroundColor Cyan
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

        New-Item -ItemType $skillLinkType -Path $target -Target $source | Out-Null
        Write-Host "リンク作成: $name  ->  $source  ($skillLinkType)" -ForegroundColor Green
    }
} else {
    Write-Host ".github\skills フォルダが見つかりません（スキップ）: $repoSkills" -ForegroundColor DarkYellow
}

# ---- カスタムエージェントのリンク（ファイル単位） ----
if (Test-Path $repoAgents) {
    if (-not (Test-Path $globalAgents)) {
        New-Item -ItemType Directory -Path $globalAgents | Out-Null
        Write-Host "作成: $globalAgents" -ForegroundColor Green
    }

    $agentLinkType = if ($Symbolic) { 'SymbolicLink' } else { 'HardLink' }

    Write-Host "`n== エージェント ==" -ForegroundColor Cyan
    Get-ChildItem -Path $repoAgents -Filter '*.agent.md' -File | ForEach-Object {
        $name   = $_.Name
        $source = $_.FullName
        $target = Join-Path $globalAgents $name

        $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        if ($existing) {
            $isLink = $null -ne $existing.LinkType
            if ($isLink -and $existing.Target -eq $source -and -not $Force) {
                Write-Host "OK（既存リンク）: $name" -ForegroundColor DarkGray
                return
            }
            if (-not $isLink -and -not $Force) {
                Write-Host "警告（実体ファイルが存在。-Force で上書き）: $target" -ForegroundColor Yellow
                return
            }
            Remove-Item -LiteralPath $target -Force
        }

        try {
            New-Item -ItemType $agentLinkType -Path $target -Target $source -ErrorAction Stop | Out-Null
            Write-Host "リンク作成: $name  ->  $source  ($agentLinkType)" -ForegroundColor Green
        } catch {
            Copy-Item -LiteralPath $source -Destination $target -Force
            Write-Host "コピー（リンク不可のためコピー）: $name  ->  $target" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host ".github\agents フォルダが見つかりません（スキップ）: $repoAgents" -ForegroundColor DarkYellow
}

Write-Host "`n完了。VS Code を再読み込みしてください（Developer: Reload Window）。" -ForegroundColor Cyan

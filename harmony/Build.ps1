[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DevEcoRoot,
    [ValidateSet('debug', 'release')]
    [string]$BuildMode = 'debug'
)

$ErrorActionPreference = 'Stop'
$studio = (Resolve-Path -LiteralPath $DevEcoRoot).Path
$hvigor = Join-Path $studio 'tools\hvigor\bin\hvigorw.bat'
if (-not (Test-Path -LiteralPath $hvigor)) { throw '指定目录中没有 DevEco Studio 的 Hvigor。' }
if ($PSScriptRoot -match '[^\x00-\x7f]') { throw '请从英文路径构建此鸿蒙工程。' }

$env:DEVECO_SDK_HOME = Join-Path $studio 'sdk'
$env:JAVA_HOME = Join-Path $studio 'jbr'
$env:HVIGOR_USER_HOME = Join-Path $PSScriptRoot '.hvigor\user'
$env:npm_config_cache = Join-Path $PSScriptRoot '.hvigor\npm-cache'
$env:Path = "$studio\tools\node;$studio\tools\ohpm\bin;" + $env:Path

Push-Location -LiteralPath $PSScriptRoot
try {
    & $hvigor assembleHap --no-daemon -p 'product=default' -p "buildMode=$BuildMode"
    if ($LASTEXITCODE -ne 0) { throw "Hvigor 构建失败，退出码 $LASTEXITCODE。" }
    $unsigned = Join-Path $PSScriptRoot 'entry\build\default\outputs\default\entry-default-unsigned.hap'
    if (Test-Path -LiteralPath $unsigned) {
        $artifactDir = Join-Path $PSScriptRoot 'artifacts'
        New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
        $artifact = Join-Path $artifactDir 'iwut-harmony-unsigned.hap'
        Copy-Item -LiteralPath $unsigned -Destination $artifact -Force
        Write-Output $artifact
    }
} finally {
    Pop-Location
}

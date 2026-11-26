param([string]$OutputPath = (Join-Path $PSScriptRoot '..\FilterLab.exe'))
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
$source = Join-Path $PSScriptRoot 'FilterLabLauncher.cs'
$icon = Join-Path $PSScriptRoot '..\filterlab-neon.ico'
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ /codepage:65001 /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/win32icon:$icon" "/out:$OutputPath" $source
if ($LASTEXITCODE -ne 0) { throw "Launcher build failed ($LASTEXITCODE)." }
Get-Item -LiteralPath $OutputPath

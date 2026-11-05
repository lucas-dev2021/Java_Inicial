<#
  Gera o PainelHelpDesk.exe a partir do PainelHelpDesk.ps1 (rode no Windows, PowerShell 5.1).
  Uso:  powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
#>
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot

if (-not (Get-Module -ListAvailable ps2exe)) {
    Install-PackageProvider NuGet -Force -Scope CurrentUser | Out-Null
    Install-Module ps2exe -Scope CurrentUser -Force
}
Import-Module ps2exe

$params = @{
    inputFile    = Join-Path $dir 'PainelHelpDesk.ps1'
    outputFile   = Join-Path $dir 'PainelHelpDesk.exe'
    noConsole    = $true
    requireAdmin = $true
    STA          = $true
    title        = 'Painel Help Desk'
    product      = 'Painel Help Desk - Sandéleh Alimentos'
    company      = 'Sandéleh Alimentos'
    version      = '2.0.0.0'
}
$ico = Join-Path $dir 'icone.ico'
if (Test-Path $ico) { $params.iconFile = $ico }

Invoke-ps2exe @params
Write-Host "Gerado: $($params.outputFile)"

@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

:: ============================================================
::  CONFIGURAÇÃO (edite aqui)
:: ============================================================
set "EMPRESA=SANDELEH ALIMENTOS"
set "TITULO=TI Console - %EMPRESA%"
set "RAIZ=%~dp0"
:: Saída fica no próprio pen drive, separada por máquina
set "PASTA_SAIDA=%RAIZ%Saida\%COMPUTERNAME%"

:: ============================================================
::  AUTO-ELEVAÇÃO (reabre como Administrador se necessário)
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

title %TITULO%
color 0A
mode con: cols=90 lines=50
cd /d "%RAIZ%"
if not exist "%PASTA_SAIDA%" mkdir "%PASTA_SAIDA%" 2>nul
:: Fallback se o pen drive estiver protegido contra gravação
if not exist "%PASTA_SAIDA%" (
    set "PASTA_SAIDA=%TEMP%\HelpDesk_Saida"
    mkdir "!PASTA_SAIDA!" 2>nul
)

:MENU
cls
echo ==========================================================================
echo   _   _ _____ _     ____    ____  _____ ____  _  __
echo  ^| ^| ^| ^| ____^| ^|   ^|  _ \  ^|  _ \^| ____/ ___^|^| ^|/ /
echo  ^| ^|_^| ^|  _^| ^| ^|   ^| ^|_) ^| ^| ^| ^| ^|  _^| \___ \^| ' /
echo  ^|  _  ^| ^|___^| ^|___^|  __/  ^| ^|_^| ^| ^|___ ___) ^| . \
echo  ^|_^| ^|_^|_____^|_____^|_^|     ^|____/^|_____^|____/^|_^|\_\
echo ==========================================================================
echo                 PAINEL DE SISTEMAS - INFRAESTRUTURA
echo                          %EMPRESA%
echo ==========================================================================
echo.
echo --- MANUTENÇÃO E REPARO DO SISTEMA ---
echo  [1] Limpeza de Arquivos Temporários
echo  [2] Limpeza de Disco Avançada
echo  [3] Esvaziar Lixeira do Windows
echo  [4] Verificação e Reparo de Arquivos do Windows (SFC)
echo  [5] Reparo da Imagem do Windows (DISM)
echo  [6] Verificação de Integridade do HD ou SSD (CHKDSK)
echo  [7] Diagnóstico de Saúde do Disco (S.M.A.R.T. / SSD)
echo.
echo --- REDE E CONECTIVIDADE ---
echo  [8] Reset de Rede - Reset de IP, Winsock e Flush DNS
echo  [9] Informações de Rede Completas
echo [10] Testes de Conectividade
echo [11] Abrir Conexões de Rede
echo [12] Reconectar / Mapear Pastas de Rede
echo [13] Reparar Pastas de Rede Inacessíveis (Sem Reiniciar)
echo.
echo --- DIAGNÓSTICO E SISTEMA ---
echo [14] Informações do Sistema
echo [15] Gerenciador de Dispositivos
echo [16] Monitor de Recursos e Processos
echo [17] Limpar Fila Retida e Reiniciar Spooler de Impressão
echo.
echo --- GESTÃO DE DRIVERS ---
echo [18] Verificar e Corrigir Drivers com Erro Crítico
echo [19] Instalar Atualizações de Drivers via Windows Update
echo [20] Analisar Drivers Desatualizados - Modo Relatório Web
echo [21] Fazer Backup de Todos os Drivers Instalados
echo.
echo --- GESTÃO E SOFTWARE ---
echo [22] Atualizar Diretivas de Grupo
echo [23] Gerar Relatório de Políticas de Grupo
echo [24] Listar Atualizações de Software Disponíveis (Winget)
echo [25] Atualizar Todos os Softwares (Winget)
echo.
echo  [0] Sair
echo ==========================================================================
set "op="
set /p "op=Escolha uma opção: "

if "%op%"=="0"  goto SAIR
if "%op%"=="1"  goto OP01
if "%op%"=="2"  goto OP02
if "%op%"=="3"  goto OP03
if "%op%"=="4"  goto OP04
if "%op%"=="5"  goto OP05
if "%op%"=="6"  goto OP06
if "%op%"=="7"  goto OP07
if "%op%"=="8"  goto OP08
if "%op%"=="9"  goto OP09
if "%op%"=="10" goto OP10
if "%op%"=="11" goto OP11
if "%op%"=="12" goto OP12
if "%op%"=="13" goto OP13
if "%op%"=="14" goto OP14
if "%op%"=="15" goto OP15
if "%op%"=="16" goto OP16
if "%op%"=="17" goto OP17
if "%op%"=="18" goto OP18
if "%op%"=="19" goto OP19
if "%op%"=="20" goto OP20
if "%op%"=="21" goto OP21
if "%op%"=="22" goto OP22
if "%op%"=="23" goto OP23
if "%op%"=="24" goto OP24
if "%op%"=="25" goto OP25
echo Opção inválida.
timeout /t 2 >nul
goto MENU

:: ------------------------- MANUTENÇÃO -------------------------
:OP01
cls & echo [1] Limpando temporários...
del /q /f /s "%TEMP%\*" >nul 2>&1
for /d %%D in ("%TEMP%\*") do rd /s /q "%%D" >nul 2>&1
del /q /f /s "%WINDIR%\Temp\*" >nul 2>&1
for /d %%D in ("%WINDIR%\Temp\*") do rd /s /q "%%D" >nul 2>&1
del /q /f /s "%WINDIR%\Prefetch\*" >nul 2>&1
echo Concluído.
goto FIM

:OP02
cls & echo [2] Abrindo Limpeza de Disco (configure e confirme)...
cleanmgr /sageset:1
cleanmgr /sagerun:1
goto FIM

:OP03
cls & echo [3] Esvaziando lixeira...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
echo Concluído.
goto FIM

:OP04
cls & echo [4] sfc /scannow (pode demorar)...
sfc /scannow
goto FIM

:OP05
cls & echo [5] DISM RestoreHealth (requer internet/WU)...
DISM /Online /Cleanup-Image /RestoreHealth
goto FIM

:OP06
cls & echo [6] CHKDSK em modo leitura (C:). Para reparar: chkdsk C: /f /r
chkdsk C: /scan
goto FIM

:OP07
cls & echo [7] Saúde dos discos...
powershell -NoProfile -Command "Get-PhysicalDisk | Select FriendlyName,MediaType,HealthStatus,OperationalStatus,@{n='GB';e={[math]::Round($_.Size/1GB)}} | Format-Table -Auto; Get-PhysicalDisk | Get-StorageReliabilityCounter | Select DeviceId,Temperature,Wear,ReadErrorsTotal,WriteErrorsTotal,PowerOnHours | Format-Table -Auto"
wmic diskdrive get model,status
goto FIM

:: ------------------------- REDE -------------------------
:OP08
cls & echo [8] Reset de rede. Será necessário reiniciar o computador.
set "c="
set /p "c=Confirmar? (S/N): "
if /i not "%c%"=="S" goto MENU
ipconfig /flushdns
netsh winsock reset
netsh int ip reset
netsh int ipv6 reset
ipconfig /release
ipconfig /renew
echo Reinicie a máquina para concluir.
goto FIM

:OP09
cls & ipconfig /all
goto FIM

:OP10
cls & echo [10] Testes de conectividade
set "gw="
for /f "tokens=3" %%G in ('route print 0.0.0.0 ^| findstr /r "^ *0.0.0.0 .*0.0.0.0"') do if not defined gw set "gw=%%G"
echo Gateway: %gw%
if defined gw ping -n 3 %gw%
ping -n 3 8.8.8.8
nslookup google.com
set "h="
set /p "h=Host/IP para tracert (Enter para pular): "
if defined h tracert %h%
goto FIM

:OP11
start "" ncpa.cpl
goto MENU

:OP12
cls & echo [12] Mapear pasta de rede
net use
set "l="
set "p="
set /p "l=Letra da unidade (ex: Z): "
set /p "p=Caminho UNC (ex: \\servidor\pasta): "
if not defined l goto FIM
net use %l%: "%p%" /persistent:yes
goto FIM

:OP13
cls & echo [13] Reparando acesso a pastas de rede (sem reiniciar)...
net use * /delete /y
ipconfig /flushdns
nbtstat -R
nbtstat -RR
klist purge
klist -li 0x3e7 purge
net stop lanmanworkstation /y
net start lanmanworkstation
net start workstation >nul 2>&1
echo Concluído. Remapeie as unidades (opção 12).
goto FIM

:: ------------------------- DIAGNÓSTICO -------------------------
:OP14
cls & systeminfo
goto FIM

:OP15
start "" devmgmt.msc
goto MENU

:OP16
start "" resmon.exe
start "" taskmgr.exe
goto MENU

:OP17
cls & echo [17] Reiniciando spooler e limpando fila...
net stop spooler /y
del /q /f /s "%WINDIR%\System32\spool\PRINTERS\*" >nul 2>&1
net start spooler
echo Concluído.
goto FIM

:: ------------------------- DRIVERS -------------------------
:OP18
cls & echo [18] Dispositivos com erro:
powershell -NoProfile -Command "Get-PnpDevice -PresentOnly | Where-Object Status -eq 'Error' | Select Class,FriendlyName,InstanceId,Problem | Format-Table -Auto"
set "c="
set /p "c=Reescanear dispositivos e tentar corrigir? (S/N): "
if /i "%c%"=="S" pnputil /scan-devices
goto FIM

:OP19
cls & echo [19] Drivers via Windows Update (módulo PSWindowsUpdate)
powershell -NoProfile -ExecutionPolicy Bypass -Command "if(-not (Get-Module -ListAvailable PSWindowsUpdate)){Install-PackageProvider NuGet -Force | Out-Null; Install-Module PSWindowsUpdate -Force -Scope AllUsers}; Import-Module PSWindowsUpdate; Get-WindowsUpdate -MicrosoftUpdate -Category Drivers -Install -AcceptAll -IgnoreReboot"
goto FIM

:OP20
cls & echo [20] Gerando relatório de drivers...
set "R=%PASTA_SAIDA%\Drivers_%COMPUTERNAME%.html"
powershell -NoProfile -Command "Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceName | Sort-Object DriverDate | Select DeviceName,Manufacturer,DriverVersion,@{n='Data';e={$_.DriverDate.ToString('yyyy-MM-dd')}} | ConvertTo-Html -Title 'Drivers' | Out-File -Encoding utf8 '%R%'"
start "" "%R%"
goto FIM

:OP21
cls & echo [21] Backup de drivers...
set "D=%PASTA_SAIDA%\Drivers_%COMPUTERNAME%_%date:~-4%%date:~3,2%%date:~0,2%"
mkdir "%D%" 2>nul
powershell -NoProfile -Command "Export-WindowsDriver -Online -Destination '%D%'"
echo Salvo em: %D%
goto FIM

:: ------------------------- GESTÃO -------------------------
:OP22
cls & gpupdate /force
goto FIM

:OP23
cls & echo [23] Gerando relatório GPO...
set "R=%PASTA_SAIDA%\GPO_%COMPUTERNAME%.html"
gpresult /h "%R%" /f
start "" "%R%"
goto FIM

:OP24
cls & winget upgrade --accept-source-agreements
goto FIM

:OP25
cls & echo [25] Atualizando todos os softwares...
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
goto FIM

:FIM
echo.
echo ------------------------------------------------------------
pause
goto MENU

:SAIR
endlocal
exit /b

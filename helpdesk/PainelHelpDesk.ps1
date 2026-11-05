<#
  Painel Help Desk - Sandéleh Alimentos
  Interface WinForms (PowerShell 5.1). Pode rodar como .ps1 ou ser compilado em .exe (Build-Exe.ps1).
  Salve este arquivo como UTF-8 com BOM.
#>

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
[System.Windows.Forms.Application]::add_ThreadException({
    param($s, $e)
    [System.Windows.Forms.MessageBox]::Show($e.Exception.Message, 'Erro no painel', 'OK', 'Error') | Out-Null
})

# ---------------------------------------------------------------- Configuração
$script:Empresa = 'SANDÉLEH'
$script:Versao  = '2.0'

# ---------------------------------------------------------------- Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    if ($PSCommandPath) {
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    } else {
        [System.Windows.Forms.MessageBox]::Show('Execute o painel como Administrador.', 'Painel Help Desk', 'OK', 'Warning') | Out-Null
    }
    exit
}

# ---------------------------------------------------------------- Pastas
$script:Raiz = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$script:Saida = Join-Path $script:Raiz ("Saida\" + $env:COMPUTERNAME)
try { New-Item -ItemType Directory -Path $script:Saida -Force -ErrorAction Stop | Out-Null }
catch {
    $script:Saida = Join-Path $env:TEMP 'HelpDesk_Saida'
    New-Item -ItemType Directory -Path $script:Saida -Force | Out-Null
}
$script:LogDir = Join-Path $script:Saida 'logs'
New-Item -ItemType Directory -Path $script:LogDir -Force -ErrorAction SilentlyContinue | Out-Null

$srv = Join-Path $script:Raiz 'servidores.txt'
if (-not (Test-Path $srv)) {
    @(
        '# Lista de hosts:porta para o teste de portas (uma por linha)',
        '# Exemplo:',
        '# servidor-arquivos:445',
        '# 192.168.0.10:3389'
    ) | Set-Content -Path $srv -Encoding UTF8 -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- Identidade visual
function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$cRed = C '#d61f2a'; $cInk = C '#141a20'; $cText2 = C '#5c6773'; $cLabel = C '#8a95a1'
$cBg2 = C '#f4f6f8'; $cLine = C '#e6e9ee'; $cLine2 = C '#d3d8df'
$cAmber = C '#c67d00'; $cGreen = C '#1f9d63'; $cBlue = C '#2563a8'; $cWhite = C '#ffffff'

$fams = (New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name }
function Pick($list) { foreach ($n in $list) { if ($fams -contains $n) { return $n } }; return $list[-1] }
$FT = Pick @('Archivo', 'Segoe UI')
$FB = Pick @('Inter', 'Segoe UI')
$FM = Pick @('Roboto Mono', 'Consolas')
function F($fam, $size, [bool]$bold = $false) {
    $st = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font($fam, [single]$size, $st)
}
function RoundPath($r, $rad) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $rad * 2
    $p.AddArc($r.X, $r.Y, $d, $d, 180, 90)
    $p.AddArc($r.Right - $d, $r.Y, $d, $d, 270, 90)
    $p.AddArc($r.Right - $d, $r.Bottom - $d, $d, $d, 0, 90)
    $p.AddArc($r.X, $r.Bottom - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    $p
}
function DrawSpaced($g, [string]$t, $font, $color, [int]$x, [int]$y, [int]$sp) {
    $fl = [System.Windows.Forms.TextFormatFlags]::NoPadding
    foreach ($ch in $t.ToCharArray()) {
        $s = [string]$ch
        [System.Windows.Forms.TextRenderer]::DrawText($g, $s, $font, (New-Object System.Drawing.Point($x, $y)), $color, $fl)
        $w = [System.Windows.Forms.TextRenderer]::MeasureText($g, $s, $font, [System.Drawing.Size]::Empty, $fl).Width
        $x += $w + $sp
    }
}
function SetDouble($ctl) {
    $ctl.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($ctl, $true, $null)
}

# ---------------------------------------------------------------- Catálogo de módulos
$script:Cats = [ordered]@{
    'Manutenção e Reparo'   = 'Limpeza, verificação e reparo do Windows e dos discos.'
    'Rede e Conectividade'  = 'Reset de pilha de rede, testes e pastas compartilhadas.'
    'Diagnóstico e Sistema' = 'Informações da máquina, dispositivos, processos e impressão.'
    'Drivers'               = 'Verificação, atualização, relatório e backup de drivers.'
    'Software e Políticas'  = 'Diretivas de grupo e gestão de pacotes via Winget.'
    'Ferramentas Extras'    = 'Inventário, auditoria, eventos e utilitários de atendimento.'
}
$script:Acts = New-Object System.Collections.ArrayList
function Add-Act($cat, $nome, $desc, $code, $confirm = '') {
    $n = $script:Acts.Count + 1
    [void]$script:Acts.Add([pscustomobject]@{ Id = $n; Cat = $cat; Nome = $nome; Desc = $desc; Code = $code; Confirm = $confirm })
}

$m = 'Manutenção e Reparo'
Add-Act $m 'Limpeza de arquivos temporários' 'TEMP do usuário, Windows\Temp e Prefetch.' @'
foreach ($d in @($env:TEMP, "$env:WINDIR\Temp", "$env:WINDIR\Prefetch")) {
  $s = (Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  Remove-Item "$d\*" -Recurse -Force -ErrorAction SilentlyContinue
  '{0,-34} ~{1} MB removidos' -f $d, [math]::Round($s / 1MB)
}
'Concluído.'
'@
Add-Act $m 'Limpeza de disco avançada' 'Executa o cleanmgr com perfil salvo.' @'
'Abrindo a Limpeza de Disco (marque os itens e confirme)...'
Start-Process cleanmgr -ArgumentList '/sageset:1' -Wait
Start-Process cleanmgr -ArgumentList '/sagerun:1' -Wait
'Concluído.'
'@
Add-Act $m 'Esvaziar lixeira' 'Esvazia a lixeira de todas as unidades.' @'
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
'Lixeira esvaziada.'
'@
Add-Act $m 'Verificar arquivos do Windows (SFC)' 'sfc /scannow. Pode levar vários minutos.' @'
sfc /scannow | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ }
'@
Add-Act $m 'Reparar imagem do Windows (DISM)' 'DISM RestoreHealth. Requer internet ou fonte local.' @'
DISM /Online /Cleanup-Image /RestoreHealth
'@
Add-Act $m 'Integridade do HD/SSD (CHKDSK)' 'Varredura online da unidade do sistema (somente leitura).' @'
chkdsk $env:SystemDrive /scan
''
'Para reparar de fato: chkdsk C: /f /r (exige reinício).'
'@
Add-Act $m 'Saúde do disco (S.M.A.R.T.)' 'Status, temperatura, desgaste e erros do HD/SSD.' @'
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, @{n='GB';e={[math]::Round($_.Size/1GB)}} | Format-Table -Auto | Out-String -Width 200
Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue | Select-Object DeviceId, Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours | Format-Table -Auto | Out-String -Width 200
'@

$m = 'Rede e Conectividade'
Add-Act $m 'Reset de rede (IP, Winsock, DNS)' 'Zera pilha TCP/IP. Exige reinício da máquina.' @'
ipconfig /flushdns
netsh winsock reset
netsh int ip reset
netsh int ipv6 reset
ipconfig /release
ipconfig /renew
''
'REINICIE a máquina para concluir.'
'@ 'O reset de rede derruba a conexão e exige reinício. Continuar?'
Add-Act $m 'Informações de rede completas' 'ipconfig /all.' @'
ipconfig /all
'@
Add-Act $m 'Testes de conectividade' 'Gateway, internet (8.8.8.8) e resolução de DNS.' @'
$gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1).NextHop
"Gateway: $gw"
if ($gw) { Test-Connection $gw -Count 3 -ErrorAction SilentlyContinue | Format-Table Address, ResponseTime -Auto | Out-String -Width 200 }
Test-Connection 8.8.8.8 -Count 3 -ErrorAction SilentlyContinue | Format-Table Address, ResponseTime -Auto | Out-String -Width 200
Resolve-DnsName google.com -ErrorAction SilentlyContinue | Format-Table Name, Type, IPAddress -Auto | Out-String -Width 200
'@
Add-Act $m 'Abrir conexões de rede' 'Abre o painel de adaptadores (ncpa.cpl).' @'
Start-Process ncpa.cpl
'Aberto.'
'@
Add-Act $m 'Mapear pasta de rede' 'Pergunta a letra e o caminho UNC e mapeia.' @'
net use
$l = '{{Letra da unidade (ex: Z)|Z}}' -replace '[: ]', ''
$p = '{{Caminho UNC (ex: \\servidor\pasta)|\\servidor\pasta}}'
net use "${l}:" $p /persistent:yes
'@
Add-Act $m 'Reparar pastas de rede (sem reiniciar)' 'Limpa sessões, cache NetBIOS, tickets Kerberos e reinicia o cliente SMB.' @'
net use * /delete /y
ipconfig /flushdns
nbtstat -R
nbtstat -RR
klist purge
klist -li 0x3e7 purge
net stop lanmanworkstation /y
net start lanmanworkstation
''
'Concluído. Remapeie as unidades (Mapear pasta de rede).'
'@ 'Isto desconecta TODOS os mapeamentos de rede da máquina. Continuar?'

$m = 'Diagnóstico e Sistema'
Add-Act $m 'Informações do sistema' 'systeminfo completo.' @'
systeminfo
'@
Add-Act $m 'Gerenciador de dispositivos' 'Abre o devmgmt.msc.' @'
Start-Process devmgmt.msc
'Aberto.'
'@
Add-Act $m 'Monitor de recursos e processos' 'Abre o Monitor de Recursos e o Gerenciador de Tarefas.' @'
Start-Process resmon.exe
Start-Process taskmgr.exe
'Abertos.'
'@
Add-Act $m 'Limpar fila e reiniciar spooler' 'Apaga trabalhos presos e reinicia o serviço de impressão.' @'
Stop-Service spooler -Force
Remove-Item "$env:WINDIR\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
Start-Service spooler
'Spooler reiniciado e fila limpa.'
'@ 'Os documentos na fila de impressão serão descartados. Continuar?'

$m = 'Drivers'
Add-Act $m 'Verificar drivers com erro' 'Lista dispositivos com problema e reescaneia o hardware.' @'
$e = Get-PnpDevice -PresentOnly | Where-Object Status -eq 'Error'
if ($e) { $e | Select-Object Class, FriendlyName, InstanceId | Format-Table -Auto | Out-String -Width 200 } else { 'Nenhum dispositivo com erro.' }
pnputil /scan-devices
'@
Add-Act $m 'Atualizar drivers (Windows Update)' 'Instala drivers pendentes via PSWindowsUpdate.' @'
if (-not (Get-Module -ListAvailable PSWindowsUpdate)) {
  'Instalando módulo PSWindowsUpdate...'
  Install-PackageProvider NuGet -Force | Out-Null
  Install-Module PSWindowsUpdate -Force -Scope AllUsers
}
Import-Module PSWindowsUpdate
Get-WindowsUpdate -MicrosoftUpdate -Category Drivers -Install -AcceptAll -IgnoreReboot
'@ 'Instala drivers do Windows Update (e o módulo PSWindowsUpdate, se faltar). Requer internet. Continuar?'
Add-Act $m 'Relatório de drivers (web)' 'Gera HTML com versão e data de cada driver.' @'
$r = Join-Path $env:HD_SAIDA "Drivers_$env:COMPUTERNAME.html"
Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceName | Sort-Object DriverDate |
  Select-Object DeviceName, Manufacturer, DriverVersion, @{n='Data';e={ if ($_.DriverDate) { $_.DriverDate.ToString('yyyy-MM-dd') } }} |
  ConvertTo-Html -Title 'Drivers' | Out-File -Encoding utf8 $r
Start-Process $r
"Relatório: $r"
'@
Add-Act $m 'Backup de todos os drivers' 'Exporta os drivers instalados para a pasta de saída.' @'
$d = Join-Path $env:HD_SAIDA ("Drivers_" + (Get-Date -Format 'yyyyMMdd'))
New-Item -ItemType Directory -Path $d -Force | Out-Null
Export-WindowsDriver -Online -Destination $d | Out-Null
"Backup salvo em: $d"
'@

$m = 'Software e Políticas'
Add-Act $m 'Atualizar diretivas de grupo' 'gpupdate /force.' @'
gpupdate /force
'@
Add-Act $m 'Relatório de políticas de grupo' 'Gera o gpresult em HTML.' @'
$r = Join-Path $env:HD_SAIDA "GPO_$env:COMPUTERNAME.html"
gpresult /h $r /f
Start-Process $r
"Relatório: $r"
'@
Add-Act $m 'Listar atualizações (Winget)' 'Mostra pacotes com versão nova disponível.' @'
if (Get-Command winget -ErrorAction SilentlyContinue) { winget upgrade --accept-source-agreements } else { 'Winget não encontrado nesta máquina.' }
'@
Add-Act $m 'Atualizar todos os softwares (Winget)' 'Atualiza em modo silencioso todos os pacotes.' @'
if (Get-Command winget -ErrorAction SilentlyContinue) { winget upgrade --all --silent --accept-package-agreements --accept-source-agreements } else { 'Winget não encontrado nesta máquina.' }
'@ 'Atualiza todos os programas instalados via Winget. Continuar?'

$m = 'Ferramentas Extras'
Add-Act $m 'Inventário da máquina (CSV)' 'Host, serial, modelo, RAM, disco, IP, MAC. Acumula em inventario.csv.' @'
$cs = Get-CimInstance Win32_ComputerSystem; $bios = Get-CimInstance Win32_BIOS; $os = Get-CimInstance Win32_OperatingSystem
$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
$nic = Get-NetIPConfiguration | Where-Object IPv4DefaultGateway | Select-Object -First 1
$mac = (Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Select-Object -First 1).MacAddress
$row = [pscustomobject][ordered]@{
  Data = (Get-Date -Format 'yyyy-MM-dd HH:mm'); Host = $env:COMPUTERNAME; Usuario = $env:USERNAME; Dominio = $cs.Domain
  Fabricante = $cs.Manufacturer; Modelo = $cs.Model; Serial = $bios.SerialNumber; CPU = $cpu
  RAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB); SO = $os.Caption; Build = $os.BuildNumber
  Disco_GB = [math]::Round($disk.Size / 1GB); Livre_GB = [math]::Round($disk.FreeSpace / 1GB)
  IP = ($nic.IPv4Address.IPAddress -join ','); MAC = $mac
}
$csv = Join-Path (Split-Path $env:HD_SAIDA -Parent) 'inventario.csv'
$row | Export-Csv $csv -Append -NoTypeInformation -Delimiter ';' -Encoding UTF8
$row | Format-List | Out-String -Width 200
"Adicionado em: $csv"
'@
Add-Act $m 'Programas instalados (CSV)' 'Lista de softwares com versão e fabricante.' @'
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
$l = Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object DisplayName | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Sort-Object DisplayName -Unique
$f = Join-Path $env:HD_SAIDA "Programas_$env:COMPUTERNAME.csv"
$l | Export-Csv $f -NoTypeInformation -Delimiter ';' -Encoding UTF8
$l | Format-Table -Auto | Out-String -Width 220
"Total: $($l.Count)  |  Arquivo: $f"
'@
Add-Act $m 'Erros críticos (últimas 24h)' 'Eventos de erro dos logs System e Application.' @'
$ev = Get-WinEvent -FilterHashtable @{ LogName = 'System', 'Application'; Level = 1, 2; StartTime = (Get-Date).AddHours(-24) } -MaxEvents 100 -ErrorAction SilentlyContinue
if ($ev) {
  $ev | Select-Object TimeCreated, LogName, ProviderName, Id, @{n='Mensagem';e={ ($_.Message -split "`n")[0] }} | Format-Table -Auto -Wrap | Out-String -Width 240
} else { 'Nenhum erro crítico nas últimas 24h.' }
'@
Add-Act $m 'Relatório de bateria' 'powercfg /batteryreport (notebooks).' @'
$r = Join-Path $env:HD_SAIDA 'Bateria.html'
powercfg /batteryreport /output $r
if (Test-Path $r) { Start-Process $r }
'@
Add-Act $m 'BitLocker e ativação do Windows' 'Status de criptografia e licença.' @'
'--- BitLocker ---'
Get-BitLockerVolume -ErrorAction SilentlyContinue | Format-Table MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage -Auto | Out-String -Width 200
'--- Licença do Windows ---'
Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" | Select-Object Name, @{n='Licenciado';e={ $_.LicenseStatus -eq 1 }} | Format-Table -Auto | Out-String -Width 200
'@
Add-Act $m 'Administradores e usuários locais' 'Quem tem privilégio de administrador na máquina.' @'
'--- Grupo Administradores ---'
Get-LocalGroupMember -SID S-1-5-32-544 | Format-Table Name, ObjectClass, PrincipalSource -Auto | Out-String -Width 200
'--- Usuários locais ---'
Get-LocalUser | Format-Table Name, Enabled, LastLogon -Auto | Out-String -Width 200
'@
Add-Act $m 'Impressoras instaladas' 'Nome, driver, porta e status.' @'
Get-Printer | Format-Table Name, DriverName, PortName, PrinterStatus -Auto | Out-String -Width 200
'@
Add-Act $m 'Resetar Windows Update' 'Para serviços e renomeia SoftwareDistribution e catroot2.' @'
$svc = 'wuauserv', 'bits', 'cryptsvc', 'msiserver'
$svc | ForEach-Object { Stop-Service $_ -Force -ErrorAction SilentlyContinue }
Rename-Item "$env:WINDIR\SoftwareDistribution" 'SoftwareDistribution.old' -ErrorAction SilentlyContinue
Rename-Item "$env:WINDIR\System32\catroot2" 'catroot2.old' -ErrorAction SilentlyContinue
$svc | ForEach-Object { Start-Service $_ -ErrorAction SilentlyContinue }
'Componentes do Windows Update resetados. Procure atualizações novamente.'
'@ 'Isto reinicia os serviços do Windows Update e renomeia seus caches. Continuar?'
Add-Act $m 'Reiniciar Explorer' 'Corrige barra de tarefas e menu Iniciar travados.' @'
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep 1
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer }
'Explorer reiniciado.'
'@
Add-Act $m 'Teste de portas (servidores.txt)' 'Testa host:porta de cada linha do arquivo ao lado do painel.' @'
$f = Join-Path $env:HD_RAIZ 'servidores.txt'
if (-not (Test-Path $f)) { "Arquivo não encontrado: $f"; return }
$itens = Get-Content $f | Where-Object { $_ -and $_ -notmatch '^\s*#' }
if (-not $itens) { "Nenhuma entrada em $f (formato host:porta)."; return }
foreach ($i in $itens) {
  $h, $p = $i.Trim() -split ':'
  if (-not $p) { $p = 445 }
  $tc = New-Object Net.Sockets.TcpClient
  try { $ar = $tc.BeginConnect($h, [int]$p, $null, $null); $ok = $ar.AsyncWaitHandle.WaitOne(1500) -and $tc.Connected } catch { $ok = $false }
  $tc.Close()
  '{0,-38} {1,-6} {2}' -f $h, $p, $(if ($ok) { 'ABERTA' } else { 'FALHOU' })
}
'@

# ---------------------------------------------------------------- Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "TI Console - Sandéleh Alimentos  v$($script:Versao)"
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(1280, 820)
$form.MinimumSize = New-Object System.Drawing.Size(1080, 700)
$form.BackColor = $cWhite
$form.ForeColor = $cInk
$form.Font = F $FB 9.5
$form.KeyPreview = $true

# --- Área central (Fill) -> adicionada primeiro
$main = New-Object System.Windows.Forms.Panel
$main.Dock = 'Fill'; $main.BackColor = $cWhite
$form.Controls.Add($main)

$cardsArea = New-Object System.Windows.Forms.Panel
$cardsArea.Dock = 'Fill'; $cardsArea.Padding = New-Object System.Windows.Forms.Padding(24, 14, 24, 8)
$main.Controls.Add($cardsArea)

$flow = New-Object System.Windows.Forms.FlowLayoutPanel
$flow.Dock = 'Fill'; $flow.AutoScroll = $true; $flow.WrapContents = $true
$flow.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
$cardsArea.Controls.Add($flow)

$head = New-Object System.Windows.Forms.Panel
$head.Dock = 'Top'; $head.Height = 112
$cardsArea.Controls.Add($head)

$bar = New-Object System.Windows.Forms.Panel
$bar.BackColor = $cRed; $bar.Size = New-Object System.Drawing.Size(26, 2); $bar.Location = New-Object System.Drawing.Point(0, 9)
$head.Controls.Add($bar)
$lblEyebrow = New-Object System.Windows.Forms.Label
$lblEyebrow.AutoSize = $true; $lblEyebrow.Font = F $FM 8.5 $true; $lblEyebrow.ForeColor = $cRed
$lblEyebrow.Location = New-Object System.Drawing.Point(34, 2); $lblEyebrow.Text = 'MÓDULOS'
$head.Controls.Add($lblEyebrow)
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.AutoSize = $true; $lblTitle.Font = F $FT 20 $true; $lblTitle.ForeColor = $cInk
$lblTitle.Location = New-Object System.Drawing.Point(-2, 20)
$head.Controls.Add($lblTitle)
$lblLead = New-Object System.Windows.Forms.Label
$lblLead.AutoSize = $true; $lblLead.Font = F $FB 10 $false; $lblLead.ForeColor = $cText2
$lblLead.Location = New-Object System.Drawing.Point(0, 58)
$head.Controls.Add($lblLead)

$txtBusca = New-Object System.Windows.Forms.TextBox
$txtBusca.Font = F $FB 10; $txtBusca.Width = 260; $txtBusca.BorderStyle = 'FixedSingle'
$txtBusca.Location = New-Object System.Drawing.Point(0, 22)
$head.Controls.Add($txtBusca)
$lblBusca = New-Object System.Windows.Forms.Label
$lblBusca.AutoSize = $true; $lblBusca.Font = F $FM 8 $true; $lblBusca.ForeColor = $cLabel
$lblBusca.Text = 'BUSCAR MÓDULO  (CTRL+F)'
$lblBusca.Location = New-Object System.Drawing.Point(0, 4)
$head.Controls.Add($lblBusca)
$head.Add_Resize({ $txtBusca.Left = $head.Width - 260; $lblBusca.Left = $head.Width - 260 })

# --- Sidebar
$side = New-Object System.Windows.Forms.Panel
$side.Dock = 'Left'; $side.Width = 250; $side.BackColor = $cWhite; $side.Padding = New-Object System.Windows.Forms.Padding(16, 18, 8, 8)
$side.Add_Paint({ param($s, $e) $p = New-Object System.Drawing.Pen($cLine); $e.Graphics.DrawLine($p, ($s.Width - 1), 0, ($s.Width - 1), $s.Height) })
$main.Controls.Add($side)

# --- Saída (Bottom)
$outPanel = New-Object System.Windows.Forms.Panel
$outPanel.Dock = 'Bottom'; $outPanel.Height = 280; $outPanel.BackColor = $cWhite
$outPanel.Padding = New-Object System.Windows.Forms.Padding(24, 0, 24, 14)
$form.Controls.Add($outPanel)

$rtb = New-Object System.Windows.Forms.RichTextBox
$rtb.Dock = 'Fill'; $rtb.ReadOnly = $true; $rtb.BorderStyle = 'None'
$rtb.BackColor = $cBg2; $rtb.ForeColor = $cInk; $rtb.Font = F $FM 9.5
$rtb.WordWrap = $false; $rtb.ScrollBars = 'Both'
$outPanel.Controls.Add($rtb)

$tool = New-Object System.Windows.Forms.Panel
$tool.Dock = 'Top'; $tool.Height = 44
$outPanel.Controls.Add($tool)

function New-Btn($text, $x, $primary = $false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.FlatStyle = 'Flat'; $b.Font = F $FB 9 $true
    $b.Size = New-Object System.Drawing.Size(104, 28); $b.Location = New-Object System.Drawing.Point($x, 8)
    $b.Cursor = 'Hand'; $b.BackColor = $cWhite; $b.ForeColor = $cInk
    $b.FlatAppearance.BorderColor = $cLine2; $b.FlatAppearance.BorderSize = 1
    if ($primary) { $b.ForeColor = $cRed; $b.FlatAppearance.BorderColor = $cRed }
    $b
}
$barOut = New-Object System.Windows.Forms.Panel
$barOut.BackColor = $cRed; $barOut.Size = New-Object System.Drawing.Size(26, 2); $barOut.Location = New-Object System.Drawing.Point(0, 21)
$tool.Controls.Add($barOut)
$lblOut = New-Object System.Windows.Forms.Label
$lblOut.AutoSize = $true; $lblOut.Font = F $FM 8.5 $true; $lblOut.ForeColor = $cRed; $lblOut.Text = 'SAÍDA'
$lblOut.Location = New-Object System.Drawing.Point(34, 14)
$tool.Controls.Add($lblOut)
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.AutoSize = $true; $lblStatus.Font = F $FM 9 $false; $lblStatus.ForeColor = $cLabel; $lblStatus.Text = 'Pronto.'
$lblStatus.Location = New-Object System.Drawing.Point(92, 14)
$tool.Controls.Add($lblStatus)

$btnCancel = New-Btn 'Cancelar' 0 $true
$btnCopy   = New-Btn 'Copiar' 0
$btnSave   = New-Btn 'Salvar .txt' 0
$btnClear  = New-Btn 'Limpar' 0
$btnFolder = New-Btn 'Pasta de saída' 0
$btnFolder.Width = 120
$x = 0
foreach ($b in @($btnFolder, $btnClear, $btnSave, $btnCopy, $btnCancel)) {
    $b.Anchor = 'Top,Right'
    $tool.Controls.Add($b)
}
function Place-Btns {
    $x = $tool.Width - 4
    foreach ($b in @($btnFolder, $btnClear, $btnSave, $btnCopy, $btnCancel)) {
        $x -= ($b.Width + 8); $b.Left = $x
    }
}
$tool.Add_Resize({ Place-Btns }); Place-Btns
$btnCancel.Enabled = $false

# --- KPI
$kpiPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$kpiPanel.Dock = 'Top'; $kpiPanel.Height = 104; $kpiPanel.BackColor = $cWhite
$kpiPanel.Padding = New-Object System.Windows.Forms.Padding(24, 6, 24, 6)
$kpiPanel.WrapContents = $false
$form.Controls.Add($kpiPanel)

$kpiPaint = {
    param($s, $e)
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $t = $s.Tag
    $r = New-Object System.Drawing.Rectangle(0, 0, ($s.Width - 1), ($s.Height - 1))
    $path = RoundPath $r 10
    $g.FillPath((New-Object System.Drawing.SolidBrush($cWhite)), $path)
    $g.DrawPath((New-Object System.Drawing.Pen($cLine)), $path)
    $fl = [System.Windows.Forms.TextFormatFlags]::NoPadding
    [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Label, (F $FB 9.5), (New-Object System.Drawing.Point(14, 10)), $cText2, $fl)
    [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Value, (F $FM 17 $true), (New-Object System.Drawing.Point(14, 30)), $t.Color, $fl)
    [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Meta, (F $FM 8.5), (New-Object System.Drawing.Point(14, 64)), $cLabel, $fl)
    $cx = $s.Width - 20; $cy = 16
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(36, $t.Color))), ($cx - 8.5), ($cy - 8.5), 17, 17)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush($t.Color)), ($cx - 4.5), ($cy - 4.5), 9, 9)
}
$script:Kpis = @()
for ($i = 0; $i -lt 5; $i++) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Size = New-Object System.Drawing.Size(220, 88); $p.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)
    SetDouble $p
    $p.Tag = @{ Label = '...'; Value = '--'; Meta = ''; Color = $cLabel }
    $p.Add_Paint($kpiPaint)
    $kpiPanel.Controls.Add($p)
    $script:Kpis += $p
}
function Set-Kpi($i, $label, $value, $meta, $color) {
    $script:Kpis[$i].Tag = @{ Label = $label; Value = $value; Meta = $meta; Color = $color }
    $script:Kpis[$i].Invalidate()
}
function Update-Kpis {
    $lblStatus.Text = 'Atualizando indicadores...'; [System.Windows.Forms.Application]::DoEvents()
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $dk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        $livre = [math]::Round(100 * $dk.FreeSpace / $dk.Size)
        $col = if ($livre -ge 20) { $cGreen } elseif ($livre -ge 10) { $cAmber } else { $cRed }
        Set-Kpi 0 "Disco $env:SystemDrive livre" "$livre%" ("{0} GB de {1} GB" -f [math]::Round($dk.FreeSpace / 1GB), [math]::Round($dk.Size / 1GB)) $col

        $tot = $os.TotalVisibleMemorySize; $free = $os.FreePhysicalMemory
        $uso = [math]::Round(100 * ($tot - $free) / $tot)
        $col = if ($uso -lt 75) { $cGreen } elseif ($uso -lt 90) { $cAmber } else { $cRed }
        Set-Kpi 1 'Memória em uso' "$uso%" ("{0} GB de {1} GB" -f [math]::Round(($tot - $free) / 1MB, 1), [math]::Round($tot / 1MB, 1)) $col

        $dias = [math]::Floor(((Get-Date) - $os.LastBootUpTime).TotalDays)
        $col = if ($dias -lt 7) { $cGreen } elseif ($dias -lt 30) { $cAmber } else { $cRed }
        Set-Kpi 2 'Uptime' "$dias d" ('boot ' + $os.LastBootUpTime.ToString('dd/MM HH:mm')) $col

        $ip = (Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object IPv4DefaultGateway | Select-Object -First 1).IPv4Address.IPAddress
        $ok = $false
        try { $ok = ((New-Object System.Net.NetworkInformation.Ping).Send('8.8.8.8', 1200)).Status -eq 'Success' } catch {}
        Set-Kpi 3 'Internet' $(if ($ok) { 'ONLINE' } else { 'OFFLINE' }) $(if ($ip) { $ip } else { 'sem IP' }) $(if ($ok) { $cGreen } else { $cRed })

        $dom = if ($cs.PartOfDomain) { $cs.Domain } else { 'WORKGROUP' }
        Set-Kpi 4 'Domínio' $dom ("$env:USERDOMAIN\$env:USERNAME") $cBlue
    } catch { $lblStatus.Text = 'Falha ao ler indicadores.' }
    $lblStatus.Text = 'Pronto.'
}

# --- Cabeçalho (wordmark)
$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'; $header.Height = 70; $header.BackColor = $cWhite
SetDouble $header
$header.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.TextRenderingHint = 'ClearTypeGridFit'
    DrawSpaced $g $script:Empresa (F $FT 18 $true) $cRed 24 10 4
    DrawSpaced $g 'ALIMENTOS' (F $FM 8) $cLabel 25 40 6
    $f1 = F $FT 13 $true
    $txt = 'Painel de Sistemas'
    [System.Windows.Forms.TextRenderer]::DrawText($g, $txt, $f1, (New-Object System.Drawing.Point(280, 14)), $cInk, [System.Windows.Forms.TextFormatFlags]::NoPadding)
    [System.Windows.Forms.TextRenderer]::DrawText($g, 'Infraestrutura de TI  ·  Help Desk', (F $FB 9.5), (New-Object System.Drawing.Point(281, 38)), $cText2, [System.Windows.Forms.TextFormatFlags]::NoPadding)
    $info = "$env:COMPUTERNAME  ·  $env:USERNAME"
    $sz = [System.Windows.Forms.TextRenderer]::MeasureText($g, $info, (F $FM 9.5))
    [System.Windows.Forms.TextRenderer]::DrawText($g, $info, (F $FM 9.5), (New-Object System.Drawing.Point(($s.Width - $sz.Width - 28), 26)), $cText2, [System.Windows.Forms.TextFormatFlags]::NoPadding)
    $g.DrawLine((New-Object System.Drawing.Pen($cLine)), 0, ($s.Height - 1), $s.Width, ($s.Height - 1))
})
$form.Controls.Add($header)

# ---------------------------------------------------------------- Catálogo na tela
$script:SelCat = ($script:Cats.Keys | Select-Object -First 1)
$script:CatBtns = @{}

function Set-Selected($name) {
    $script:SelCat = $name
    foreach ($k in $script:CatBtns.Keys) {
        $b = $script:CatBtns[$k]
        if ($k -eq $name) { $b.BackColor = $cBg2; $b.ForeColor = $cRed; $b.Font = F $FB 10 $true }
        else { $b.BackColor = $cWhite; $b.ForeColor = $cInk; $b.Font = F $FB 10 $false }
    }
}

$cardHover = {
    param($s, $e)
    $c = if ($s -is [System.Windows.Forms.Panel]) { $s } else { $s.Parent }
    $c.BackColor = $cBg2
}
$cardLeave = {
    param($s, $e)
    $c = if ($s -is [System.Windows.Forms.Panel]) { $s } else { $s.Parent }
    if (-not $c.ClientRectangle.Contains($c.PointToClient([System.Windows.Forms.Cursor]::Position))) { $c.BackColor = $cWhite }
}
$cardClick = {
    param($s, $e)
    Invoke-Action $s.Tag
}
$cardPaint = {
    param($s, $e)
    $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
    $r = New-Object System.Drawing.Rectangle(0, 0, ($s.Width - 1), ($s.Height - 1))
    $path = RoundPath $r 10
    $g.DrawPath((New-Object System.Drawing.Pen($cLine)), $path)
    if ($s.Tag.Confirm) {
        $g.FillRectangle((New-Object System.Drawing.SolidBrush($cAmber)), 0, 12, 3, ($s.Height - 24))
    }
}

function Show-Cards($list) {
    $flow.SuspendLayout()
    $flow.Controls.Clear()
    foreach ($a in $list) {
        $c = New-Object System.Windows.Forms.Panel
        $c.Size = New-Object System.Drawing.Size(318, 86); $c.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 12)
        $c.BackColor = $cWhite; $c.Cursor = 'Hand'; $c.Tag = $a
        SetDouble $c
        $n = New-Object System.Windows.Forms.Label
        $n.Text = ('{0:00}' -f $a.Id); $n.Font = F $FM 9 $true; $n.ForeColor = $cRed; $n.AutoSize = $true
        $n.Location = New-Object System.Drawing.Point(14, 12); $n.BackColor = [System.Drawing.Color]::Transparent; $n.Tag = $a
        $t = New-Object System.Windows.Forms.Label
        $t.Text = $a.Nome; $t.Font = F $FB 10 $true; $t.ForeColor = $cInk
        $t.AutoSize = $false; $t.Size = New-Object System.Drawing.Size(250, 22); $t.AutoEllipsis = $true
        $t.Location = New-Object System.Drawing.Point(44, 10); $t.BackColor = [System.Drawing.Color]::Transparent; $t.Tag = $a
        $d = New-Object System.Windows.Forms.Label
        $d.Text = $a.Desc; $d.Font = F $FB 9 $false; $d.ForeColor = $cText2
        $d.AutoSize = $false; $d.Size = New-Object System.Drawing.Size(268, 44)
        $d.Location = New-Object System.Drawing.Point(44, 34); $d.BackColor = [System.Drawing.Color]::Transparent; $d.Tag = $a
        foreach ($ctl in @($c, $n, $t, $d)) {
            $ctl.Add_MouseEnter($cardHover); $ctl.Add_MouseLeave($cardLeave); $ctl.Add_Click($cardClick)
        }
        $c.Add_Paint($cardPaint)
        $c.Controls.AddRange(@($n, $t, $d))
        $flow.Controls.Add($c)
    }
    $flow.ResumeLayout()
}

function Show-Category($name) {
    Set-Selected $name
    $txtBusca.Text = ''
    $lblEyebrow.Text = 'MÓDULOS'
    $lblTitle.Text = $name
    $lblLead.Text = $script:Cats[$name]
    Show-Cards @($script:Acts | Where-Object { $_.Cat -eq $name })
}

$y = 18
foreach ($k in $script:Cats.Keys) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = '  ' + $k; $b.TextAlign = 'MiddleLeft'; $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0; $b.FlatAppearance.MouseOverBackColor = $cBg2
    $b.Size = New-Object System.Drawing.Size(224, 42); $b.Location = New-Object System.Drawing.Point(16, $y)
    $b.Cursor = 'Hand'; $b.Tag = $k; $b.BackColor = $cWhite; $b.ForeColor = $cInk; $b.Font = F $FB 10 $false
    $b.Add_Click({ param($s, $e) Show-Category $s.Tag })
    $side.Controls.Add($b)
    $script:CatBtns[$k] = $b
    $y += 46
}
$lblAtalho = New-Object System.Windows.Forms.Label
$lblAtalho.AutoSize = $false; $lblAtalho.Size = New-Object System.Drawing.Size(224, 60)
$lblAtalho.Location = New-Object System.Drawing.Point(16, ($y + 20)); $lblAtalho.Font = F $FM 8.5; $lblAtalho.ForeColor = $cLabel
$lblAtalho.Text = "F5  atualizar indicadores`nCTRL+F  buscar módulo`nSaída: Saida\$env:COMPUTERNAME"
$side.Controls.Add($lblAtalho)

$txtBusca.Add_TextChanged({
    $q = $txtBusca.Text.Trim()
    if (-not $q) { Show-Category $script:SelCat; return }
    $lblEyebrow.Text = 'BUSCA'; $lblTitle.Text = 'Resultados'; $lblLead.Text = "Módulos que contêm '$q'."
    Show-Cards @($script:Acts | Where-Object { $_.Nome -like "*$q*" -or $_.Desc -like "*$q*" -or ('{0:00}' -f $_.Id) -eq $q })
})

# ---------------------------------------------------------------- Execução
$script:Busy = $false; $script:Proc = $null; $script:OutFile = ''; $script:Printed = 0
$script:Final = $false; $script:T0 = $null; $script:CurAct = $null; $script:InputCancel = $false

function Read-Shared($path) {
    try {
        $fs = [System.IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
        $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)
        $t = $sr.ReadToEnd(); $sr.Close(); return $t
    } catch { return '' }
}
function Write-Log($msg) {
    try { Add-Content -Path (Join-Path $script:LogDir ((Get-Date -Format 'yyyyMMdd') + '.log')) -Value ("{0}  {1}  {2}" -f (Get-Date -Format 'HH:mm:ss'), $env:USERNAME, $msg) -Encoding UTF8 } catch {}
}
function Set-Busy([bool]$b) {
    $script:Busy = $b
    $btnCancel.Enabled = $b
    $flow.Enabled = -not $b
    $side.Enabled = -not $b
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 400
$timer.Add_Tick({
    if (-not $script:Proc) { return }
    $txt = Read-Shared $script:OutFile
    if ($txt.Length -gt $script:Printed) {
        $rtb.AppendText($txt.Substring($script:Printed))
        $script:Printed = $txt.Length
        $rtb.SelectionStart = $rtb.TextLength; $rtb.ScrollToCaret()
    }
    $lblStatus.Text = ('Executando: {0}  ({1:0}s)' -f $script:CurAct.Nome, ((Get-Date) - $script:T0).TotalSeconds)
    if ($script:Proc.HasExited) {
        if (-not $script:Final) { $script:Final = $true; return }
        $timer.Stop()
        $seg = ((Get-Date) - $script:T0).TotalSeconds
        $rtb.AppendText(("`r`n[concluído em {0:0}s]`r`n" -f $seg))
        $rtb.SelectionStart = $rtb.TextLength; $rtb.ScrollToCaret()
        try { Copy-Item $script:OutFile (Join-Path $script:LogDir ((Get-Date -Format 'yyyyMMdd_HHmmss') + ('_{0:00}.txt' -f $script:CurAct.Id))) -ErrorAction SilentlyContinue } catch {}
        Write-Log ("FIM  [{0:00}] {1}  ({2:0}s)" -f $script:CurAct.Id, $script:CurAct.Nome, $seg)
        $lblStatus.Text = ('Concluído: {0}' -f $script:CurAct.Nome)
        $script:Proc = $null
        Set-Busy $false
    }
})

function Invoke-Action($a) {
    if ($script:Busy) { return }
    $script:CurAct = $a
    $code = $a.Code
    $script:InputCancel = $false
    $ev = [System.Text.RegularExpressions.MatchEvaluator]{
        param($mm)
        $parts = $mm.Groups[1].Value -split '\|', 2
        $def = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $r = [Microsoft.VisualBasic.Interaction]::InputBox($parts[0], $script:CurAct.Nome, $def)
        if ([string]::IsNullOrWhiteSpace($r)) { $script:InputCancel = $true; return '' }
        return ($r -replace '[^\w\.\-\\\$ /]', '')
    }
    $code = [regex]::Replace($code, '\{\{(.+?)\}\}', $ev)
    if ($script:InputCancel) { $lblStatus.Text = 'Cancelado.'; return }
    if ($a.Confirm) {
        $r = [System.Windows.Forms.MessageBox]::Show($a.Confirm, $a.Nome, 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $lblStatus.Text = 'Cancelado.'; return }
    }

    $id = [guid]::NewGuid().ToString('N')
    $tmp = Join-Path $env:TEMP "hd_$id.ps1"
    $script:OutFile = Join-Path $env:TEMP "hd_$id.out"
    Set-Content -Path $tmp -Value ('$ProgressPreference = ''SilentlyContinue''' + "`r`n" + $code) -Encoding UTF8
    Set-Content -Path $script:OutFile -Value '' -Encoding UTF8

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$tmp' *>&1 | Out-File -FilePath '$($script:OutFile)' -Encoding utf8 -Width 200`""
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables['HD_SAIDA'] = $script:Saida
    $psi.EnvironmentVariables['HD_RAIZ'] = $script:Raiz

    $rtb.AppendText(("`r`n>>> [{0:00}] {1}  ({2})`r`n" -f $a.Id, $a.Nome, (Get-Date -Format 'HH:mm:ss')))
    Write-Log ("INICIO  [{0:00}] {1}" -f $a.Id, $a.Nome)
    $script:Printed = 0; $script:Final = $false; $script:T0 = Get-Date
    Set-Busy $true
    try {
        $script:Proc = [System.Diagnostics.Process]::Start($psi)
        $timer.Start()
    } catch {
        $rtb.AppendText("Falha ao iniciar: $($_.Exception.Message)`r`n")
        $script:Proc = $null; Set-Busy $false
    }
}

$btnCancel.Add_Click({
    if ($script:Proc -and -not $script:Proc.HasExited) {
        [void][System.Diagnostics.Process]::Start('taskkill', "/PID $($script:Proc.Id) /T /F")
        $rtb.AppendText("`r`n[cancelado pelo usuário]`r`n")
    }
})
$btnClear.Add_Click({ $rtb.Clear() })
$btnCopy.Add_Click({ if ($rtb.TextLength) { [System.Windows.Forms.Clipboard]::SetText($rtb.Text); $lblStatus.Text = 'Copiado.' } })
$btnSave.Add_Click({
    $f = Join-Path $script:Saida ('Saida_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
    Set-Content -Path $f -Value $rtb.Text -Encoding UTF8
    $lblStatus.Text = "Salvo: $f"
})
$btnFolder.Add_Click({ Start-Process explorer.exe $script:Saida })

$form.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq 'F5') { Update-Kpis }
    if ($e.Control -and $e.KeyCode -eq 'F') { $txtBusca.Focus() }
})
$form.Add_FormClosing({
    param($s, $e)
    if ($script:Busy) {
        $r = [System.Windows.Forms.MessageBox]::Show('Há uma tarefa em execução. Fechar mesmo assim?', 'Painel Help Desk', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $e.Cancel = $true; return }
        if ($script:Proc -and -not $script:Proc.HasExited) { [void][System.Diagnostics.Process]::Start('taskkill', "/PID $($script:Proc.Id) /T /F") }
    }
})
$form.Add_Shown({
    Show-Category $script:SelCat
    $rtb.AppendText("Painel Help Desk v$($script:Versao)  |  $env:COMPUTERNAME  |  Saída: $($script:Saida)`r`n")
    Update-Kpis
})

[System.Windows.Forms.Application]::Run($form)

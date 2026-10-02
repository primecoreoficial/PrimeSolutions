# ============================================================
# PRIMECORE OPTIMIZER (PowerShell) - pos-formatacao Windows 10
#
# Inclui: otimizacao do Windows e atualizacao de drivers
#   (Windows Update + Dell Command Update / HP Image Assistant).
#
# Uso (PowerShell como Administrador):
#   irm https://raw.githubusercontent.com/primecoreoficial/PrimeSolutions/main/optimizer.ps1 | iex
#
# Obs: arquivo propositalmente em ASCII (sem acentos) para nao
# haver problema de codificacao ao baixar com irm no Windows 10.
# ============================================================

# Link do proprio script (usado para reabrir como Administrador).
# (ja configurado para o repositorio PrimeSolutions)
$RepoUrl = 'https://raw.githubusercontent.com/primecoreoficial/PrimeSolutions/main/optimizer.ps1'

function Start-PrimeCoreOptimizer {

    # ---------- TLS 1.2 (Windows 10 recem-formatado) ----------
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

    # ---------- Administrador ----------
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host ''
        Write-Host ' [!] Precisa ser executado como Administrador.' -ForegroundColor Yellow
        Write-Host '     Solicitando permissao...' -ForegroundColor Yellow
        try {
            if ($PSCommandPath) {
                Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
            }
            elseif ($RepoUrl -notmatch 'SEU_USUARIO') {
                $cmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm '$RepoUrl' | iex"
                Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "`"$cmd`"")
            }
            else {
                Write-Host '     Abra o PowerShell como Administrador e execute o comando novamente.' -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host ('     Nao foi possivel elevar: ' + $_.Exception.Message) -ForegroundColor Red
        }
        return
    }

    # ---------- Estado ----------
    $S = @{
        Log     = ''
        Results = @()
        Hw      = @{}
    }
    $oldColor = $null
    $oldTitle = $null
    try {
        $oldColor = $Host.UI.RawUI.ForegroundColor
        $oldTitle = $Host.UI.RawUI.WindowTitle
        $Host.UI.RawUI.WindowTitle = 'PrimeCore Optimizer'
        $Host.UI.RawUI.ForegroundColor = 'Red'
    } catch {}

    # ---------- Log ----------
    $logDir = Join-Path $env:ProgramData 'PrimeCore\Optimizer'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $S.Log = Join-Path $logDir ("PrimeCoreOptimizer_$stamp.log")

    function Write-Log([string]$Msg) {
        $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Msg
        Add-Content -Path $S.Log -Value $line -Encoding UTF8
    }

    function Say([string]$Msg, [string]$Color = 'Red') {
        Write-Host $Msg -ForegroundColor $Color
    }

    # ---------- Banner ----------
    function Show-Header {
        Clear-Host
        $banner = @'

   ####  ####  ##### #   # #####  ####  ###  ####  #####
   #   # #   #   #   ## ## #     #     #   # #   # #
   ####  ####    #   # # # ####  #     #   # ####  ####
   #     #  #    #   #   # #     #     #   # #  #  #
   #     #   # ##### #   # #####  ####  ###  #   # #####

            O P T I M I Z E R   P O S - F O R M A T A C A O
------------------------------------------------------------
'@
        Say $banner
    }

    # ---------- Executa programa nativo e registra no log ----------
    function Invoke-Native([string]$Exe, [string[]]$Arguments) {
        $out = & $Exe @Arguments 2>&1 | Out-String
        $rc = $LASTEXITCODE
        Add-Content -Path $S.Log -Value $out -Encoding UTF8
        Write-Log ("{0} {1} -> codigo {2}" -f $Exe, ($Arguments -join ' '), $rc)
        return $rc
    }

    function Set-Reg([string]$Path, [string]$Name, [int]$Value) {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord
    }

    # ---------- Hardware / perfil ----------
    function Get-HardwareInfo {
        $ErrorActionPreference = 'SilentlyContinue'
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $cs = Get-CimInstance Win32_ComputerSystem
        $os = Get-CimInstance Win32_OperatingSystem
        $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic Display' } | Select-Object -First 1
        $disk = Get-PhysicalDisk | Where-Object { $_.BusType -ne 'USB' } | Select-Object -First 1

        $ramGB = 0
        if ($cs.TotalPhysicalMemory) { $ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) }
        $ramInt = 8
        if ($cs.TotalPhysicalMemory) { $ramInt = [int][math]::Round($cs.TotalPhysicalMemory / 1GB) }

        $profile = 'EQUILIBRADO'
        if ($ramInt -le 4) { $profile = 'LEVE' }
        if ($ramInt -ge 16) { $profile = 'DESEMPENHO' }

        $arch = $env:PROCESSOR_ARCHITECTURE
        if ($arch -eq 'AMD64') { $arch = 'x64' }

        function Nz($v, $d) { if ([string]::IsNullOrWhiteSpace([string]$v)) { $d } else { [string]$v } }

        $S.Hw = @{
            CPU          = Nz $cpu.Name 'Nao identificado'
            Threads      = Nz $cpu.NumberOfLogicalProcessors '?'
            RAM          = if ($ramGB -gt 0) { "$($ramGB.ToString([Globalization.CultureInfo]::InvariantCulture)) GB" } else { 'Nao identificada' }
            RAMINT       = $ramInt
            GPU          = Nz $gpu.Name 'Microsoft Basic Display Adapter / nao identificado'
            DISKTYPE     = Nz $disk.MediaType 'Nao identificado'
            Manufacturer = Nz $cs.Manufacturer 'Nao identificado'
            Model        = Nz $cs.Model 'Nao identificado'
            OS           = Nz $os.Caption 'Windows (nao identificado)'
            OSVER        = Nz $os.Version '?'
            ARCH         = $arch
            PROFILE      = $profile
        }

        Write-Log '------------------ DIAGNOSTICO ------------------'
        foreach ($k in 'CPU', 'Threads', 'RAM', 'GPU', 'DISKTYPE', 'Manufacturer', 'Model', 'OS', 'OSVER', 'ARCH', 'PROFILE') {
            Write-Log ("{0}: {1}" -f $k, $S.Hw[$k])
        }
        Write-Log '-------------------------------------------------'
    }

    # ---------- Etapas de otimizacao ----------
    # Cada etapa devolve uma string: 'OK' ou 'AVISO (...)'
    function Step-RestorePoint {
        try {
            Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description 'PrimeCore Optimizer' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
            return 'OK'
        }
        catch {
            Write-Log ('Ponto de restauracao nao criado: ' + $_.Exception.Message)
            return 'AVISO (nao criado - veja o log)'
        }
    }

    function Step-Cleanup {
        $ErrorActionPreference = 'SilentlyContinue'
        Remove-Item -Path (Join-Path $env:TEMP '*') -Recurse -Force
        Remove-Item -Path (Join-Path $env:WINDIR 'Temp\*') -Recurse -Force
        Remove-Item -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer\thumbcache_*.db') -Force
        Invoke-Native 'ipconfig' @('/flushdns') | Out-Null
        Clear-RecycleBin -Force
        return 'OK'
    }

    function Step-ComponentCleanup {
        $rc = Invoke-Native 'DISM' @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
        if ($rc -eq 0) { return 'OK' }
        return "AVISO (codigo $rc)"
    }

    function Step-Power {
        $isLaptop = $false
        try {
            $enc = Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop
            $laptopTypes = 8, 9, 10, 11, 12, 14, 18, 21, 31, 32
            foreach ($t in $enc.ChassisTypes) { if ($laptopTypes -contains $t) { $isLaptop = $true } }
        } catch {}
        Write-Log "ISLAPTOP=$isLaptop"
        if ($isLaptop) {
            Invoke-Native 'powercfg' @('/setactive', 'SCHEME_BALANCED') | Out-Null
            Write-Log 'Notebook: plano Equilibrado'
            return 'OK (notebook: Equilibrado)'
        }
        Invoke-Native 'powercfg' @('/setactive', 'SCHEME_MIN') | Out-Null
        Write-Log 'Desktop: plano Alto Desempenho'
        return 'OK (desktop: Alto Desempenho)'
    }

    function Step-Visuals {
        $fx = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        if ($S.Hw.PROFILE -eq 'LEVE') {
            Set-Reg $fx 'VisualFXSetting' 2
            Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
            Write-Log 'Perfil LEVE: efeitos visuais reduzidos'
            return 'OK (efeitos reduzidos - perfil LEVE)'
        }
        Set-Reg $fx 'VisualFXSetting' 3
        Write-Log 'Efeitos visuais preservados'
        return 'OK (efeitos preservados)'
    }

    function Step-Storage {
        $rc = Invoke-Native 'defrag' @($env:SystemDrive, '/O', '/U', '/V')
        if ($rc -eq 0) { return 'OK' }
        return "AVISO (codigo $rc)"
    }

    function Step-Integrity {
        $rc1 = Invoke-Native 'DISM' @('/Online', '/Cleanup-Image', '/RestoreHealth')
        $rc2 = Invoke-Native 'sfc' @('/scannow')
        if ($rc1 -eq 0 -and $rc2 -eq 0) { return 'OK' }
        return "AVISO (DISM $rc1 / SFC $rc2 - veja o log)"
    }


    # ---------- Etapas de DRIVERS ----------
    function Test-Internet {
        try { return [bool](Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction Stop) }
        catch { return $false }
    }

    function Get-DriverSnapshot {
        $map = @{}
        $items = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue
        foreach ($d in $items) {
            if ($d.DeviceName -and $d.DeviceID) {
                $map[$d.DeviceID] = [pscustomobject]@{ Name = $d.DeviceName; Version = $d.DriverVersion; Date = $d.DriverDate }
            }
        }
        return $map
    }

    function Find-Exe([string[]]$Roots, [string]$FileName) {
        foreach ($r in $Roots) {
            if (-not (Test-Path $r)) { continue }
            $hit = Get-ChildItem -Path $r -Recurse -Filter $FileName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
        return $null
    }

    function Install-WingetFirst([string[]]$Ids) {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            Write-Log 'winget nao encontrado neste Windows'
            return $false
        }
        foreach ($id in $Ids) {
            $rc = Invoke-Native 'winget' @('install', '--id', $id, '-e', '--silent', '--accept-package-agreements', '--accept-source-agreements')
            if ($rc -eq 0 -or $rc -eq -1978335189) { return $true }
            Write-Log "winget: pacote $id nao instalado (codigo $rc)"
        }
        return $false
    }

    function Step-DriverInit {
        $S.DrvBefore = Get-DriverSnapshot
        Write-Log ("Drivers registrados antes: " + $S.DrvBefore.Count)
        return 'OK'
    }

    function Step-DriverBackup {
        $dest = Join-Path $logDir ("DriverBackup_$stamp")
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        $out = Export-WindowsDriver -Online -Destination $dest -ErrorAction Stop
        $n = @($out).Count
        Write-Log ("Backup de drivers de terceiros em $dest ($n)")
        return "OK ($n drivers de terceiros salvos)"
    }

    function Step-DriverWU {
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Start-Service -Name bits -ErrorAction SilentlyContinue
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $found = $searcher.Search("IsInstalled=0 and Type='Driver'")
        if ($found.Updates.Count -eq 0) {
            Write-Log 'Windows Update: nenhum driver pendente'
            return 'OK (nenhum driver pendente)'
        }
        $coll = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($u in $found.Updates) {
            if ($u.Title -match 'Firmware|BIOS|UEFI') {
                Write-Log ('Windows Update: ignorado (firmware/BIOS): ' + $u.Title)
                continue
            }
            if (-not $u.EulaAccepted) { $u.AcceptEula() }
            Write-Log ('Windows Update: pendente: ' + $u.Title)
            [void]$coll.Add($u)
        }
        if ($coll.Count -eq 0) { return 'OK (so firmware/BIOS pendente - ignorado)' }

        $dl = $session.CreateUpdateDownloader()
        $dl.Updates = $coll
        [void]$dl.Download()

        $ready = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($u in $coll) { if ($u.IsDownloaded) { [void]$ready.Add($u) } }
        if ($ready.Count -eq 0) { return 'AVISO (download dos drivers falhou)' }

        $inst = $session.CreateUpdateInstaller()
        $inst.Updates = $ready
        $r = $inst.Install()
        Write-Log ("Windows Update: resultado {0}, reinicio necessario: {1}" -f $r.ResultCode, $r.RebootRequired)
        if ($r.ResultCode -eq 2) { return ("OK ({0} driver(s) instalado(s))" -f $ready.Count) }
        if ($r.ResultCode -eq 3) { return 'AVISO (instalado com erros em alguns drivers - veja o log)' }
        return ("AVISO (instalacao nao concluiu - codigo {0})" -f $r.ResultCode)
    }

    function Step-DriverVendor {
        $m = [string]$S.Hw.Manufacturer

        if ($m -match 'Dell') {
            $dellRoots = @((Join-Path $env:ProgramFiles 'Dell'), (Join-Path ${env:ProgramFiles(x86)} 'Dell'))
            $exe = Find-Exe $dellRoots 'dcu-cli.exe'
            if (-not $exe) {
                [void](Install-WingetFirst @('Dell.CommandUpdate', 'Dell.CommandUpdate.Universal'))
                $exe = Find-Exe $dellRoots 'dcu-cli.exe'
            }
            if (-not $exe) { return 'AVISO (Dell Command Update nao instalado - veja o log)' }
            $rc = Invoke-Native $exe @('/applyUpdates', '-silent', '-reboot=disable')
            if ($rc -eq 0 -or $rc -eq 1 -or $rc -eq 500) { return "OK (Dell Command Update, codigo $rc)" }
            return "AVISO (Dell Command Update, codigo $rc - veja o log)"
        }

        if ($m -match '^HP|Hewlett') {
            $roots = @((Join-Path $env:ProgramFiles 'HP'), (Join-Path ${env:ProgramFiles(x86)} 'HP'), 'C:\SWSetup')
            $exe = Find-Exe $roots 'HPImageAssistant.exe'
            if (-not $exe) {
                [void](Install-WingetFirst @('HP.ImageAssistant', 'HP.HPImageAssistant'))
                $exe = Find-Exe $roots 'HPImageAssistant.exe'
            }
            if (-not $exe) { return 'AVISO (HP Image Assistant nao instalado - veja o log)' }
            $rep = Join-Path $logDir 'HPIA'
            New-Item -ItemType Directory -Path $rep -Force | Out-Null
            $rc = Invoke-Native $exe @('/Operation:Analyze', '/Action:Install', '/Category:Drivers', '/Selection:All', '/Silent', '/Noninteractive', "/ReportFolder:$rep", "/SoftpaqDownloadFolder:$rep")
            if ($rc -eq 0 -or $rc -eq 256 -or $rc -eq 3010) { return "OK (HP Image Assistant, codigo $rc)" }
            return "AVISO (HP Image Assistant, codigo $rc - veja o log)"
        }

        Write-Log "Fabricante '$m': sem ferramenta automatica neste script (usado apenas o Windows Update)"
        return "OK (fabricante '$m': sem ferramenta automatica - so Windows Update)"
    }

    function Step-DriverGPU {
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
        if ($gpus.Count -eq 0) { return 'AVISO (nenhuma placa de video encontrada)' }
        $warn = @()
        foreach ($g in $gpus) {
            $dt = $null
            if ($g.DriverDate) { $dt = $g.DriverDate }
            Write-Log ("GPU: {0} | driver {1} | data {2}" -f $g.Name, $g.DriverVersion, $dt)
            if ($g.Name -match 'Basic Display') { $warn += 'sem driver de video instalado' }
            elseif ($dt -and $dt -lt (Get-Date).AddYears(-2)) { $warn += ("{0}: driver de {1}" -f $g.Name, $dt.ToString('yyyy-MM-dd')) }
        }
        if ($warn.Count -gt 0) { return ('AVISO (atualizar video manualmente no site do fabricante - ' + ($warn -join '; ') + ')') }
        return 'OK (driver de video recente)'
    }

    function Step-DriverFinish {
        $after = Get-DriverSnapshot
        $changed = 0
        foreach ($k in $after.Keys) {
            if ($S.DrvBefore.ContainsKey($k)) {
                if ($S.DrvBefore[$k].Version -ne $after[$k].Version) {
                    Write-Log ("DRIVER ATUALIZADO: {0}: {1} -> {2}" -f $after[$k].Name, $S.DrvBefore[$k].Version, $after[$k].Version)
                    $changed++
                }
            }
            else {
                Write-Log ("DRIVER NOVO: {0}: {1}" -f $after[$k].Name, $after[$k].Version)
                $changed++
            }
        }
        $prob = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'OK' })
        foreach ($d in $prob) { Write-Log ("SEM DRIVER/COM PROBLEMA: {0} | {1} | {2}" -f $d.Class, $d.FriendlyName, $d.InstanceId) }
        if ($prob.Count -gt 0) { return ("AVISO ({0} alterado(s); {1} dispositivo(s) ainda com problema - veja o log)" -f $changed, $prob.Count) }
        return ("OK ({0} driver(s) alterado(s); nenhum dispositivo com problema)" -f $changed)
    }

    # ---------- Executor de etapa ----------
    function Invoke-Step([string]$Name, [scriptblock]$Action) {
        Write-Host ''
        Say "  [..] $Name - aguarde..."
        Write-Log "INICIO: $Name"
        $res = 'ERRO'
        try {
            $res = @(& $Action) | Select-Object -Last 1
        }
        catch {
            $res = 'ERRO (' + $_.Exception.Message + ')'
        }
        Write-Log "FIM: $Name => $res"
        if ($res -like 'OK*') { Say "  [OK] $Name" 'Green' }
        elseif ($res -like 'AVISO*') { Say "  [AVISO] $Name : $res" 'Yellow' }
        else { Say "  [ERRO] $Name : $res" 'Yellow' }
        $S.Results += [pscustomobject]@{ Etapa = $Name; Resultado = $res }
    }

    function Show-Report {
        Show-Header
        $h = $S.Hw
        Say ("  Fabricante : {0}" -f $h.Manufacturer)
        Say ("  Modelo     : {0}" -f $h.Model)
        Say ("  CPU        : {0}" -f $h.CPU)
        Say ("  Threads    : {0}" -f $h.Threads)
        Say ("  RAM        : {0}" -f $h.RAM)
        Say ("  GPU        : {0}" -f $h.GPU)
        Say ("  Disco      : {0}" -f $h.DISKTYPE)
        Say ("  Windows    : {0}" -f $h.OS)
        Say ("  Versao     : {0}" -f $h.OSVER)
        Say ("  Arquitetura: {0}" -f $h.ARCH)
        Say ("  Perfil     : {0}" -f $h.PROFILE)
        Say ''
        Say ("  Log: {0}" -f $S.Log)
        Say ''
        Read-Host '  Pressione ENTER para voltar' | Out-Null
    }

    # ---------- Inicio ----------
    Write-Log '============================================================'
    Write-Log 'PRIMECORE OPTIMIZER (PowerShell) - LOG'
    Write-Log ("Usuario: {0} em {1}" -f $env:USERNAME, $env:COMPUTERNAME)
    Write-Log '============================================================'

    try {
        Show-Header
        Say '  [DIAGNOSTICO] Detectando hardware...'
        Get-HardwareInfo

        while ($true) {
            Show-Header
            Say ("  CPU: {0}" -f $S.Hw.CPU)
            Say ("  RAM: {0}   Disco: {1}   Perfil: {2}" -f $S.Hw.RAM, $S.Hw.DISKTYPE, $S.Hw.PROFILE)
            Say '------------------------------------------------------------'
            Say ''
            Say '   [1] Otimizacao COMPLETA'
            Say '   [2] So limpeza e manutencao'
            Say '   [3] So ajustes de desempenho'
            Say '   [4] Atualizar DRIVERS (Windows Update + fabricante)'
            Say '   [5] TUDO (otimizacao completa + drivers)'
            Say ''
            Say '   [D] Diagnostico   [E] Restaurar energia   [L] Abrir logs'
            Say '   [0] Sair'
            Say ''
            $op = (Read-Host '  Opcao').Trim().ToUpper()

            $mode = $null
            if ($op -eq '1') { $mode = 'FULL' }
            elseif ($op -eq '2') { $mode = 'CLEAN' }
            elseif ($op -eq '3') { $mode = 'PERF' }
            elseif ($op -eq '4') { $mode = 'DRV' }
            elseif ($op -eq '5') { $mode = 'ALL' }
            elseif ($op -eq 'D') { Show-Report }
            elseif ($op -eq 'E') {
                $rc = Invoke-Native 'powercfg' @('/setactive', 'SCHEME_BALANCED')
                if ($rc -eq 0) { Say '  [OK] Plano Equilibrado ativado.' 'Green' } else { Say "  [ERRO] Codigo $rc" 'Yellow' }
                Read-Host '  Pressione ENTER para voltar' | Out-Null
            }
            elseif ($op -eq 'L') { Start-Process explorer.exe $logDir }
            elseif ($op -eq '0') { break }

            if (-not $mode) { continue }

            if ($mode -eq 'DRV' -or $mode -eq 'ALL') {
                if (-not (Test-Internet)) {
                    Say ''
                    Say '  [ERRO] Sem internet. Conecte o PC e tente novamente.' 'Yellow'
                    Say '         (os drivers de rede precisam estar instalados)' 'Yellow'
                    Read-Host '  Pressione ENTER para voltar' | Out-Null
                    continue
                }
            }

            # ---- Confirmacao ----
            $modeName = @{ FULL = 'COMPLETA'; CLEAN = 'SO LIMPEZA E MANUTENCAO'; PERF = 'SO AJUSTES DE DESEMPENHO'; DRV = 'ATUALIZACAO DE DRIVERS'; ALL = 'OTIMIZACAO COMPLETA + DRIVERS' }[$mode]
            Show-Header
            Say '  Sera executado:'
            Say ''
            Say ("   Modo: {0}   perfil {1}" -f $modeName, $S.Hw.PROFILE)
            Say ''
            $c = (Read-Host '  Confirmar? [S/N]').Trim().ToUpper()
            if ($c -ne 'S') { continue }

            # ---- Execucao ----
            $S.Results = @()
            Write-Log ("=== OTIMIZACAO: modo {0} perfil {1} ===" -f $mode, $S.Hw.PROFILE)
            Show-Header

            Invoke-Step 'Ponto de restauracao' { Step-RestorePoint }

            if ($mode -eq 'FULL' -or $mode -eq 'ALL') {
                Invoke-Step 'Limpeza de temporarios' { Step-Cleanup }
                Invoke-Step 'Manutencao dos componentes do Windows' { Step-ComponentCleanup }
                Invoke-Step 'Plano de energia' { Step-Power }
                Invoke-Step 'Efeitos visuais' { Step-Visuals }
                Invoke-Step 'Otimizacao do armazenamento' { Step-Storage }
                Invoke-Step 'Integridade do Windows (DISM + SFC)' { Step-Integrity }
            }
            elseif ($mode -eq 'CLEAN') {
                Invoke-Step 'Limpeza de temporarios' { Step-Cleanup }
                Invoke-Step 'Manutencao dos componentes do Windows' { Step-ComponentCleanup }
                Invoke-Step 'Otimizacao do armazenamento' { Step-Storage }
                Invoke-Step 'Integridade do Windows (DISM + SFC)' { Step-Integrity }
            }
            elseif ($mode -eq 'PERF') {
                Invoke-Step 'Plano de energia' { Step-Power }
                Invoke-Step 'Efeitos visuais' { Step-Visuals }
                Invoke-Step 'Otimizacao do armazenamento' { Step-Storage }
            }

            if ($mode -eq 'DRV' -or $mode -eq 'ALL') {
                Invoke-Step 'Drivers: leitura inicial' { Step-DriverInit }
                Invoke-Step 'Drivers: backup dos atuais' { Step-DriverBackup }
                Invoke-Step 'Drivers: Windows Update' { Step-DriverWU }
                Invoke-Step 'Drivers: ferramenta do fabricante' { Step-DriverVendor }
                Invoke-Step 'Drivers: placa de video' { Step-DriverGPU }
                Invoke-Step 'Drivers: conferencia final' { Step-DriverFinish }
            }

            # ---- Resumo ----
            Say ''
            Say '------------------------------------------------------------'
            Say '  RESUMO'
            Say '------------------------------------------------------------'
            foreach ($r in $S.Results) { Say ("   {0,-42} {1}" -f $r.Etapa, $r.Resultado) }
            Say '------------------------------------------------------------'
            Say ("   Log: {0}" -f $S.Log)
            Say ''
            Say '   Recomenda-se reiniciar antes da entrega ao cliente.'
            Say ''
            Write-Log '=== FIM DA OTIMIZACAO ==='

            $rs = (Read-Host '  Reiniciar agora? [S/N]').Trim().ToUpper()
            if ($rs -eq 'S') {
                Write-Log 'Reinicio solicitado'
                & shutdown.exe /r /t 15 /c 'PrimeCore Optimizer - reinicializacao pos-formatacao'
                Say ''
                Say '  Reiniciando em 15 segundos. Para cancelar: shutdown /a'
                Start-Sleep -Seconds 15
                break
            }
        }
    }
    finally {
        Write-Log 'Encerrado'
        Say ''
        Say '  PrimeCore - Tecnologia que funciona.'
        Say ''
        try {
            if ($null -ne $oldColor) { $Host.UI.RawUI.ForegroundColor = $oldColor }
            if ($null -ne $oldTitle) { $Host.UI.RawUI.WindowTitle = $oldTitle }
        } catch {}
    }
}

Start-PrimeCoreOptimizer

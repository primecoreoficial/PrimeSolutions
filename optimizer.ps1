# ============================================================
# PRIMECORE OPTIMIZER (PowerShell) - pos-formatacao Windows 10
#
# Uso (PowerShell como Administrador):
#   irm https://raw.githubusercontent.com/SEU_USUARIO/PrimeCore/main/optimizer.ps1 | iex
#
# Obs: arquivo propositalmente em ASCII (sem acentos) para nao
# haver problema de codificacao ao baixar com irm no Windows 10.
# ============================================================

# Link do proprio script (usado para reabrir como Administrador).
# Troque SEU_USUARIO pelo seu usuario do GitHub.
$RepoUrl = 'https://raw.githubusercontent.com/SEU_USUARIO/PrimeCore/main/optimizer.ps1'

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
            Say ''
            Say '   [D] Diagnostico   [E] Restaurar energia   [L] Abrir logs'
            Say '   [0] Sair'
            Say ''
            $op = (Read-Host '  Opcao').Trim().ToUpper()

            $mode = $null
            if ($op -eq '1') { $mode = 'FULL' }
            elseif ($op -eq '2') { $mode = 'CLEAN' }
            elseif ($op -eq '3') { $mode = 'PERF' }
            elseif ($op -eq 'D') { Show-Report }
            elseif ($op -eq 'E') {
                $rc = Invoke-Native 'powercfg' @('/setactive', 'SCHEME_BALANCED')
                if ($rc -eq 0) { Say '  [OK] Plano Equilibrado ativado.' 'Green' } else { Say "  [ERRO] Codigo $rc" 'Yellow' }
                Read-Host '  Pressione ENTER para voltar' | Out-Null
            }
            elseif ($op -eq 'L') { Start-Process explorer.exe $logDir }
            elseif ($op -eq '0') { break }

            if (-not $mode) { continue }

            # ---- Confirmacao ----
            $modeName = @{ FULL = 'COMPLETA'; CLEAN = 'SO LIMPEZA E MANUTENCAO'; PERF = 'SO AJUSTES DE DESEMPENHO' }[$mode]
            Show-Header
            Say '  Sera executado:'
            Say ''
            Say ("   Otimizacao Windows : {0}   perfil {1}" -f $modeName, $S.Hw.PROFILE)
            Say ''
            $c = (Read-Host '  Confirmar? [S/N]').Trim().ToUpper()
            if ($c -ne 'S') { continue }

            # ---- Execucao ----
            $S.Results = @()
            Write-Log ("=== OTIMIZACAO: modo {0} perfil {1} ===" -f $mode, $S.Hw.PROFILE)
            Show-Header

            Invoke-Step 'Ponto de restauracao' { Step-RestorePoint }

            if ($mode -eq 'FULL') {
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
            else {
                Invoke-Step 'Plano de energia' { Step-Power }
                Invoke-Step 'Efeitos visuais' { Step-Visuals }
                Invoke-Step 'Otimizacao do armazenamento' { Step-Storage }
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

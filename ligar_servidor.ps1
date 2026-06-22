$ErrorActionPreference = 'Stop'

$serverRoot = 'C:\Projetos\otserv - Tibia'
$serverExe = Join-Path $serverRoot 'crystalserver.exe'
$serverConfig = Join-Path $serverRoot 'config.lua'
$mysqlLauncher = 'C:\xampp\mysql_start.bat'
$apacheLauncher = 'C:\xampp\apache_start.bat'
$publicAddress = '177.192.12.76'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs
    exit
}

function Wait-ForPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutSeconds)

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $socket = [System.Net.Sockets.TcpClient]::new()
        try {
            $attempt = $socket.ConnectAsync($HostName, $Port)
            if ($attempt.Wait(1000) -and $socket.Connected) { return $true }
        } catch {
        } finally {
            $socket.Dispose()
        }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)

    return $false
}

try {
    Write-Host 'Ligando o FazendoTibia...' -ForegroundColor Cyan

    foreach ($required in @($serverExe, $serverConfig, $mysqlLauncher, $apacheLauncher)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Arquivo nao encontrado: $required" }
    }

    Write-Host 'Garantindo acesso pelo Firewall do Windows...'
    $firewallRules = @(
        @{ Name = 'FazendoTibia Site TCP 80'; Port = 80 },
        @{ Name = 'FazendoTibia Login TCP 7171'; Port = 7171 },
        @{ Name = 'FazendoTibia Jogo TCP 7172'; Port = 7172 }
    )
    foreach ($rule in $firewallRules) {
        & netsh.exe advfirewall firewall delete rule name="$($rule.Name)" | Out-Null
        & netsh.exe advfirewall firewall add rule name="$($rule.Name)" dir=in action=allow protocol=TCP localport=$($rule.Port) profile=private,public | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Nao foi possivel liberar a porta $($rule.Port) no Firewall." }
    }

    $config = Get-Content -LiteralPath $serverConfig -Raw
    $updatedConfig = $config -replace '(?m)^ip\s*=\s*"[^"]*"', "ip = `"$publicAddress`""
    if ($updatedConfig -ne $config) {
        Set-Content -LiteralPath $serverConfig -Value $updatedConfig -Encoding UTF8
    }

    if (-not (Get-Process -Name mysqld -ErrorAction SilentlyContinue)) {
        Write-Host 'Iniciando banco de dados...'
        Start-Process -FilePath $mysqlLauncher -WorkingDirectory 'C:\xampp' -WindowStyle Hidden
    }
    if (-not (Wait-ForPort -HostName '127.0.0.1' -Port 3306 -TimeoutSeconds 30)) {
        throw 'O banco de dados nao abriu a porta 3306.'
    }

    if (-not (Get-Process -Name httpd -ErrorAction SilentlyContinue)) {
        Write-Host 'Iniciando site de contas...'
        Start-Process -FilePath $apacheLauncher -WorkingDirectory 'C:\xampp' -WindowStyle Hidden
    }
    if (-not (Wait-ForPort -HostName '127.0.0.1' -Port 80 -TimeoutSeconds 30)) {
        throw 'O site nao abriu a porta 80.'
    }

    if (-not (Get-Process -Name crystalserver -ErrorAction SilentlyContinue)) {
        Write-Host 'Iniciando servidor do jogo...'
        Start-Process -FilePath $serverExe -WorkingDirectory $serverRoot -WindowStyle Hidden
    }
    if (-not (Wait-ForPort -HostName '127.0.0.1' -Port 7171 -TimeoutSeconds 180)) {
        throw 'O servidor nao abriu a porta 7171. Veja crystalserver-startup.out.log.'
    }
    if (-not (Wait-ForPort -HostName '127.0.0.1' -Port 7172 -TimeoutSeconds 15)) {
        throw 'O servidor nao abriu a porta 7172.'
    }

    Write-Host ''
    Write-Host 'SERVIDOR ONLINE' -ForegroundColor Green
    Write-Host "Site para criar conta: http://$publicAddress/"
    Write-Host 'Deixe esta janela aberta enquanto seus amigos jogam.'
    Write-Host 'Pode minimiza-la. Para desligar, feche esta janela e encerre crystalserver.'
    Read-Host 'Pressione Enter somente quando quiser fechar esta janela'
} catch {
    Write-Host ''
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Pressione Enter para fechar'
    exit 1
}

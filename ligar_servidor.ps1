$ErrorActionPreference = 'Stop'

$serverRoot = Join-Path $PSScriptRoot 'server'
$serverExe = Join-Path $serverRoot 'crystalserver.exe'
$serverConfig = Join-Path $serverRoot 'config.lua'
$serverPackageUrl = 'https://github.com/MarcosNatividade01/Tibiafriends/releases/latest/download/crystalserver-runtime.zip'
$serverVersionUrl = 'https://github.com/MarcosNatividade01/Tibiafriends/releases/latest/download/crystalserver-runtime.version'
$serverPackageName = 'crystalserver-runtime.zip'
$serverVersionName = 'crystalserver-runtime.version'
$publicAddress = '177.192.12.76'

$runtimeRoot = Join-Path $serverRoot 'runtime'
$mysqlRoot = Join-Path $runtimeRoot 'mysql'
$mysqlData = Join-Path $runtimeRoot 'mysql-data'
$mysqlIni = Join-Path $runtimeRoot 'portable-my.ini'
$mysqlExe = Join-Path $mysqlRoot 'bin\mysql.exe'
$mysqlAdminExe = Join-Path $mysqlRoot 'bin\mysqladmin.exe'
$mysqldExe = Join-Path $mysqlRoot 'bin\mysqld.exe'
$mysqlInstallExe = Join-Path $mysqlRoot 'bin\mysql_install_db.exe'
$phpRoot = Join-Path $runtimeRoot 'php'
$phpExe = Join-Path $phpRoot 'php.exe'
$phpIni = Join-Path $phpRoot 'php-portable.ini'
$htdocsRoot = Join-Path $runtimeRoot 'htdocs'
$siteConfig = Join-Path $htdocsRoot 'config.local.php'

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

function Invoke-MySql {
    param([string[]]$Arguments)
    & $mysqlExe @('--protocol=tcp', '--host=127.0.0.1', '--port=3306', '--user=root') @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao executar comando no MySQL portatil.' }
}

function Update-RepositoryFromGitHub {
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Host 'Git nao encontrado. Continuando sem atualizar a pasta pelo GitHub...' -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git'))) {
        Write-Host 'Esta pasta nao parece ser um repositorio Git. Continuando sem git pull...' -ForegroundColor Yellow
        return
    }

    Write-Host 'Verificando atualizacoes no GitHub...'
    Push-Location $PSScriptRoot
    try {
        & $git.Source fetch --prune origin main
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Nao foi possivel consultar o GitHub. Continuando com os arquivos locais...' -ForegroundColor Yellow
            return
        }

        $localCommit = (& $git.Source rev-parse HEAD).Trim()
        $remoteCommit = (& $git.Source rev-parse origin/main).Trim()

        if ($localCommit -eq $remoteCommit) {
            Write-Host 'Arquivos locais ja estao atualizados com o GitHub.' -ForegroundColor Green
            return
        }

        Write-Host 'Atualizacao encontrada no GitHub. Baixando arquivos...'
        & $git.Source pull --ff-only origin main
        if ($LASTEXITCODE -eq 0) {
            Write-Host 'Arquivos atualizados pelo GitHub com sucesso.' -ForegroundColor Green
        } else {
            Write-Host 'Nao foi possivel atualizar automaticamente pelo GitHub. Continuando com os arquivos locais...' -ForegroundColor Yellow
        }
    } finally {
        Pop-Location
    }
}

function Get-RemoteServerVersion {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -Uri $serverVersionUrl -UseBasicParsing
        return $response.Content.Trim()
    } catch {
        Write-Host 'Nao foi possivel consultar a versao online do pacote runtime do servidor. Continuando com o runtime local...' -ForegroundColor Yellow
        return $null
    }
}

function Install-ServerRuntime {
    $localVersionPath = Join-Path $serverRoot $serverVersionName
    $hasServer = (Test-Path -LiteralPath $serverExe) -and (Test-Path -LiteralPath $serverConfig)
    $remoteVersion = Get-RemoteServerVersion

    if ($hasServer -and $remoteVersion) {
        $localVersion = ''
        if (Test-Path -LiteralPath $localVersionPath) {
            $localVersion = (Get-Content -LiteralPath $localVersionPath -Raw).Trim()
        }

        if ($localVersion -eq $remoteVersion) { return }

        Write-Host 'Atualizacao do servidor encontrada no GitHub.' -ForegroundColor Yellow
    } elseif ($hasServer) {
        return
    } else {
        Write-Host 'Servidor CrystalServer nao encontrado nesta pasta.' -ForegroundColor Yellow
    }

    Write-Host 'Baixando CrystalServer do GitHub. Isso pode demorar na primeira vez...'

    $downloadPath = Join-Path $PSScriptRoot $serverPackageName
    $extractPath = Join-Path $PSScriptRoot '_server_extract'
    $preservedMysqlData = Join-Path $PSScriptRoot '_mysql_data_preserve'

    if (Test-Path -LiteralPath $downloadPath) { Remove-Item -LiteralPath $downloadPath -Force }
    if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }
    if (Test-Path -LiteralPath $preservedMysqlData) { Remove-Item -LiteralPath $preservedMysqlData -Recurse -Force }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $serverPackageUrl -OutFile $downloadPath -UseBasicParsing

    Write-Host 'Extraindo CrystalServer...'
    Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath -Force

    $extractedExe = Join-Path $extractPath 'crystalserver.exe'
    $extractedConfig = Join-Path $extractPath 'config.lua'
    if (-not ((Test-Path -LiteralPath $extractedExe) -and (Test-Path -LiteralPath $extractedConfig))) {
        throw 'O pacote baixado nao contem crystalserver.exe e config.lua na raiz.'
    }

    if (Test-Path -LiteralPath $mysqlData) {
        Move-Item -LiteralPath $mysqlData -Destination $preservedMysqlData
    }

    if (Test-Path -LiteralPath $serverRoot) { Remove-Item -LiteralPath $serverRoot -Recurse -Force }
    Move-Item -LiteralPath $extractPath -Destination $serverRoot

    if (Test-Path -LiteralPath $preservedMysqlData) {
        $restoredMysqlRoot = Join-Path $serverRoot 'runtime'
        if (-not (Test-Path -LiteralPath $restoredMysqlRoot)) { New-Item -ItemType Directory -Path $restoredMysqlRoot | Out-Null }
        $newMysqlData = Join-Path $restoredMysqlRoot 'mysql-data'
        if (Test-Path -LiteralPath $newMysqlData) { Remove-Item -LiteralPath $newMysqlData -Recurse -Force }
        Move-Item -LiteralPath $preservedMysqlData -Destination $newMysqlData
    }

    if ($remoteVersion) {
        Set-Content -LiteralPath (Join-Path $serverRoot $serverVersionName) -Value $remoteVersion -Encoding ASCII
    }

    Remove-Item -LiteralPath $downloadPath -Force
}

function Write-PortableConfigs {
    $serverPath = ($serverRoot -replace '\\', '/') + '/'
    $siteConfigText = @"
<?php
`$config['installed'] = true;
`$config['env'] = 'prod';
`$config['mail_enabled'] = false;
`$config['external_game_address'] = '$publicAddress';
`$config['lan_game_address'] = '192.168.0.250';
`$config['local_game_address'] = '127.0.0.1';
`$config['server_path'] = '$serverPath';
`$config['mail_admin'] = 'admin@gmail.com';
`$config['mail_address'] = 'admin@gmail.com';
`$config['date_timezone'] = 'America/Sao_Paulo';
`$config['client'] = '1500';
`$config['session_prefix'] = 'myaac_4wx6tfa6_';
`$config['cache_prefix'] = 'myaac_jofifieq_';
`$config['highscores_ids_hidden'] = array(1, 2, 3, 4, 5, 6);
"@
    Set-Content -LiteralPath $siteConfig -Value $siteConfigText -Encoding ASCII

    $phpExtDir = (Join-Path $phpRoot 'ext') -replace '\\', '/'
    $phpSessionDir = Join-Path $runtimeRoot 'php-sessions'
    if (-not (Test-Path -LiteralPath $phpSessionDir)) { New-Item -ItemType Directory -Path $phpSessionDir | Out-Null }
    $phpSessionPath = $phpSessionDir -replace '\\', '/'
    $phpIniText = @"
[PHP]
extension_dir="$phpExtDir"
extension=curl
extension=fileinfo
extension=gd2
extension=mbstring
extension=mysqli
extension=openssl
extension=pdo_mysql
date.timezone=America/Sao_Paulo
default_charset=UTF-8
memory_limit=256M
upload_max_filesize=32M
post_max_size=32M
max_execution_time=60
session.save_path="$phpSessionPath"
"@
    Set-Content -LiteralPath $phpIni -Value $phpIniText -Encoding ASCII

    $baseDir = $mysqlRoot -replace '\\', '/'
    $dataDir = $mysqlData -replace '\\', '/'
    @"
[mysqld]
basedir=$baseDir
datadir=$dataDir
port=3306
bind-address=127.0.0.1
innodb_flush_method=normal

[client]
port=3306
host=127.0.0.1
user=root
password=
"@ | Set-Content -LiteralPath $mysqlIni -Encoding ASCII
}

function Ensure-PortableDatabase {
    if (-not (Test-Path -LiteralPath $mysqlExe)) { throw "MySQL portatil nao encontrado: $mysqlExe" }

    if (-not (Test-Path -LiteralPath (Join-Path $mysqlData 'mysql'))) {
        Write-Host 'Criando banco de dados portatil...'
        if (-not (Test-Path -LiteralPath $mysqlData)) { New-Item -ItemType Directory -Path $mysqlData | Out-Null }
        Push-Location $mysqlRoot
        try {
            & $mysqlInstallExe "--datadir=$mysqlData" --password= | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel criar o banco MySQL portatil.' }
        } finally {
            Pop-Location
        }
    }

    if (-not (Wait-ForPort -HostName '127.0.0.1' -Port 3306 -TimeoutSeconds 1)) {
        Write-Host 'Iniciando banco de dados portatil...'
        Start-Process -FilePath $mysqldExe -ArgumentList @("`"--defaults-file=$mysqlIni`"", '--console') -WorkingDirectory $mysqlRoot -WindowStyle Hidden
    }
    if (-not (Wait-ForPort -HostName '127.0.0.1' -Port 3306 -TimeoutSeconds 45)) {
        throw 'O banco de dados portatil nao abriu a porta 3306.'
    }

    $databaseExists = $false
    try {
        $dbName = & $mysqlExe --protocol=tcp --host=127.0.0.1 --port=3306 --user=root --batch --skip-column-names -e "SHOW DATABASES LIKE 'otserv';" 2>$null
        $databaseExists = ($dbName -eq 'otserv')
    } catch {
        $databaseExists = $false
    }

    if (-not $databaseExists) {
        Write-Host 'Importando banco inicial do jogo...'
        Invoke-MySql -Arguments @('-e', 'CREATE DATABASE IF NOT EXISTS otserv CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;')
        Invoke-MySql -Arguments @('otserv', "--execute=source $((Join-Path $serverRoot 'otserv.sql') -replace '\\', '/')")
    }

    $grantCoinsSql = Join-Path $serverRoot 'grant_tibia_coins.sql'
    if (Test-Path -LiteralPath $grantCoinsSql) {
        Write-Host 'Garantindo Tibia Coins nas contas...'
        Invoke-MySql -Arguments @('otserv', "--execute=source $(($grantCoinsSql) -replace '\\', '/')")
    }
}

function Ensure-PortableSite {
    if (-not (Test-Path -LiteralPath $phpExe)) { throw "PHP portatil nao encontrado: $phpExe" }
    if (-not (Test-Path -LiteralPath (Join-Path $htdocsRoot 'clientcreateaccount.php'))) { throw "Site portatil nao encontrado: $htdocsRoot" }

    if (-not (Wait-ForPort -HostName '127.0.0.1' -Port 80 -TimeoutSeconds 1)) {
        Write-Host 'Iniciando site de contas portatil...'
        Start-Process -FilePath $phpExe -ArgumentList @('-c', "`"$phpIni`"", '-S', '0.0.0.0:80', '-t', "`"$htdocsRoot`"") -WorkingDirectory $htdocsRoot -WindowStyle Hidden
    }
    if (-not (Wait-ForPort -HostName '127.0.0.1' -Port 80 -TimeoutSeconds 30)) {
        throw 'O site portatil nao abriu a porta 80.'
    }
}

try {
    Write-Host 'Ligando o FazendoTibia...' -ForegroundColor Cyan

    Update-RepositoryFromGitHub
    Install-ServerRuntime

    foreach ($required in @($serverExe, $serverConfig, $mysqlInstallExe, $mysqldExe, $mysqlExe, $phpExe, $htdocsRoot)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Arquivo nao encontrado: $required" }
    }

    Write-PortableConfigs

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

    Ensure-PortableDatabase
    Ensure-PortableSite

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
    Write-Host 'Pode minimiza-la. Para desligar, feche esta janela e encerre crystalserver, mysqld e php.'
    Read-Host 'Pressione Enter somente quando quiser fechar esta janela'
} catch {
    Write-Host ''
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Pressione Enter para fechar'
    exit 1
}

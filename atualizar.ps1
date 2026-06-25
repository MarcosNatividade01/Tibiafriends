$ErrorActionPreference = 'Stop'

$packageUrl = 'https://github.com/MarcosNatividade01/Tibiafriends/releases/latest/download/FazendoTibia-Para-Amigos.zip'
$versionUrl = 'https://github.com/MarcosNatividade01/Tibiafriends/releases/latest/download/FazendoTibia-Para-Amigos.version'
$versionFile = Join-Path $PSScriptRoot 'FazendoTibia-Para-Amigos.version'

function Get-RemoteVersion {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -Uri $versionUrl -UseBasicParsing
        return $response.Content.Trim()
    } catch {
        Write-Host 'Nao foi possivel consultar atualizacoes no GitHub. Continuando com a versao local...' -ForegroundColor Yellow
        return $null
    }
}

function Get-LocalVersion {
    if (-not (Test-Path -LiteralPath $versionFile)) { return '' }
    return (Get-Content -LiteralPath $versionFile -Raw).Trim()
}

function Copy-UpdatedFiles {
    param([string]$SourcePath)

    $robocopyArgs = @(
        $SourcePath,
        $PSScriptRoot,
        '/E',
        '/R:2',
        '/W:1',
        '/XD',
        '.git',
        'characterdata',
        'cache',
        'log',
        'crashdump',
        '_package_update',
        '_server_extract',
        'server\runtime\mysql-data',
        'server\runtime\php-sessions',
        '/XF',
        'clientoptions.json'
    )

    & robocopy.exe @robocopyArgs | Out-Host
    if ($LASTEXITCODE -gt 7) {
        throw "Falha ao aplicar atualizacao. Codigo do Robocopy: $LASTEXITCODE"
    }
}

function Update-Package {
    $remoteVersion = Get-RemoteVersion
    if (-not $remoteVersion) { return }

    $localVersion = Get-LocalVersion
    if ($localVersion -eq $remoteVersion) { return }

    Write-Host "Atualizacao encontrada: $remoteVersion" -ForegroundColor Yellow
    Write-Host 'Baixando pacote atualizado do GitHub...'

    $downloadPath = Join-Path $PSScriptRoot 'FazendoTibia-Para-Amigos.update.zip'
    $extractPath = Join-Path $PSScriptRoot '_package_update'

    if (Test-Path -LiteralPath $downloadPath) { Remove-Item -LiteralPath $downloadPath -Force }
    if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }

    Invoke-WebRequest -Uri $packageUrl -OutFile $downloadPath -UseBasicParsing

    Write-Host 'Extraindo atualizacao...'
    Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath -Force

    $sourcePath = $extractPath
    $nestedRoot = Join-Path $extractPath 'Tibiafriends-main'
    if (Test-Path -LiteralPath $nestedRoot) {
        $sourcePath = $nestedRoot
    }

    if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'JOGAR.bat'))) {
        throw 'O pacote baixado nao contem os arquivos do cliente na raiz.'
    }

    Write-Host 'Aplicando atualizacao...'
    Copy-UpdatedFiles -SourcePath $sourcePath

    Set-Content -LiteralPath $versionFile -Value $remoteVersion -Encoding ASCII

    Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $extractPath -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host 'Atualizacao concluida.' -ForegroundColor Green
}

try {
    Update-Package
} catch {
    Write-Host "Nao foi possivel atualizar automaticamente: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Continuando com os arquivos locais...'
}

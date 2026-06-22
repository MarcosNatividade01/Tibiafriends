$ErrorActionPreference = 'Stop'

$dll = Join-Path $PSScriptRoot 'bin\Qt6WebEngineCore.dll'
$expectedHash = '228B98C149D4EBDFC1FB8E9443C416F1B6EBB323609B9475B52E6D74AF14D1E5'
$parts = @(
    "$dll.part1"
    "$dll.part2"
)

if ((Test-Path -LiteralPath $dll) -and
    (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash -eq $expectedHash) {
    exit 0
}

try {
    foreach ($part in $parts) {
        if (-not (Test-Path -LiteralPath $part)) {
            throw "Arquivo necessario ausente: $part"
        }
    }

    $temporary = "$dll.tmp"
    $output = [IO.File]::Create($temporary)
    try {
        foreach ($part in $parts) {
            $input = [IO.File]::OpenRead($part)
            try {
                $input.CopyTo($output)
            }
            finally {
                $input.Dispose()
            }
        }
    }
    finally {
        $output.Dispose()
    }

    if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ne $expectedHash) {
        throw 'As partes do Qt6WebEngineCore.dll estao incompletas ou corrompidas.'
    }

    Move-Item -LiteralPath $temporary -Destination $dll -Force
    Write-Host 'Cliente preparado com sucesso.'
}
catch {
    Write-Host "Nao foi possivel preparar o cliente: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item -LiteralPath "$dll.tmp" -Force -ErrorAction SilentlyContinue
    exit 1
}

@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0atualizar.ps1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0preparar_cliente.ps1"
if errorlevel 1 (
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$local=$false; try{$c=[Net.Sockets.TcpClient]::new();$a=$c.ConnectAsync('127.0.0.1',7171);$local=$a.Wait(1000)-and $c.Connected;$c.Dispose()}catch{}; if($local){exit 2}; $ports=80,7171,7172; $failed=@($ports | Where-Object { try { $c=[Net.Sockets.TcpClient]::new(); $a=$c.ConnectAsync('177.192.12.76',$_); $ok=$a.Wait(2500)-and $c.Connected; $c.Dispose(); -not $ok } catch { $true } }); if($failed){Add-Type -AssemblyName PresentationFramework; [Windows.MessageBox]::Show('O servidor ainda nao esta acessivel. No PC servidor, abra LIGAR SERVIDOR e deixe-o ligado. Portas com falha: '+($failed -join ', '),'FazendoTibia') | Out-Null; exit 1}"
if errorlevel 2 goto local
if errorlevel 1 exit /b 1

set "MINIMAP_DIR=%LOCALAPPDATA%\Tibia\packages\Tibia\minimap"
if not exist "%MINIMAP_DIR%" mkdir "%MINIMAP_DIR%"

copy /Y "assets\minimapmarkers.bin" "%MINIMAP_DIR%\" >nul
copy /Y "assets\Minimap_Color_*.png" "%MINIMAP_DIR%\" >nul
copy /Y "assets\Minimap_WaypointCost_*.png" "%MINIMAP_DIR%\" >nul

start "" "bin\client.exe"
endlocal
exit /b 0

:local
start "" "bin\client-local.exe"
endlocal

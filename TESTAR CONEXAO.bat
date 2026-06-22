@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ip='177.192.12.76'; 80,7171,7172 ^| ForEach-Object { $r=Test-NetConnection $ip -Port $_ -WarningAction SilentlyContinue; Write-Host ('Porta '+$_+': '+$(if($r.TcpTestSucceeded){'OK'}else{'BLOQUEADA'})) }; Read-Host 'Pressione Enter para fechar'"

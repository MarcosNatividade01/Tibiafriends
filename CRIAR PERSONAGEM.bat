@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$local=$false;try{$c=[Net.Sockets.TcpClient]::new();$a=$c.ConnectAsync('127.0.0.1',80);$local=$a.Wait(1000)-and$c.Connected;$c.Dispose()}catch{};if($local){Start-Process 'http://127.0.0.1/?account/create'}else{Start-Process 'http://177.192.12.76/?account/create'}"

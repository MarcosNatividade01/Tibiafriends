@echo off
title FazendoTibia - Servidor
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0atualizar.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ligar_servidor.ps1"

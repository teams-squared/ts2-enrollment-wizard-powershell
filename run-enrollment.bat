@echo off
cd /d "%~dp0"
powershell.exe -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0assets\enroll.ps1\"' -Verb RunAs"

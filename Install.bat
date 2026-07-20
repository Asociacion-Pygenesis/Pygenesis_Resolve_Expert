@echo off
REM Atajo en la raiz del paquete / repo: reenvia al instalador.
cd /d "%~dp0"
if exist "%~dp0installer\Install.bat" (
  call "%~dp0installer\Install.bat" %*
) else (
  echo No se encontro installer\Install.bat
  pause
  exit /b 1
)

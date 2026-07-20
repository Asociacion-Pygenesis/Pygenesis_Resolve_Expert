@echo off
setlocal
title Pygenesis ResolveExpert - Instalador
cd /d "%~dp0"

echo.
echo  Pygenesis ResolveExpert - Instalador
echo  =====================================
echo.
echo  Este asistente instalara:
echo    - Motor de inferencia local (GPU/CPU)
echo    - Modelo desde Hugging Face
echo    - Plugin Resolve Studio
echo    - Companion (Resolve Free)
echo.
echo  Requisitos: Python 3.10+ en PATH, conexion a Internet.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_pygenesis.ps1" %*
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE% neq 0 (
  echo  Instalacion fallida (codigo %EXITCODE%).
  echo  Revisa los mensajes anteriores.
) else (
  echo  Listo. Puedes cerrar esta ventana.
)
echo.
pause
exit /b %EXITCODE%

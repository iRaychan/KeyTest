@echo off
setlocal
set "TARGET=%~dp0"
if not exist "%TARGET%index.html" (
  echo KeySuite index.html was not found beside this patcher.
  set /p TARGET=Paste the full path to the extracted KeySuite source/repository folder: 
)
if "%TARGET%"=="" (
  echo No target folder was entered.
  pause
  exit /b 1
)
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 "%~dp0tools\apply_v300.py" --target "%TARGET%"
) else (
  python "%~dp0tools\apply_v300.py" --target "%TARGET%"
)
if errorlevel 1 (
  echo.
  echo V3.00 patch failed. Read the ERROR message above.
  pause
  exit /b 1
)
echo.
echo Open the target folder and upload the files inside KeySuite_V3.00_Changed_Files.zip to GitHub.
echo Preserve your working config.js.
pause

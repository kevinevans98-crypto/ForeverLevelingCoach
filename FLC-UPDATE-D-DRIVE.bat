@echo off
setlocal
title Forever Leveling Coach Updater - D Drive

echo.
echo Forever Leveling Coach Updater
echo ==============================
echo.

set "ADDONDIR=D:\Game Folder\World of Warcraft\_classic_beta_\Interface\AddOns"
set "TARGET=%ADDONDIR%\ForeverLevelingCoach"
set "ZIP=%TEMP%\ForeverLevelingCoach-update.zip"
set "EXTRACT=%TEMP%\ForeverLevelingCoach-update"
set "URL=https://github.com/kevinevans98-crypto/ForeverLevelingCoach/archive/refs/heads/ForeverLevelingCoach.zip"

echo Using AddOns folder:
echo   %ADDONDIR%
echo.

if not exist "%ADDONDIR%" (
  echo ERROR: AddOns folder not found:
  echo   %ADDONDIR%
  echo.
  pause
  exit /b 1
)

if exist "%ZIP%" del /f /q "%ZIP%" >nul 2>&1
if exist "%EXTRACT%" rmdir /s /q "%EXTRACT%" >nul 2>&1

echo Downloading latest addon from GitHub...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%ZIP%'"
if errorlevel 1 goto :fail

echo Extracting...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP%' -DestinationPath '%EXTRACT%' -Force"
if errorlevel 1 goto :fail

set "SOURCE=%EXTRACT%\ForeverLevelingCoach-ForeverLevelingCoach\ForeverLevelingCoach"

if not exist "%SOURCE%\ForeverLevelingCoach.toc" (
  echo ERROR: Downloaded addon files were not found.
  goto :fail
)

if exist "%TARGET%" (
  echo Removing old addon files...
  rmdir /s /q "%TARGET%"
)

echo Installing latest version...
xcopy "%SOURCE%" "%TARGET%\" /E /I /Y >nul
if errorlevel 1 goto :fail

echo.
echo Update complete.
echo Installed to:
echo   %TARGET%
echo.
echo If WoW is open, type /reload.
echo.
pause
exit /b 0

:fail
echo.
echo Update failed.
echo.
pause
exit /b 1

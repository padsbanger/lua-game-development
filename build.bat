@echo off
setlocal

set "ROOT=%~dp0"
set "GAME_DIR=%ROOT%"
set "BUILD_DIR=%ROOT%build"
set "ZIP_PATH=%BUILD_DIR%\DeskbarQuest.zip"
set "LOVE_PATH=%BUILD_DIR%\DeskbarQuest.love"
set "EXE_PATH=%BUILD_DIR%\DeskbarQuest.exe"
set "LOVE_EXE="
set "LOVE_DIR="

for /f "delims=" %%I in ('where love.exe 2^>nul') do (
  if not defined LOVE_EXE set "LOVE_EXE=%%I"
)

if not defined LOVE_EXE if exist "%ProgramFiles%\LOVE\love.exe" set "LOVE_EXE=%ProgramFiles%\LOVE\love.exe"
if not defined LOVE_EXE if exist "%ProgramFiles(x86)%\LOVE\love.exe" set "LOVE_EXE=%ProgramFiles(x86)%\LOVE\love.exe"
if not defined LOVE_EXE if exist "%LOCALAPPDATA%\Programs\LOVE\love.exe" set "LOVE_EXE=%LOCALAPPDATA%\Programs\LOVE\love.exe"

if not exist "%GAME_DIR%main.lua" (
  echo Could not find main.lua in "%GAME_DIR%".
  pause
  exit /b 1
)

if not defined LOVE_EXE (
  echo Could not find love.exe.
  pause
  exit /b 1
)

for %%I in ("%LOVE_EXE%") do set "LOVE_DIR=%%~dpI"
mkdir "%BUILD_DIR%" 2>nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $paths = @('%GAME_DIR%data', '%GAME_DIR%main.lua', '%GAME_DIR%conf.lua', '%GAME_DIR%README.md') | Where-Object { Test-Path -LiteralPath $_ }; Compress-Archive -LiteralPath $paths -DestinationPath '%ZIP_PATH%' -Force; Move-Item -LiteralPath '%ZIP_PATH%' -Destination '%LOVE_PATH%' -Force"

if errorlevel 1 (
  echo Failed to create "%LOVE_PATH%".
  pause
  exit /b 1
)

copy /y "%LOVE_DIR%*.dll" "%BUILD_DIR%\" >nul
if errorlevel 1 (
  echo Failed to copy LOVE runtime files. Close any running Deskbar Quest window and try again.
  pause
  exit /b 1
)

copy /y "%LOVE_DIR%license.txt" "%BUILD_DIR%\" >nul
if errorlevel 1 (
  echo Failed to copy LOVE license file. Close any running Deskbar Quest window and try again.
  pause
  exit /b 1
)

copy /b /y "%LOVE_EXE%"+"%LOVE_PATH%" "%EXE_PATH%" >nul
if errorlevel 1 (
  echo Failed to create "%EXE_PATH%". Close any running Deskbar Quest window and try again.
  pause
  exit /b 1
)

echo Built "%EXE_PATH%".
echo Ship the whole "%BUILD_DIR%" folder, not just the exe.

@echo off
setlocal

set "ROOT=%~dp0"
set "GAME_DIR=%ROOT%games\comet-orchard"
set "BUILD_DIR=%ROOT%build\comet-orchard"
set "ZIP_PATH=%BUILD_DIR%\comet-orchard.zip"
set "LOVE_PATH=%BUILD_DIR%\comet-orchard.love"
set "EXE_PATH=%BUILD_DIR%\CometOrchard.exe"
set "LOVE_EXE="
set "LOVE_DIR="

for /f "delims=" %%I in ('where love.exe 2^>nul') do (
  if not defined LOVE_EXE set "LOVE_EXE=%%I"
)

if not defined LOVE_EXE if exist "%ProgramFiles%\LOVE\love.exe" set "LOVE_EXE=%ProgramFiles%\LOVE\love.exe"
if not defined LOVE_EXE if exist "%ProgramFiles(x86)%\LOVE\love.exe" set "LOVE_EXE=%ProgramFiles(x86)%\LOVE\love.exe"
if not defined LOVE_EXE if exist "%LOCALAPPDATA%\Programs\LOVE\love.exe" set "LOVE_EXE=%LOCALAPPDATA%\Programs\LOVE\love.exe"

if not exist "%GAME_DIR%\main.lua" (
  echo Could not find the game at "%GAME_DIR%".
  echo Run this file from the lua-game-development project root.
  pause
  exit /b 1
)

if not defined LOVE_EXE (
  echo Could not find love.exe.
  echo Install LOVE or add its install folder to PATH.
  pause
  exit /b 1
)

for %%I in ("%LOVE_EXE%") do set "LOVE_DIR=%%~dpI"

mkdir "%BUILD_DIR%" 2>nul

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; Compress-Archive -Path '%GAME_DIR%\*' -DestinationPath '%ZIP_PATH%' -Force; Move-Item -LiteralPath '%ZIP_PATH%' -Destination '%LOVE_PATH%' -Force"

if errorlevel 1 (
  echo Failed to create "%LOVE_PATH%".
  pause
  exit /b 1
)

copy /y "%LOVE_DIR%*.dll" "%BUILD_DIR%\" >nul
copy /y "%LOVE_DIR%license.txt" "%BUILD_DIR%\" >nul
copy /b /y "%LOVE_EXE%"+"%LOVE_PATH%" "%EXE_PATH%" >nul

echo Built "%EXE_PATH%".
echo Ship the whole "%BUILD_DIR%" folder, not just the exe.

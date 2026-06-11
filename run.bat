@echo off
setlocal

set "GAME_DIR=%~dp0"
set "LOVE_EXE="

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

"%LOVE_EXE%" "%GAME_DIR%"

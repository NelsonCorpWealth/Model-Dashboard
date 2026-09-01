@echo off
setlocal enabledelayedexpansion
REM =================================================================
REM  Model Dashboard - weekly publish
REM
REM  1. rebuilds data.json from the model workbooks
REM  2. checks it against Model Dashboard.xlsx
REM  3. copies the page + data into the git clone and pushes
REM
REM  The git clone lives OUTSIDE OneDrive on purpose - a .git folder
REM  inside a synced folder gets corrupted by the sync client.
REM =================================================================
cd /d "%~dp0"
set "REPO=%USERPROFILE%\NelsonCorp-Model-Dashboard"
set "REMOTE=https://github.com/NelsonCorpWealth/Model-Dashboard.git"

REM ---------- preflight ------------------------------------------
where git >nul 2>&1
if errorlevel 1 (
  echo.
  echo   git is not installed, or not on your PATH.
  echo   Install it from https://git-scm.com/download/win  ^(accept the defaults^)
  echo.
  goto :fail
)

set "PY="
python --version >nul 2>&1 && set "PY=python"
if not defined PY ( py -3 --version >nul 2>&1 && set "PY=py -3" )
if not defined PY (
  echo.
  echo   Python is not installed, or not on your PATH.
  echo   Install it from https://www.python.org/downloads/windows/
  echo   IMPORTANT: tick "Add python.exe to PATH" on the first screen.
  echo.
  goto :fail
)
echo Using !PY!

if not exist "%REPO%\.git" (
  echo.
  echo First run - cloning the site repo to %REPO%
  git clone "%REMOTE%" "%REPO%"
  if errorlevel 1 goto :fail
)

REM ---------- build ----------------------------------------------
echo.
echo [1/3] Reading the model workbooks...
!PY! build_data.py
if errorlevel 1 goto :fail

echo.
echo [2/3] Checking the numbers against Model Dashboard.xlsx...
!PY! verify.py

REM ---------- publish --------------------------------------------
echo.
echo [3/3] Publishing...
copy /y index.html "%REPO%\" >nul
copy /y data.json  "%REPO%\" >nul
pushd "%REPO%"
git pull --rebase --quiet
git add -A
git diff --cached --quiet && (echo Nothing changed since the last publish. & popd & goto :done)
git commit -q -m "Model data %date%"
git push
if errorlevel 1 (popd & goto :fail)
popd

:done
echo.
echo Published.  https://nelsoncorpwealth.github.io/Model-Dashboard/
echo The site refreshes about a minute after the push.
echo.
pause
exit /b 0

:fail
echo.
echo *** Stopped - nothing was published. The reason is above. ***
echo.
pause
exit /b 1

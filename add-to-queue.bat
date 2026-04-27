@echo off
setlocal EnableDelayedExpansion

set "_CFG=%~dp0config.env"
if not exist "%_CFG%" (
    call :bootstrap_config
    echo.
    echo config.env has been created at:
    echo   %_CFG%
    echo.
    echo Edit it to match your setup, then trigger this script again.
    echo.
    pause
    exit /b 1
)
for /f "usebackq tokens=1,* delims==" %%A in ("%_CFG%") do (
    set "_K=%%A"
    if not "!_K:~0,1!"=="#" if not "!_K!"=="" set "%%A=%%B"
)

if "!STAGING!"=="C:\path\to\staging" (
    echo ERROR: STAGING in config.env is still the default placeholder value.
    echo Please open config.env and set STAGING to a real staging folder path.
    echo [%date% %time%] ERROR: STAGING is unconfigured ^(placeholder value^). Edit config.env and set a real path. >> "%~dp0queue.log"
    echo.
    pause
    exit /b 1
)

set "_ARG=%~1"
set "_DEST="
for /f "delims=" %%D in ('powershell -NoProfile -Command "$dests=$env:DESTINATIONS -split '\|'|ForEach-Object{$s=$_ -split ':',2;[PSCustomObject]@{L=$s[0];P=$s[1]}};$autos=$env:AUTODETECT -split '\|';$parts=$env:_ARG -split '\\';$hit=$autos|Where-Object{$parts -icontains $_}|Select-Object -First 1;if($hit){$d=$dests|Where-Object{$_.L -ieq $hit}|Select-Object -First 1;if($d){[Console]::Error.WriteLine('Auto-detected: '+$d.L);Write-Output $d.P;exit}};$n=1;foreach($d in $dests){[Console]::Error.WriteLine('  ['+($n++)+'] '+$d.L+' -> '+$d.P)};[Console]::Error.WriteLine('  [0] Cancel');$c=Read-Host 'Choose';if([string]::IsNullOrEmpty($c)-or $c -eq '0'){Write-Output 'CANCEL'}else{$idx=[int]$c-1;if($idx -ge 0 -and $idx -lt $dests.Count){Write-Output $dests[$idx].P}else{[Console]::Error.WriteLine('Invalid choice');Write-Output 'CANCEL'}}"') do set "_DEST=%%D"

if "!_DEST!"=="CANCEL" (
    echo Cancelled.
    timeout /t 1 >nul
    exit /b 0
)
if "!_DEST!"=="" (
    echo No destination selected.
    timeout /t 1 >nul
    exit /b 0
)

echo "%~1";;!_DEST! >> "%~dp0queue.txt"
echo Queued: %~nx1 -^> !_DEST!

start "Queue Processor" cmd /c "%~dp0process-queue.bat"

timeout /t 2 >nul
goto :eof

:bootstrap_config
echo Creating default config.env -- please edit it before running.
(
    echo # Queue Processor Configuration
    echo # Edit this file to match your setup before running.
    echo.
    echo # Path to 7-Zip executable
    echo SEVENZIP=C:\Program Files\7-Zip\7z.exe
    echo.
    echo # Temporary extraction folder
    echo STAGING=C:\path\to\staging
    echo.
    echo # Destinations: pipe-separated Label:Path pairs
    echo DESTINATIONS=TV:C:\Media\TV^|Movies:C:\Media\Movies^|Other:C:\Media\Other
    echo.
    echo # Auto-detect: pipe-separated folder names matching destination labels
    echo # If a folder in the source path exactly equals one of these names ^(case-insensitive^),
    echo # the destination with the same label is chosen automatically.
    echo AUTODETECT=TV^|Movies
) > "%_CFG%"
exit /b 0

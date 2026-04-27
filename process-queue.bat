@echo off
setlocal EnableDelayedExpansion

set "_CFG=%~dp0config.env"
if not exist "%_CFG%" (
    call :bootstrap_config
    echo.
    echo config.env has been created at:
    echo   %_CFG%
    echo.
    echo Edit it to match your setup, then run this script again.
    echo.
    pause
    exit /b 1
)
for /f "usebackq tokens=1,* delims==" %%A in ("%_CFG%") do (
    set "_K=%%A"
    if not "!_K:~0,1!"=="#" if not "!_K!"=="" set "%%A=%%B"
)

set QFILE=%~dp0queue.txt
set LOGFILE=%~dp0queue.log
set LOCKFILE=%~dp0queue.lock

:: Fail early if STAGING is still the placeholder
if "!STAGING!"=="C:\path\to\staging" (
    echo ERROR: STAGING in config.env is still the default placeholder value.
    echo Please open config.env and set STAGING to a real staging folder path.
    echo [%date% %time%] ERROR: STAGING is unconfigured ^(placeholder value^). Edit config.env and set a real path. >> "%LOGFILE%"
    echo.
    pause
    exit /b 1
)

:: Check for lock file — distinguish a stale lock from an active instance
if exist "%LOCKFILE%" (
    for /f %%C in ('tasklist /FI "WINDOWTITLE eq Queue Processor" 2^>nul ^| find /c "cmd.exe"') do set _COUNT=%%C
    if !_COUNT! GTR 1 exit /b 0
    echo ERROR: A stale lock file was found and no processor is currently running.
    echo   %LOCKFILE%
    echo.
    echo The previous run was likely aborted unexpectedly.
    echo To resume cleanly:
    echo   1. Delete %LOCKFILE%
    echo   2. Check %QFILE% and remove any entries you do not want re-processed.
    echo   3. Run this script again.
    echo.
    echo [%date% %time%] ERROR: Stale lock file found, no active processor detected. Delete %LOCKFILE% and review %QFILE% before resuming. >> "%LOGFILE%"
    pause
    exit /b 1
)

:: Create lock file
echo %date% %time% > "%LOCKFILE%"

echo Queue processor running. Ctrl+C to stop.
echo.

:loop
if not exist "%QFILE%" goto wait

for /f "usebackq delims=" %%L in ("%QFILE%") do (
    for /f "tokens=1,2 delims=;" %%A in ("%%L") do (
        set "RARFILE=%%~A"
        set "DEST=%%B"
    )
    echo Extracting: !RARFILE!
    echo Destination: !DEST!
    echo.
    echo Queue:
    set _N=0
    for /f "usebackq delims=" %%Q in ("%QFILE%") do (
        set /a _N+=1
        for /f "tokens=1,2 delims=;" %%X in ("%%Q") do (
            echo   !_N!. %%~nxX -^> %%Y
        )
    )
    echo.
    echo [%date% %time%] Processing: !RARFILE! >> "%LOGFILE%"

    "%SEVENZIP%" x "!RARFILE!" -o"%STAGING%" -y -bso0 -bsp1 && (
        echo Moving to: !DEST!
        set "_DEST=!DEST!"
        powershell -NoProfile -Command "$f=@('*****','&****','*&***','**&**','***&*','****&');$i=0;$tmp=[IO.Path]::GetTempFileName();$p=Start-Process robocopy -ArgumentList $env:STAGING,$env:_DEST,'/MOV','/E','/R:3','/W:5','/NJH','/NJS','/NDL','/NC','/NS','/NP' -RedirectStandardOutput $tmp -NoNewWindow -PassThru;$cur='';$row=-1;while(-not $p.HasExited){$l=Get-Content $tmp -Tail 1 -EA SilentlyContinue;if($l -and $l.Trim()){$cur=$l.Trim()};if($row -lt 0){Write-Host('  '+$cur);$row=[Console]::CursorTop;Write-Host('  '+$f[$i%%$f.Length])-NoNewline}else{[Console]::SetCursorPosition(0,$row-1);Write-Host('  '+$cur.PadRight(60));[Console]::SetCursorPosition(0,$row);Write-Host('  '+$f[$i%%$f.Length])-NoNewline};$i++;Start-Sleep -Milliseconds 500};Write-Host'';Remove-Item $tmp -EA SilentlyContinue;exit $p.ExitCode"
        rd /s /q "%STAGING%" 2>nul
        echo Done.
        echo [%date% %time%] SUCCESS: !RARFILE! -^> !DEST! >> "%LOGFILE%"
    ) || (
        rd /s /q "%STAGING%" 2>nul
        echo FAILED.
        echo [%date% %time%] FAILED: !RARFILE! >> "%LOGFILE%"
    )
    echo.
    more +1 "%QFILE%" > "%QFILE%.tmp" 2>nul
    move /y "%QFILE%.tmp" "%QFILE%" >nul 2>nul
    for %%Q in ("%QFILE%") do if %%~zQ==0 del "%QFILE%"
    goto loop
)

:wait
goto cleanup

:cleanup
del "%LOCKFILE%" 2>nul
exit /b 0

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
    echo AUTODETECT=TV^|Movies
) > "%_CFG%"
exit /b 0

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

set "_FOLDERS="
:arg_loop
if "%~1"=="" goto :arg_done
if not exist "%~1\" (
    echo ERROR: Not a folder or does not exist:
    echo   %~1
    echo.
    pause
    exit /b 1
)
if "!_FOLDERS!"=="" (
    set "_FOLDERS=%~1"
) else (
    set "_FOLDERS=!_FOLDERS!|%~1"
)
shift /1
goto :arg_loop
:arg_done
if "!_FOLDERS!"=="" (
    echo.
    echo Usage: drag one or more folders onto this script.
    echo.
    pause
    exit /b 1
)

set "_LOCK=%~dp0queue.lock"
set "_QUEUE=%~dp0queue.txt"
set "_TMPOUT=%TEMP%\rar-queue-folder-%RANDOM%.txt"

powershell -NoProfile -Command "$folders=$env:_FOLDERS -split '\|';$dests=$env:DESTINATIONS -split '\|'|ForEach-Object{$s=$_ -split ':',2;[PSCustomObject]@{L=$s[0];P=$s[1]}};$autos=$env:AUTODETECT -split '\|';$files=$folders|ForEach-Object{Get-ChildItem -Path $_ -Recurse -Filter '*.rar' -EA SilentlyContinue}|Where-Object{$_.Name -notmatch '\.part\d+\.rar$' -or $_.Name -match '\.part0*1\.rar$'}|Sort-Object FullName -Unique;if(-not $files){[Console]::Error.WriteLine('No RAR files found in: '+($folders -join ', '));exit 1};$results=New-Object System.Collections.Generic.List[PSCustomObject];$needPrompt=New-Object System.Collections.Generic.List[object];foreach($f in $files){$parts=$f.FullName -split '\\';$hit=$autos|Where-Object{$parts -icontains $_}|Select-Object -First 1;if($hit){$d=$dests|Where-Object{$_.L -ieq $hit}|Select-Object -First 1;if($d){$results.Add([PSCustomObject]@{File=$f.FullName;Dest=$d.P});[Console]::Error.WriteLine('Auto: '+$f.Name+' -> '+$d.L)}else{$needPrompt.Add($f)}}else{$needPrompt.Add($f)}};if($needPrompt.Count -gt 0){[Console]::Error.WriteLine('');[Console]::Error.WriteLine([string]$needPrompt.Count+' file(s) need a destination:');foreach($f in $needPrompt){[Console]::Error.WriteLine('  '+$f.Name)};[Console]::Error.WriteLine('');$n=1;foreach($d in $dests){[Console]::Error.WriteLine('  ['+($n++)+'] '+$d.L+' -> '+$d.P)};[Console]::Error.WriteLine('  [0] Cancel');$c=Read-Host 'Choose destination for unlisted files';if([string]::IsNullOrEmpty($c) -or $c -eq '0'){exit 1};$idx=[int]$c-1;if($idx -lt 0 -or $idx -ge $dests.Count){[Console]::Error.WriteLine('Invalid choice');exit 1};$fd=$dests[$idx].P;foreach($f in $needPrompt){$results.Add([PSCustomObject]@{File=$f.FullName;Dest=$fd})}};$results|Sort-Object File|ForEach-Object{Write-Output([char]34+$_.File+[char]34+';;'+$_.Dest)}" 1>"!_TMPOUT!"
if errorlevel 1 (
    del "!_TMPOUT!" 2>nul
    echo Cancelled.
    timeout /t 2 >nul
    exit /b 0
)

set "_CNT=0"
for /f "usebackq delims=" %%L in ("!_TMPOUT!") do set /a _CNT+=1
if !_CNT!==0 (
    del "!_TMPOUT!" 2>nul
    echo No files to queue.
    timeout /t 2 >nul
    exit /b 0
)

if not exist "!_LOCK!" goto :add_and_start

for /f "delims=" %%T in ('powershell -NoProfile -Command "if((Get-Date)-(Get-Item '!_LOCK!').LastWriteTime -gt [TimeSpan]::FromHours(24)){'OLD'}else{'RECENT'}"') do set "_LOCKAGE=%%T"

if "!_LOCKAGE!"=="RECENT" (
    type "!_TMPOUT!" >> "!_QUEUE!"
    del "!_TMPOUT!" 2>nul
    echo Queued !_CNT! file(s).
    exit /b 0
)

echo.
echo  WARNING: A stale lock file was found ^(older than 24 hours^).
echo  The queue processor may have crashed or been killed.
echo.
echo  Lock file : !_LOCK!
echo  Queue file: !_QUEUE!
echo.
echo  [1] Delete queue.txt and queue.lock, then start fresh with these files
echo  [2] Abort -- investigate and clean up manually
echo.
choice /c 12 /n /m "Choose [1/2]: "
if errorlevel 2 (
    del "!_TMPOUT!" 2>nul
    echo Aborted. Clean up the files listed above before retrying.
    timeout /t 3 >nul
    exit /b 0
)
del "!_QUEUE!" 2>nul
del "!_LOCK!"

:add_and_start
type "!_TMPOUT!" >> "!_QUEUE!"
del "!_TMPOUT!" 2>nul
echo Queued !_CNT! file(s). Starting processor...
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

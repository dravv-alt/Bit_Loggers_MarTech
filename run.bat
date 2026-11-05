@echo off
setlocal enabledelayedexpansion

title CampaignGrid — Bit Loggers Mobile App Launcher

echo ======================================================================
echo          CAMPAIGNGRID — CAMPAIGN MANAGEMENT PLATFORM
echo          Mobile Application Launcher (Flutter + TimescaleDB)
echo ======================================================================
echo.

:: 1. Locate Flutter
if exist "C:\Users\bhavv\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=C:\Users\bhavv\flutter\bin\flutter.bat"
) else if exist "C:\Users\%USERNAME%\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=C:\Users\%USERNAME%\flutter\bin\flutter.bat"
) else if exist "C:\src\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=C:\src\flutter\bin\flutter.bat"
) else (
    where flutter >nul 2>nul
    if !errorlevel! equ 0 (
        set "FLUTTER_CMD=flutter"
    ) else (
        set "FLUTTER_CMD=C:\Users\bhavv\flutter\bin\flutter.bat"
    )
)

echo [*] Using Flutter: !FLUTTER_CMD!
echo.

set "ROOT_DIR=%~dp0"
if "%ROOT_DIR:~-1%"=="\" set "ROOT_DIR=%ROOT_DIR:~0,-1%"

:: 2. Check / Start Docker container bitloggers-timescaledb
echo [*] Checking dedicated TimescaleDB container (bitloggers-timescaledb)...
where docker >nul 2>nul
if %errorlevel% equ 0 (
    docker --context default ps >nul 2>nul
    if !errorlevel! neq 0 (
        if exist "C:\Program Files\Docker\Docker\Docker Desktop.exe" (
            echo [*] Docker Desktop is not running. Launching Docker Desktop...
            start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            echo [*] Waiting 12 seconds for Docker daemon...
            ping 127.0.0.1 -n 12 >nul
        )
    )
    docker --context default ps -a --format "{{.Names}}" 2>nul | findstr /i "^bitloggers-timescaledb$" >nul 2>nul
    if !errorlevel! equ 0 (
        docker --context default ps --format "{{.Names}}" 2>nul | findstr /i "^bitloggers-timescaledb$" >nul 2>nul
        if !errorlevel! neq 0 (
            echo [*] Starting existing container bitloggers-timescaledb on port 5438...
            docker --context default start bitloggers-timescaledb >nul 2>nul
        ) else (
            echo [OK] bitloggers-timescaledb is running on port 5438.
        )
    ) else (
        echo [*] Attempting to create and start bitloggers-timescaledb on port 5438...
        docker --context default run -d --name bitloggers-timescaledb -p 5438:5432 -e POSTGRES_USER=bitloggers -e POSTGRES_PASSWORD=bitloggers_password -e POSTGRES_DB=bit_loggers timescale/timescaledb:2.28.3-pg17-oss 2>nul
    )
) else (
    echo [!] Docker command not in PATH; skipping Docker check.
)
echo.

:: 3. Start Backend Server if not already active on port 3000
echo [*] Checking Backend API Server on port 3000...
netstat -ano | findstr /r ":3000.*LISTENING" >nul 2>nul
if %errorlevel% neq 0 (
    echo [*] Starting Backend Server in background window...
    cd /d "%ROOT_DIR%"
    start "Bit Loggers Backend API (PostgreSQL + TimescaleDB)" /min cmd /c "node server/start.js"
    ping 127.0.0.1 -n 3 >nul
) else (
    echo [OK] Backend API Server is already active on http://localhost:3000.
)
echo.

:: 4. Navigate into Flutter directory
cd /d "%ROOT_DIR%\bit_loggers_app"
if not exist "pubspec.yaml" (
    echo [ERROR] Could not find bit_loggers_app/pubspec.yaml!
    pause
    exit /b 1
)

:: Check if command line argument was passed directly
if /i "%~1"=="windows" goto RUN_WINDOWS
if /i "%~1"=="android" goto RUN_ANDROID
if /i "%~1"=="chrome" goto RUN_CHROME
if /i "%~1"=="devices" goto LIST_DEVICES
if /i "%~1"=="apk" goto BUILD_APK
if /i "%~1"=="test" goto RUN_TESTS

:: 5. Menu selection
:MENU
echo ======================================================================
echo  Choose how you want to run the Flutter Mobile Application:
echo ======================================================================
echo  [1] Run on Windows Desktop (Native desktop client - fast ^& immediate)
echo  [2] Run on Connected Android Device or Emulator (Mobile)
echo  [3] Run on Chrome (Web Preview / Debugger)
echo  [4] List all connected devices (flutter devices)
echo  [5] Build Android APK (Release APK for sideloading)
echo  [6] Run 14/14 Architecture Tests (PostgreSQL + TimescaleDB engine)
echo  [0] Exit
echo ======================================================================
set /p "CHOICE=Enter choice (1-6, default is 1): "

if "%CHOICE%"=="" set "CHOICE=1"
if "%CHOICE%"=="1" goto RUN_WINDOWS
if "%CHOICE%"=="2" goto RUN_ANDROID
if "%CHOICE%"=="3" goto RUN_CHROME
if "%CHOICE%"=="4" goto LIST_DEVICES
if "%CHOICE%"=="5" goto BUILD_APK
if "%CHOICE%"=="6" goto RUN_TESTS
if "%CHOICE%"=="0" goto EXIT_SCRIPT

echo [!] Invalid choice. Please select 0 to 6.
echo.
goto MENU

:RUN_WINDOWS
echo.
echo [*] Launching Flutter Application on Windows Desktop...
call "!FLUTTER_CMD!" run -d windows
goto DONE

:RUN_ANDROID
echo.
echo [*] Checking connected Android devices...
call "!FLUTTER_CMD!" devices
echo.
echo [*] Launching on Android device/emulator...
call "!FLUTTER_CMD!" run -d android
goto DONE

:RUN_CHROME
echo.
echo [*] Launching on Chrome...
call "!FLUTTER_CMD!" run -d chrome
goto DONE

:LIST_DEVICES
echo.
echo [*] Connected Devices:
call "!FLUTTER_CMD!" devices
echo.
pause
goto MENU

:BUILD_APK
echo.
echo [*] Building Android Release APK...
call "!FLUTTER_CMD!" build apk --release
echo.
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ==================================================================
    echo [SUCCESS] APK built successfully at:
    echo %cd%\build\app\outputs\flutter-apk\app-release.apk
    echo ==================================================================
)
pause
goto MENU

:RUN_TESTS
echo.
echo [*] Running 14/14 LLD Architecture Tests against TimescaleDB...
cd /d "%~dp0"
node tests/run-all-tests.js
cd /d "%~dp0bit_loggers_app"
echo.
pause
goto MENU

:DONE
echo.
echo [*] Application process ended.
pause

:EXIT_SCRIPT
endlocal

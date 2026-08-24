@echo off
REM ============================================================================
REM  mediasoup-demo one-click startup script (Windows)
REM
REM  What it does:
REM    1. Start mediasoup SFU server (port 4443 signaling / 44444 media)
REM    2. Start frontend Vite service (port 5555, HTTPS) and auto-open two pages:
REM       - producer page: capture camera/mic and publish
REM       - consumer page: subscribe and play only (for single camera/mic test)
REM
REM  Usage (Windows only): double-click this script, or run start-all.bat in cmd
REM       Do NOT run it with bash (Git Bash / WSL / MSYS): "bash start-all.bat"
REM       will be parsed by bash and fail with "@echo: command not found" etc.
REM       In Git Bash use: ./start-all.sh
REM  Stop:  run stop-all.bat
REM ============================================================================

setlocal

set "ROOT=%~dp0"
set "SERVER_DIR=%ROOT%server"
set "APP_DIR=%ROOT%app"

echo ============================================================
echo   mediasoup-demo one-click startup
echo ============================================================
echo   Project root: %ROOT%
echo.

REM ---------------------------------------------------------------------------
REM 1. Check Node.js
REM ---------------------------------------------------------------------------
where node >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Node.js not found. Please install Node.js ^>= 22
    echo         Download: https://nodejs.org/
    pause
    exit /b 1
)
for /f "delims=" %%v in ('node --version') do set "NODE_VER=%%v"
echo [OK] Node.js installed: %NODE_VER%

REM ---------------------------------------------------------------------------
REM 2. Check dependencies (skip install if already present)
REM ---------------------------------------------------------------------------
if not exist "%SERVER_DIR%\node_modules" (
    echo [INFO] server dependencies not found, installing...
    pushd "%SERVER_DIR%"
    call npm ci
    if errorlevel 1 (
        echo [ERROR] server dependencies install failed
        popd
        pause
        exit /b 1
    )
    popd
    echo [OK] server dependencies installed
) else (
    echo [OK] server dependencies already present, skip
)

if not exist "%APP_DIR%\node_modules" (
    echo [INFO] app dependencies not found, installing...
    pushd "%APP_DIR%"
    call npm install --legacy-peer-deps
    if errorlevel 1 (
        echo [ERROR] app dependencies install failed
        popd
        pause
        exit /b 1
    )
    popd
    echo [OK] app dependencies installed
) else (
    echo [OK] app dependencies already present, skip
)

REM ---------------------------------------------------------------------------
REM 3. Check config file and TLS certificate
REM ---------------------------------------------------------------------------
if not exist "%SERVER_DIR%\config.mjs" (
    echo [ERROR] config file missing: %SERVER_DIR%config.mjs
    echo         Please create it based on server\config.example.mjs
    pause
    exit /b 1
)

if not exist "%SERVER_DIR%\cert.pem" (
    echo [INFO] TLS certificate not found, generating self-signed cert...
    pushd "%SERVER_DIR%"
    call node generate-cert.mjs
    if errorlevel 1 (
        echo [ERROR] certificate generation failed
        popd
        pause
        exit /b 1
    )
    popd
    echo [OK] TLS certificate generated
) else (
    echo [OK] TLS certificate already present, skip
)

echo.
echo ============================================================
echo   Starting services (two new windows)
echo ============================================================

REM ---------------------------------------------------------------------------
REM 3.5 Clean up leftover processes from a previous run (avoid EADDRINUSE)
REM ---------------------------------------------------------------------------
echo [INFO] Cleaning up leftover processes on ports 4443/44444/5555...
for %%p in (4443 44444 5555) do (
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%%p " ^| findstr "LISTENING"') do (
        echo [INFO] Killing leftover process PID %%a on port %%p
        taskkill /f /pid %%a >nul 2>nul
    )
)
echo [INFO] Cleanup done.
echo.

REM ---------------------------------------------------------------------------
REM 4. Start server (new window)
REM ---------------------------------------------------------------------------
echo [INFO] Starting mediasoup SFU server...
start "mediasoup-server" cmd /k "cd /d "%SERVER_DIR%" && set DEBUG=mediasoup-demo-server* && node lib/index.js"

REM Wait for server port to be ready
echo [INFO] Waiting for server to start (port 4443)...
set /a COUNT=0
:wait_server
timeout /t 1 /nobreak >nul
set /a COUNT+=1
netstat -ano | findstr ":4443 " | findstr "LISTENING" >nul
if not errorlevel 1 goto server_ready
if %COUNT% geq 30 (
    echo [ERROR] server startup timeout (30 seconds elapsed)
    pause
    exit /b 1
)
goto wait_server
:server_ready
echo [OK] server started (port 4443)

REM ---------------------------------------------------------------------------
REM 5. Start frontend (new window), auto-open producer + consumer pages
REM ---------------------------------------------------------------------------
echo [INFO] Starting frontend Vite service (port 5555)...
start "mediasoup-app" cmd /k "cd /d "%APP_DIR%" && npm start"
REM Note: DEBUG env var with wildcards must NOT be set for the app window.
REM The server window sets DEBUG=mediasoup-demo-server* only (no extra patterns).

echo.
echo ============================================================
echo   Startup complete!
echo ============================================================
echo   Server (SFU):     https://localhost:4443  (WSS signaling)
echo   Frontend page:    https://localhost:5555
echo.
echo   The frontend auto-opens two browser pages:
echo     - producer: capture camera/mic and publish
echo     - consumer: subscribe and play only (single camera/mic test)
echo.
echo   On first visit, the browser will warn about the self-signed
echo   certificate. Click "Advanced" -^> "Proceed" to continue, and
echo   allow camera and microphone permissions in the browser.
echo.
echo   To stop services, run stop-all.bat
echo ============================================================

endlocal

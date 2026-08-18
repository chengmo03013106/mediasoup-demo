@echo off
REM ============================================================================
REM  mediasoup-demo one-click stop script (Windows)
REM
REM  What it does: stop mediasoup SFU server and frontend Vite service
REM ============================================================================

echo ============================================================
echo   Stopping mediasoup-demo services...
echo ============================================================

REM Close service windows (match by window title)
taskkill /fi "WINDOWTITLE eq mediasoup-server*" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq mediasoup-app*" /f >nul 2>nul

REM Fallback: find and kill processes by port
for %%p in (4443 44444 5555) do (
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%%p " ^| findstr "LISTENING"') do (
        echo [INFO] Killing process PID %%a on port %%p
        taskkill /f /pid %%a >nul 2>nul
    )
)

echo.
echo [OK] services stopped
pause

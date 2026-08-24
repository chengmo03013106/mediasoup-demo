@echo off
REM ============================================================================
REM  mediasoup-demo one-click stop script (Windows)
REM
REM  What it does: stop mediasoup SFU server and frontend Vite service.
REM  Uses /T (tree kill) so child node processes are killed too, otherwise the
REM  server's node.exe would survive as an orphan and keep holding the terminal
REM  pipe (mediasoup-demo-terminal.sock), causing EADDRINUSE on next start.
REM ============================================================================

echo ============================================================
echo   Stopping mediasoup-demo services...
echo ============================================================

REM Close service windows (match by window title). /T kills the whole tree
REM (the cmd window AND its child node.exe).
taskkill /fi "WINDOWTITLE eq mediasoup-server*" /f /t >nul 2>nul
taskkill /fi "WINDOWTITLE eq mediasoup-app*" /f /t >nul 2>nul

REM Fallback: find and kill processes by port (also with /T tree kill).
for %%p in (4443 44444 5555) do (
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%%p " ^| findstr "LISTENING"') do (
        echo [INFO] Killing process tree PID %%a on port %%p
        taskkill /f /t /pid %%a >nul 2>nul
    )
)

echo.
echo [OK] services stopped
pause

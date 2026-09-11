@echo off
title MindBurst Mobile App Preview
echo ==============================================
echo   MindBurst - Offline AI Personal Memory
echo ==============================================
echo Starting app in mobile portrait preview mode...
echo.

py -3.10 main.py

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] App exited with an error. Press any key to exit.
    pause
)

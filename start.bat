@echo off
setlocal EnableDelayedExpansion
title LiveSTT

echo.
echo ============================================
echo   LiveSTT - Start Script
echo ============================================
echo.

echo [1/6] Python check...
where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   Python not found. Installing...
    winget install Python.Python.3.12 --accept-source-agreements --accept-package-agreements
    if %ERRORLEVEL% NEQ 0 (
        echo   [ERROR] Python install failed.
        echo   Please install from: https://www.python.org/downloads/
        echo   Check 'Add Python to PATH' during install!
        pause
        exit /b 1
    )
    echo   Python installed! Refreshing PATH...
    call RefreshEnv.cmd >nul 2>&1
    for /f "tokens=*" %%P in ('powershell -NoProfile -Command "[System.Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH','User')"') do set PATH=%%P
)
for /f "tokens=*" %%i in ('python --version 2^>^&1') do echo   %%i found

echo [2/6] ffmpeg check...
where ffmpeg >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   ffmpeg not found. Installing...
    winget install Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
    if %ERRORLEVEL% NEQ 0 (
        echo   [ERROR] ffmpeg install failed.
        echo   Please install from: https://ffmpeg.org/download.html
        pause
        exit /b 1
    )
    echo   ffmpeg installed! Refreshing PATH...
    for /f "tokens=*" %%P in ('powershell -NoProfile -Command "[System.Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH','User')"') do set PATH=%%P
)
echo   ffmpeg found

echo [3/6] Ollama check...
where ollama >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   Ollama not found. Installing...
    winget install Ollama.Ollama --accept-source-agreements --accept-package-agreements
    if %ERRORLEVEL% NEQ 0 (
        echo   [ERROR] Ollama install failed.
        echo   Please install from: https://ollama.com/download
        echo   (STT works without Ollama. Translation/Summary won't work)
        set SKIP_OLLAMA=1
    ) else (
        echo   Ollama installed! Refreshing PATH...
        for /f "tokens=*" %%P in ('powershell -NoProfile -Command "[System.Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH','User')"') do set PATH=%%P
        where ollama >nul 2>&1
        if %ERRORLEVEL% NEQ 0 (
            echo   PATH refresh failed. Please close and re-run this file once.
            pause
            exit /b 0
        )
        echo   Ollama ready!
    )
) else (
    echo   Ollama found
)

echo [4/6] Python packages check...
python -c "import aiohttp; import faster_whisper; import yt_dlp" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo   Installing required packages...
    pip install -r "%~dp0requirements.txt"
    if %ERRORLEVEL% NEQ 0 (
        echo   [ERROR] Package install failed.
        echo   Try manually: pip install -r requirements.txt
        pause
        exit /b 1
    )
    echo   Packages installed!
) else (
    echo   Python packages OK
)

if not defined SKIP_OLLAMA (
    echo [5/6] Ollama model check...
    curl -s http://localhost:11434/api/tags >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo   Starting Ollama service...
        start /min "" ollama serve
        timeout /t 5 /nobreak >nul
    )
    echo   Ollama service running
    ollama list 2>nul | findstr /i "gemma3:4b" >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo   Downloading gemma3:4b model... (approx 3GB)
        ollama pull gemma3:4b
        if %ERRORLEVEL% NEQ 0 (
            echo   [WARN] Model download failed.
        ) else (
            echo   Model downloaded!
        )
    ) else (
        echo   gemma3:4b model found
    )
) else (
    echo [5/6] Ollama skipped
)

echo [6/6] Starting LiveSTT server...
echo.
echo ============================================
echo   Browser will open automatically.
echo   (Whisper model loading: 1-2 min)
echo.
echo   Input:  http://localhost:8765
echo   Viewer: http://localhost:8765/viewer.html
echo.
echo   Close this window to stop.
echo ============================================
echo.

start /min "" cmd /c "for /L %%i in (1,1,120) do (timeout /t 2 /nobreak >nul & curl -s http://localhost:8765/api/status >nul 2>&1 && (start http://localhost:8765 & exit /b 0))"

python "%~dp0server.py"

echo.
echo Server stopped.
pause

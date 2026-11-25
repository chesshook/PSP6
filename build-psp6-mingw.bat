@echo off
setlocal EnableExtensions

rem PSP6 native Release build for MinGW-w64 x86_64 UCRT GCC.
rem Set PSP6_PORTABLE=1 before running to omit -march=native/-mtune=native.

set "ROOT=%~dp0"
cd /d "%ROOT%"

echo.
echo  ____  ____  ____
echo ^|  _ ^|/ ___^|^|  _ ^|
echo ^| ^|_) ^| ^|   ^| ^|_) ^|
echo ^|  __/^| ^|___^|  __/
echo ^|_^|    \____^|_^|       Native PSP Emulator
echo.

where git >nul 2>nul || (echo [ERROR] Git was not found in PATH.& exit /b 1)
where cmake >nul 2>nul || (echo [ERROR] CMake was not found in PATH.& exit /b 1)
where ninja >nul 2>nul || (echo [ERROR] Ninja was not found in PATH.& exit /b 1)
where gcc >nul 2>nul || (echo [ERROR] MinGW GCC was not found in PATH.& exit /b 1)
where g++ >nul 2>nul || (echo [ERROR] MinGW G++ was not found in PATH.& exit /b 1)

echo [PSP6] Compiler:
g++ --version
if errorlevel 1 exit /b 1
echo.

if not exist "upstream\PPSSPP\.git" (
    echo [PSP6] Fetching pinned PPSSPP source and submodules...
) else (
    echo [PSP6] Checking pinned PPSSPP source...
)

git submodule update --init --recursive --depth 1
if errorlevel 1 (
    echo [ERROR] Upstream source setup failed.
    exit /b 1
)

set "BUILD_DIR=build-mingw-native"
set "TUNE_FLAGS=-march=native -mtune=native"
if "%PSP6_PORTABLE%"=="1" (
    set "BUILD_DIR=build-mingw-portable"
    set "TUNE_FLAGS="
)

set "JOBS=4"
for /f %%N in ('powershell -NoProfile -Command "[Environment]::ProcessorCount" 2^>nul') do set "JOBS=%%N"

set "OPT_FLAGS=-O3 -DNDEBUG %TUNE_FLAGS% -flto=auto -ffunction-sections -fdata-sections -fno-math-errno -fno-strict-aliasing"

echo [PSP6] Configuring %BUILD_DIR%...
cmake -S "upstream\PPSSPP" -B "%BUILD_DIR%" -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=gcc ^
  -DCMAKE_CXX_COMPILER=g++ ^
  -DCMAKE_C_FLAGS_RELEASE="%OPT_FLAGS%" ^
  -DCMAKE_CXX_FLAGS_RELEASE="%OPT_FLAGS%" ^
  -DCMAKE_EXE_LINKER_FLAGS_RELEASE="-flto=auto -Wl,--gc-sections -static -static-libgcc -static-libstdc++" ^
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ^
  -DHEADLESS=ON ^
  -DUNITTEST=ON ^
  -DATLAS_TOOL=OFF ^
  -DUSE_CCACHE=OFF
if errorlevel 1 (
    echo [ERROR] CMake configuration failed.
    exit /b 1
)

echo.
echo [PSP6] Building with %JOBS% jobs...
cmake --build "%BUILD_DIR%" --parallel %JOBS%
if errorlevel 1 (
    echo [ERROR] Compilation or linking failed. See the first compiler error above.
    exit /b 1
)

if not exist "dist" mkdir "dist"
if not exist "dist\assets" mkdir "dist\assets"

if exist "%BUILD_DIR%\PPSSPPWindows.exe" (
    copy /y "%BUILD_DIR%\PPSSPPWindows.exe" "dist\PSP6.exe" >nul
) else (
    echo [ERROR] PPSSPPWindows.exe was not produced.
    exit /b 1
)

if exist "%BUILD_DIR%\PPSSPPHeadless.exe" copy /y "%BUILD_DIR%\PPSSPPHeadless.exe" "dist\PSP6Headless.exe" >nul
if exist "%BUILD_DIR%\PPSSPPUnitTest.exe" copy /y "%BUILD_DIR%\PPSSPPUnitTest.exe" "dist\PSP6UnitTest.exe" >nul

robocopy "upstream\PPSSPP\assets" "dist\assets" /E /NFL /NDL /NJH /NJS /NC /NS >nul
if errorlevel 8 (
    echo [ERROR] Asset packaging failed.
    exit /b 1
)

echo.
echo [PSP6] BUILD SUCCESSFUL
echo Main executable : dist\PSP6.exe
echo Headless tests  : dist\PSP6Headless.exe
echo Unit tests      : dist\PSP6UnitTest.exe
echo.
echo Note: Native-tuned builds are optimized for this CPU. For wider CPU
echo compatibility run: set PSP6_PORTABLE=1 ^& build-psp6-mingw.bat
exit /b 0

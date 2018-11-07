@echo off
cls

del /Q test\.target\*.exe

if not exist "ppl2.exe" goto COMPILE
del ppl2.exe

:COMPILE
dub build --parallel --build=debug --config=test --arch=x86_64 --compiler=dmd


if not exist "ppl2.exe" goto FAIL
ppl2.exe


if not exist "test\.target\test.exe" goto FAIL
call getfilesize.bat test\.target\test.exe
echo.
echo Running test\.target\test.exe (%filesize% bytes)
echo.
test\.target\test.exe
echo.
echo.
goto END


:FAIL
echo Compile or config error


:END
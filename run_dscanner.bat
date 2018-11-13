@echo off

set INCL=-I \work\dmd2\src\phobos
set INCL=%INCL% -I \work\dmd2\src\druntime\src
set INCL=%INCL% -I \work\ldc2-1.12.0-windows-x64\import

rem set INCL=%INCL% -I C:\Users\pvm_2_000\AppData\Local\dub\packages\dlangui-0.9.180\dlangui\src

rem set INCL=%INCL% -I C:\pvmoore\d\libs\common\src
rem set INCL=%INCL% -I C:\pvmoore\d\libs\llvm\src

\work\dscanner\dscanner --report -I src %INCL% src > dscanner_report.txt

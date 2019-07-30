REM %1 base path
REM %2 file list

REM list_libs cache\tensorflow_r1.13\bazel-bin\tensorflow\ tf_imports.cpp

set FOLDER=%~dp1
set OUTPUT=%2

echo Creating %2

setlocal EnableDelayedExpansion
for /L %%n in (1 1 500) do if "!FOLDER:~%%n,1!" neq "" set /a "len=%%n+1"
setlocal DisableDelayedExpansion

if EXIST %OUTPUT% (
    del %OUTPUT%
)

for /R %1 %%g in (*.lib) do (
    set "absPath=%%g"
    setlocal EnableDelayedExpansion
    set "relPath=!absPath:~%len%!"

    REM TODO Replace \ with / in paths for pragma
    set "PRAGMA=#pragma comment(lib, "!relPath:\=/!")"
    echo(!PRAGMA! >>%OUTPUT%

    REM echo(!relPath! >>%OUTPUT%
    endlocal
)

REM %1  dll
REM %2  lib

set DLL=%1
set LIB=%2


echo Creating %2
REM TODO likely unnecessary

REM From https://www.gnu.org/software/gnulib/manual/html_node/Visual-Studio-Compatibility.html
echo EXPORTS > %LIB%.def
dumpbin /nologo /exports %DLL%.dll | tail -n+20 | awk '{ print $4 }' >> %LIB%.def

REM TODO apply /LTCG linkopt for /GL build
lib /NOLOGO /MACHINE:x64 /def:%LIB%.def /out:%LIB%.lib

REM del /Q %LIB%.txt %LIB%.def

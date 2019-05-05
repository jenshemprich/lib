call build_tensorflow.bat Debug
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow.bat Release
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow.bat Release-avx2
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow.bat Release-avx2-fma
if %errorlevel% neq 0 exit /b %errorlevel%

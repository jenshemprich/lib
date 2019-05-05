call build_tensorflow.bat Release-cuda
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow.bat Release-cuda-avx2
if %errorlevel% neq 0 exit /b %errorlevel%

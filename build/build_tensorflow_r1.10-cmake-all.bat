call build_tensorflow_with_cmake.bat Debug
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow_with_cmake.bat Release
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow_with_cmake.bat Release-avx2
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow_with_cmake.bat Release-cuda
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow_with_cmake.bat Release-cuda-avx2
if %errorlevel% neq 0 exit /b %errorlevel%

call build_tensorflow_with_cmake.bat Release-avx2-fma
if %errorlevel% neq 0 exit /b %errorlevel%

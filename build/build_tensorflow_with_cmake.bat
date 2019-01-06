REM %1 = configuration
REM %2 = path to tensorflow sources
REM %3 = build dir

REM Defaults

if NOT [%1] == [] (
    set VS_SOLUTION_DIR_NAME=%1
)else (
    set VS_SOLUTION_DIR_NAME=Debug
)

if NOT [%2] == [] (
    set TENSORFLOW_SOURCES=%2
)else (
    set TENSORFLOW_SOURCES=%~dp0\tensorflow_r1.10-cmake
)

REM if NOT [%3] == [] (
REM    set TENSORFLOW_BUILD_DIR=%3
REM )else (
REM    set TENSORFLOW_BUILD_DIR=%~dp0\cmake
REM )


if EXIST "%TENSORFLOW_SOURCES%\.git"  (
    pushd "%TENSORFLOW_SOURCES%"
        git pull
    popd
)else (
    git clone --single-branch --branch r1.10 https://github.com/jenshemprich/tensorflow.git "%TENSORFLOW_SOURCES%"
)


REM cmake parameters

set CMAKE_SCRIPTS=%~dp0\scripts
call %CMAKE_SCRIPTS%\cmake_build_path.bat
call %CMAKE_SCRIPTS%\cmake_cuda_path.bat
call %CMAKE_SCRIPTS%\cmake_build_config.bat

REM /O2 is automatically set by cmake
if /I %VS_SOLUTION_DIR_NAME%==Debug (
    set TENSORFLOW_WIN_CPU_SIMD_OPTION="/arch:AVX"
    set CMAKE_CONFIGURATION_TYPE=Debug
) else (
    if /I not x%VS_SOLUTION_DIR_NAME:avx2=%==x%VS_SOLUTION_DIR_NAME% (
        set TENSORFLOW_WIN_CPU_SIMD_OPTION="/arch:AVX2"
        set CMAKE_CONFIGURATION_TYPE=Release
    ) else (
        set TENSORFLOW_WIN_CPU_SIMD_OPTION="/arch:AVX"
        set CMAKE_CONFIGURATION_TYPE=Release
    )
)

REM TODO global optimization with /GL -> set separately from /arch since cmake can only detect a single flag

if /I not x%VS_SOLUTION_DIR_NAME:cuda=%==x%VS_SOLUTION_DIR_NAME% (
    set TENSORFLOW_ENABLE_GPU_FLAG="ON"
) else (
    set TENSORFLOW_ENABLE_GPU_FLAG="OFF"
)

set TENSORFLOW_BUILD_CC_TESTS_FLAG="OFF"

set CMAKE_DEV_PATH_BUILD=%TENSORFLOW_SOURCES%\cmake_build
set CMAKE_INSTALL_PREFIX="%CMAKE_DEV_PATH_LIB%\tensorflow\%TENSORFLOW_RELEASE%\%TENSORFLOW_VS_BUILD%\%VS_SOLUTION_DIR_NAME%"
set CMAKE_TENSORFLOW_BUILD_PATH=%CMAKE_DEV_PATH_BUILD%\tensorflow\%TENSORFLOW_RELEASE%\%TENSORFLOW_VS_BUILD%\%VS_SOLUTION_DIR_NAME%

pushd %TENSORFLOW_SOURCES%\tensorflow\contrib\cmake

cmake . -B%CMAKE_TENSORFLOW_BUILD_PATH% -A x64 ^
-G %CMAKE_GENERATOR% ^
-DCMAKE_CONFIGURATION_TYPES=%CMAKE_CONFIGURATION_TYPE% ^
-Dtensorflow_BUILD_ALL_KERNELS=ON ^
-Dtensorflow_BUILD_CC_EXAMPLE=ON ^
-Dtensorflow_BUILD_CC_TESTS=%TENSORFLOW_BUILD_CC_TESTS_FLAG% ^
-Dtensorflow_BUILD_CONTRIB_KERNELS=ON ^
-Dtensorflow_BUILD_PYTHON_BINDINGS=OFF ^
-Dtensorflow_BUILD_SHARED_LIB=ON ^
-Dtensorflow_DISABLE_EIGEN_FORCEINLINE=OFF ^
-Dtensorflow_ENABLE_MKL_SUPPORT=OFF ^
-Dtensorflow_ENABLE_MKLDNN_SUPPORT=OFF ^
-Dtensorflow_ENABLE_GPU=%TENSORFLOW_ENABLE_GPU_FLAG% ^
-Dtensorflow_CUDA_VERSION=10 ^
-Dtensorflow_CUDNN_VERSION=7 ^
-DCUDA_USE_STATIC_CUDA_RUNTIME=ON ^
-DCUDA_SDK_ROOT_DIR=%CUDA_SDK_ROOT_DIR% ^
-DCUDA_TOOLKIT_ROOT_DIR=%CUDA_TOOLKIT_ROOT_DIR% ^
-DCUDA_HOST_COMPILER=%CUDA_HOST_COMPILER% ^
-DCUDNN_HOME=%CUDNN_HOME% ^
-Dtensorflow_ENABLE_GRPC_SUPPORT=ON ^
-Dtensorflow_OPTIMIZE_FOR_NATIVE_ARCH=ON ^
-Dtensorflow_WIN_CPU_SIMD_OPTIONS=%TENSORFLOW_WIN_CPU_SIMD_OPTION% ^
-DCMAKE_INSTALL_PREFIX=%CMAKE_INSTALL_PREFIX%

popd

if %errorlevel% neq 0 exit /b %errorlevel%

REM devenv %CMAKE_DEV_PATH_BUILD%\tensorflow\%TENSORFLOW_RELEASE%\%TENSORFLOW_VS_BUILD%\%VS_SOLUTION_DIR_NAME%\Tensorflow.sln
REM /p:CL_MPCount=6 ^
REM /m:1 ^

MSBuild.exe "%CMAKE_TENSORFLOW_BUILD_PATH%\INSTALL.vcxproj" ^
/verbosity:minimal ^
/p:Configuration=%CMAKE_CONFIGURATION_TYPE% ^
/t:Build ^
/p:Platform=x64 ^
/p:PreferredToolArchitecture=x64 ^
/filelogger


if %errorlevel% neq 0 exit /b %errorlevel%

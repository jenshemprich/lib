REM %1 = configuration
REM %2 = path to tensorflow sources
REM %3 = build dir

set PreferredToolArchitecture=x64

set CMAKE_SCRIPTS=%~dp0\scripts
call %CMAKE_SCRIPTS%\cmake_build_path.bat
call %CMAKE_SCRIPTS%\cmake_cuda_path.bat
call %CMAKE_SCRIPTS%\cmake_build_config.bat


REM Defaults

set ROOT=%~dp0
set BUILD_CACHE=%ROOT%cache

if NOT [%1] == [] (
    set VS_SOLUTION_DIR_NAME=%1
)else (
    set VS_SOLUTION_DIR_NAME=Debug
)

if NOT [%2] == [] (
    set TENSORFLOW_SOURCES=%2
)else (
    set TENSORFLOW_SOURCES=%BUILD_CACHE%\tensorflow_%TENSORFLOW_RELEASE%
)


if EXIST "%TENSORFLOW_SOURCES%\.git"  (
    pushd "%TENSORFLOW_SOURCES%"
        git pull
    popd
) else (
    git clone --single-branch --branch %TENSORFLOW_RELEASE% https://github.com/tensorflow/tensorflow.git "%TENSORFLOW_SOURCES%"
    pushd "%TENSORFLOW_SOURCES%"
        REM TODO enum files at runtime
        git am --signoff %ROOT%patches\0001-Using-protobuf-3.6.1-to-fix-vs-2017-debug-assertion.patch
        git am --signoff %ROOT%patches\0002-Fixed-grpc-Configuration-cmake-grpc-was-always-built.patch
    popd
)


REM cmake parameters

set CMAKE_CXX_FLAGS=
set CMAKE_LINKER_FLAGS=
set TENSORFLOW_ENABLE_MKL_FLAG="OFF"

if /I not x%VS_SOLUTION_DIR_NAME:avx-fma=%==x%VS_SOLUTION_DIR_NAME% (
    echo Arch avx2-fma is unsupported...
    exit /b 2
)

REM /O2 is automatically set by cmake
if /I %VS_SOLUTION_DIR_NAME%==Debug (
    set CMAKE_CONFIGURATION_TYPE=Debug
    set TENSORFLOW_WIN_CPU_SIMD_OPTION="/arch:AVX"
) else (
    set CMAKE_CONFIGURATION_TYPE=Release

    if /I not x%VS_SOLUTION_DIR_NAME:avx2=%==x%VS_SOLUTION_DIR_NAME% (
        set TENSORFLOW_WIN_CPU_SIMD_OPTION="/arch:AVX2"
        set CMAKE_CXX_FLAGS=-D__FMA__ -D__AVX2__

        REM explicit fma build for benchmarking with macro definitions for Eigen
        if /I not x%VS_SOLUTION_DIR_NAME:-fma=%==x%VS_SOLUTION_DIR_NAME% (
            set CMAKE_CXX_FLAGS=%CMAKE_CXX_FLAGS% -D__FMA__ -D__AVX2__
        )
    ) else (
        set TENSORFLOW_WIN_CPU_SIMD_OPTION="/arch:AVX"
        set CMAKE_CXX_FLAGS=-D__AVX__
    )

    REM explicit /fp:fast build for benchmarking (with macro definitions for Eigen)
    REM TODO rename to fast 
    REM TODO -> rebuild all tf archs on cuda-capable host
    REM TODO -> rename Visual Studio configurations
    REM TODO -> After benchmarking, integrate into avx, avx2 (avx+fast, avx2+fast+fma)
    if /I not x%VS_SOLUTION_DIR_NAME:-fma=%==x%VS_SOLUTION_DIR_NAME% (
        REM Yes, that's not exactly fma (only available Haswell+), but close
        set CMAKE_CXX_FLAGS=%CMAKE_CXX_FLAGS% /fp:fast
    )

    REM global optimization build for benchmarking (does not work yet)
    if /I not x%VS_SOLUTION_DIR_NAME:-gl=%==x%VS_SOLUTION_DIR_NAME% (
        echo "Warning: using option /GL exceeds COFF file size of 4G - build will fail"
        echo "Warning:  cmake doesn't set /LTCG for modules"
        echo "cmake doesn't set ""Whole Program Optimization"" in project general section either -> must be set manually
        set CMAKE_CXX_FLAGS=%CMAKE_CXX_FLAGS% /GL
        set CMAKE_LINKER_FLAGS=%CMAKE_LINKER_FLAGS% "/LTCG"
    )

    REM TODO cmake integration of mkl degrades r1.10 performance -> use bazel build + r.1.14
    if /I not x%VS_SOLUTION_DIR_NAME:-mkl=%==x%VS_SOLUTION_DIR_NAME% (
        set TENSORFLOW_ENABLE_MKL_FLAG=ON
        REM set CMAKE_CXX_FLAGS="-DINTEL_MKL -DEIGEN_USE_VML -DENABLE_MKL"
        REM set CMAKE_CXX_FLAGS="-DINTEL_MKL -DINTEL_MKL_ML -DEIGEN_USE_MKL_ALL -DMKL_DIRECT_CALL"
        set CMAKE_CXX_FLAGS=%CMAKE_CXX_FLAGS% -DEIGEN_USE_MKL_ALL
    )
)

if /I not x%VS_SOLUTION_DIR_NAME:cuda=%==x%VS_SOLUTION_DIR_NAME% (
    set TENSORFLOW_ENABLE_GPU_FLAG="ON"
) else (
    set TENSORFLOW_ENABLE_GPU_FLAG="OFF"
)

set TENSORFLOW_BUILD_CC_TESTS_FLAG="OFF"

set CMAKE_INSTALL_PREFIX=%CMAKE_DEV_PATH_LIB%\tensorflow\%TENSORFLOW_RELEASE%\%TENSORFLOW_VS_VERSION%\%VS_SOLUTION_DIR_NAME%
set CMAKE_TENSORFLOW_BUILD_PATH=%BUILD_CACHE%\%TENSORFLOW_VS_VERSION%\tensorflow\%TENSORFLOW_RELEASE%\%VS_SOLUTION_DIR_NAME%


REM Debug exit
REM exit /B 0


REM cmake project setup

pushd %TENSORFLOW_SOURCES%\tensorflow\contrib\cmake

cmake . -B%CMAKE_TENSORFLOW_BUILD_PATH% ^
-Ax64 ^
-G%CMAKE_GENERATOR% ^
-DCMAKE_CONFIGURATION_TYPES=%CMAKE_CONFIGURATION_TYPE% ^
-DCMAKE_CXX_FLAGS="%CMAKE_CXX_FLAGS%" ^
-DCMAKE_EXE_LINKER_FLAGS=%CMAKE_LINKER_FLAGS% ^
-DCMAKE_SHARED_LINKER_FLAGS=%CMAKE_LINKER_FLAGS% ^
-DCMAKE_MODULE_LINKER_FLAGS=%CMAKE_LINKER_FLAGS% ^
-Dtensorflow_BUILD_ALL_KERNELS=ON ^
-Dtensorflow_BUILD_CC_EXAMPLE=ON ^
-Dtensorflow_BUILD_CC_TESTS=%TENSORFLOW_BUILD_CC_TESTS_FLAG% ^
-Dtensorflow_BUILD_CONTRIB_KERNELS=ON ^
-Dtensorflow_BUILD_PYTHON_BINDINGS=OFF ^
-Dtensorflow_BUILD_SHARED_LIB=ON ^
-Dtensorflow_DISABLE_EIGEN_FORCEINLINE=OFF ^
-Dtensorflow_ENABLE_MKL_SUPPORT=%TENSORFLOW_ENABLE_MKL_FLAG% ^
-Dtensorflow_ENABLE_MKLDNN_SUPPORT=%TENSORFLOW_ENABLE_MKL_FLAG% ^
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

REM Install mkl from F:\Developer\lib\build\cache\tensorflow\r1.10\vc16\Release-mkl\mkl\bin
popd

if %errorlevel% neq 0 exit /b %errorlevel%

REM devenv %CMAKE_TENSORFLOW_BUILD_PATH%\Tensorflow.sln
REM exit /b 0


REM build tensorflow.dll and install lib & includes

MSBuild.exe "%CMAKE_TENSORFLOW_BUILD_PATH%\INSTALL.vcxproj" ^
/verbosity:minimal ^
/p:Configuration=%CMAKE_CONFIGURATION_TYPE% ^
/t:Build ^
/p:Platform=x64 ^
/p:PreferredToolArchitecture=x64 ^
/filelogger

if %errorlevel% neq 0 exit /b %errorlevel%


REM Post-processing

REM Consolidate include files
rmdir /Q /S %CMAKE_INSTALL_PREFIX%\..\..\include
if %errorlevel% neq 0 exit /b %errorlevel%
move %CMAKE_INSTALL_PREFIX%\include %CMAKE_INSTALL_PREFIX%\..\..\
if %errorlevel% neq 0 (
    echo "If you have an Explorer window open close it!"
    pause
    move %CMAKE_INSTALL_PREFIX%include %CMAKE_INSTALL_PREFIX%\..\..\
    if %errorlevel% neq 0 exit /b %errorlevel%
)
 
 exit /b 0
 
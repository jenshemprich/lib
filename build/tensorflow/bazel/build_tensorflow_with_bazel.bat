echo off
REM %1 = configuration

set PreferredToolArchitecture=x64

set ROOT=%~dp0
set BUILD_CACHE=%ROOT%cache
set BAZEL_SCRIPTS=%ROOT%scripts

call %BAZEL_SCRIPTS%\bazel_build_path.bat
call %BAZEL_SCRIPTS%\bazel_cuda_path.bat
call %BAZEL_SCRIPTS%\bazel_build_config.bat

if %errorlevel% neq 0 goto error

REM TODO remvoe test code
REM set TENSORFLOW_BAZEL=REM


if NOT [%1] == [] (
    set VS_CONFIGURATION_NAME=%1
)else (
    set VS_CONFIGURATION_NAME=Debug
)
if %errorlevel% neq 0 goto error

if [%VS_CONFIGURATION_NAME%] == [Debug] (
    set TENSORFLOW_SOURCE_FOLDER_NAME=tensorflow_%TENSORFLOW_RELEASE%
) else if [%VS_CONFIGURATION_NAME%] == [Release] (
    set TENSORFLOW_SOURCE_FOLDER_NAME=tensorflow_%TENSORFLOW_RELEASE%
) else (
    set TENSORFLOW_SOURCE_FOLDER_NAME=tensorflow_%TENSORFLOW_RELEASE%_%VS_CONFIGURATION_NAME%
)
if %errorlevel% neq 0 goto error

set TENSORFLOW_SOURCES=%BUILD_CACHE%\%TENSORFLOW_SOURCE_FOLDER_NAME%


if [%VS_CONFIGURATION_NAME%] == [Debug] (
    set BAZEL_TARGET_DIR=%TENSORFLOW_SOURCES%\bazel-out\x64_windows-fastbuild
) else (
    set BAZEL_TARGET_DIR=%TENSORFLOW_SOURCES%\bazel-out\x64_windows-opt
)
if %errorlevel% neq 0 goto error


if EXIST "%TENSORFLOW_SOURCES%\.git"  (
    pushd "%TENSORFLOW_SOURCES%"
        git pull
        if %errorlevel% neq 0 goto error
    popd
) else (
    git clone --single-branch --branch %TENSORFLOW_RELEASE% https://github.com/tensorflow/tensorflow.git "%TENSORFLOW_SOURCES%"
    if %errorlevel% neq 0 exit /b %errorlevel%
    pushd "%TENSORFLOW_SOURCES%"
        REM TODO enum files at runtime
        git am --signoff %ROOT%patches\0001-Fix-Visual-Studio-Debug-build-compile-errors.patch
        git am --signoff %ROOT%patches\0002-Fix-Visual-Studio-Debug-build-LNK2019-errors.patch
        REM TODO Auto-Config
        python configure.py
        if %errorlevel% neq 0 goto error
    popd

)


pushd "%TENSORFLOW_SOURCES%"

    REM TODO using --outputBase results in build eror : input file ""
    REM set OUTPUT_BASE=--output_base=%BUILD_CACHE%\bazel_build\%TENSORFLOW_VS_VERSION%\%TENSORFLOW_SOURCE_FOLDER_NAME%
    set OUTPUT_BASE=

    if [%VS_CONFIGURATION_NAME%] == [Debug] (
        REM Configure fastbuild to produce a debug executable without debug info -> works around the coff file size limit and can be used with debug version of stl

        REM Compile options for debug version
        set BUILD_CONFIGURATION_COMPILE_OPTIONS=-c fastbuild --define "_DEBUG=true" --define "_ITERATOR_DEBUG_LEVEL=2" --copt "/Od" --copt "/DEBUG:NONE"

        REM https://docs.microsoft.com/en-us/cpp/c-runtime-library/crt-library-features?view=vs-2019
        REM Link to runtime dlls: Dll import lib /MDd
        set BUILD_CONFIGURATION_LINK_OPTIONS=--copt "/MDd" --linkopt="/DEBUG:NONE"  --linkopt "/NODEFAULTLIB:msvcrtd.lib" --linkopt "/NODEFAULTLIB:ucrt.lib"  --linkopt "/NODEFAULTLIB:vcruntime.lib"  --linkopt "/DEFAULTLIB:msvcrtd.lib" --linkopt "/DEFAULTLIB:ucrtd.lib"  --linkopt "/DEFAULTLIB:vcruntimed.lib"

        set BUILD_CONFIGURATION_OPTIONS=%BUILD_CONFIGURATION_COMPILE_OPTIONS% %BUILD_CONFIGURATION_LINK_OPTIONS%
    ) else (
        set BUILD_CONFIGURATION_OPTIONS=-c opt --copt "/MD"
    )

    if [%VS_CONFIGURATION_NAME%] == [Debug] (
        set BUILD_ARCH_OPTIONS=--copt="/arch:AVX"
    ) else (
        set BUILD_ARCH_OPTIONS=--copt="/arch:AVX"
    )

      if /I not x%VS_CONFIGURATION_NAME:-gl=%==x%VS_CONFIGURATION_NAME% (
          REM TODO /LTCG not forwared correctly to linker:
          REM LINK : MSIL .netmodule or module compiled with /GL found; restarting link with /LTCG; add /LTCG to the link command line to improve linker performance
          REM TODO fails with cwise_op.lo.lib : fatal error LNK1107: invalid or corrupt file: cannot read at 0x1495A2BB
          set BUILD_CONFIGURATION_OPTIONS=%BUILD_CONFIGURATION_OPTIONS% --copt="/GL" --linkopt="/LTCG"
      )
 
    REM TODO Eigen_Strong_Inline from configure sript (default is disabled)
    REM TODO AVX2, CUDA

    set BUILD_TARGETS=//tensorflow:libtensorflow_framework.so //tensorflow:libtensorflow.so //tensorflow:libtensorflow_cc.so
    REM set BUILD_TARGETS=//tensorflow:libtensorflow_cc.so


    %TENSORFLOW_BAZEL% %OUTPUT_BASE% build %BUILD_CONFIGURATION_OPTIONS% %BUILD_ARCH_OPTIONS% %BUILD_TARGETS%
    %TENSORFLOW_BAZEL% %OUTPUT_BASE% shutdown
    if %errorlevel% neq 0 goto error

    set INSTALL_DIR=%DEV_PATH_LIB%\tensorflow\%TENSORFLOW_RELEASE%


    echo Installing headers...
    set INSTALL_INCLUDE_DIR=%INSTALL_DIR%\include
    if EXIST %INSTALL_INCLUDE_DIR% (
        rmdir /S /Q %INSTALL_INCLUDE_DIR%
    )
    mkdir %INSTALL_INCLUDE_DIR%
    if %errorlevel% neq 0 goto error
    
    set INSTALL=xcopy /Y /S /Q

    echo TensorFlow...
    REM TODO Too much is copied, for instance C interface and probably a lot of internal stuff -> reduce or split up
    %INSTALL% %TENSORFLOW_SOURCES%\tensorflow\*.h %INSTALL_INCLUDE_DIR%\tensorflow\

    REM Merge protobuf generated files next-to their source - since r1.14 %BAZEL_TARGET_DIR%\genfiles is gone, so we must pick up these files here
    %INSTALL% %BAZEL_TARGET_DIR%\bin\tensorflow\*.h %INSTALL_INCLUDE_DIR%\tensorflow\
    if %errorlevel% neq 0 goto error
    %INSTALL% %BAZEL_TARGET_DIR%\bin\tensorflow\*.cc %INSTALL_INCLUDE_DIR%\tensorflow\
    if %errorlevel% neq 0 goto error

    echo Absl...
    set INCLUDE_EXTERNAL_DIR=%TENSORFLOW_SOURCES%\bazel-%TENSORFLOW_SOURCE_FOLDER_NAME%\external
    %INSTALL% %INCLUDE_EXTERNAL_DIR%\com_google_absl\absl\*.h %INSTALL_INCLUDE_DIR%\absl\
    if %errorlevel% neq 0 goto error
    %INSTALL% %INCLUDE_EXTERNAL_DIR%\com_google_absl\absl\*.inc %INSTALL_INCLUDE_DIR%\absl\
    if %errorlevel% neq 0 goto error

    echo Protobuf...
    %INSTALL% %INCLUDE_EXTERNAL_DIR%\protobuf_archive\src\google\*.h %INSTALL_INCLUDE_DIR%\google\
    if %errorlevel% neq 0 goto error
    %INSTALL% %INCLUDE_EXTERNAL_DIR%\protobuf_archive\src\google\*.inc %INSTALL_INCLUDE_DIR%\google\
    if %errorlevel% neq 0 goto error

    REM Eigen & Unsupported
    echo Eigen...
    %INSTALL% %INCLUDE_EXTERNAL_DIR%\eigen_archive\* %INSTALL_INCLUDE_DIR%\eigen_archive\
    if %errorlevel% neq 0 goto error

    REM referenced by some tensorflow headers
    REM TODO remove copy: also available via eigen_archive\unsupported\
    REM TODO check versions of eigen_archive\ via third_party\eigen3\
    %INSTALL% %TENSORFLOW_SOURCES%\third_party\eigen3\* %INSTALL_INCLUDE_DIR%\third_party\eigen3\
    if %errorlevel% neq 0 goto error


    echo Installing binaries...
    set INSTALL_BIN_DIR=%INSTALL_DIR%\%TENSORFLOW_VS_VERSION%\%VS_CONFIGURATION_NAME%\bin
    if EXIST %INSTALL_BIN_DIR% (
       rmdir /S /Q %INSTALL_BIN_DIR%\
    )
    mkdir %INSTALL_BIN_DIR%\
    if %errorlevel% neq 0 goto error

    REM TODO cpu & gpu arch in lib name
    set LIB_TENSORFLOW_FRAMEWORK_NAME=tensorflow_framework
    set LIB_TENSORFLOW_C_NAME=tensorflow_c
    set LIB_TENSORFLOW_CC_NAME=tensorflow


    copy %BAZEL_TARGET_DIR%\bin\tensorflow\libtensorflow_framework.so.%TENSORFLOW_VERSION%.1 %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_FRAMEWORK_NAME%.dll
    if [%VS_CONFIGURATION_NAME%] == [Debug] (
        copy %BAZEL_TARGET_DIR%\bin\tensorflow\libtensorflow_framework.so.%TENSORFLOW_VERSION%.pdb %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_FRAMEWORK_NAME%.pdb
        if %errorlevel% neq 0 goto error
    )

    copy %BAZEL_TARGET_DIR%\bin\tensorflow\libtensorflow.so.%TENSORFLOW_VERSION%.1 %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_C_NAME%.dll
    if [%VS_CONFIGURATION_NAME%] == [Debug] (
        copy %BAZEL_TARGET_DIR%\bin\tensorflow\libtensorflow.so.%TENSORFLOW_VERSION%.pdb %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_C_NAME%.pdb
        if %errorlevel% neq 0 goto error
    )

    copy %BAZEL_TARGET_DIR%\bin\tensorflow\libtensorflow_cc.so.%TENSORFLOW_VERSION%.1 %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_CC_NAME%.dll
    if [%VS_CONFIGURATION_NAME%] == [Debug] (
        copy %BAZEL_TARGET_DIR%\bin\tensorflow\libtensorflow_cc.so.%TENSORFLOW_VERSION%.pdb %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_CC_NAME%.pdb
        if %errorlevel% neq 0 goto error
    )


    echo Installing libs...
    set INSTALL_LIB_DIR=%INSTALL_DIR%\%TENSORFLOW_VS_VERSION%\%VS_CONFIGURATION_NAME%\lib
    if EXIST %INSTALL_LIB_DIR% (
       rmdir /S /Q %INSTALL_LIB_DIR%\
    )
    mkdir %INSTALL_LIB_DIR%\
    if %errorlevel% neq 0 goto error

    REM TODO create lib from tensorflow_filtered_def_file.def & tf_custom_op_library_additional_deps.dll.gen.def

    REM Build with https://github.com/tensorflow/tensorflow/issues/22047, then skip and use libtensorflow.so.if.lib
    REM Better solution here: https://github.com/guikarist/tensorflow-windows-build-script

    call %BAZEL_SCRIPTS%\create_lib.bat %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_FRAMEWORK_NAME% %INSTALL_LIB_DIR%\%LIB_TENSORFLOW_FRAMEWORK_NAME%
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_lib.bat %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_C_NAME% %INSTALL_LIB_DIR%\%LIB_TENSORFLOW_C_NAME%
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_lib.bat %INSTALL_BIN_DIR%\%LIB_TENSORFLOW_CC_NAME% %INSTALL_LIB_DIR%\%LIB_TENSORFLOW_CC_NAME%
    if %errorlevel% neq 0 goto error

    echo Installing Pragma incs...
    mkdir %INSTALL_INCLUDE_DIR%\lib
    call %BAZEL_SCRIPTS%\create_static_libs_import_src.cmd %BAZEL_TARGET_DIR%\bin\external\ %INSTALL_INCLUDE_DIR%\lib\external.inc
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_static_libs_import_src.cmd %BAZEL_TARGET_DIR%\bin\tensorflow\c %INSTALL_INCLUDE_DIR%\lib\c.inc
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_static_libs_import_src.cmd %BAZEL_TARGET_DIR%\bin\tensorflow\cc %INSTALL_INCLUDE_DIR%\lib\cc.inc
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_static_libs_import_src.cmd %BAZEL_TARGET_DIR%\bin\tensorflow\core %INSTALL_INCLUDE_DIR%\lib\core.inc
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_static_libs_import_src.cmd %BAZEL_TARGET_DIR%\bin\tensorflow\contrib %INSTALL_INCLUDE_DIR%\lib\contrib.inc
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_static_libs_import_src.cmd %BAZEL_TARGET_DIR%\bin\tensorflow\stream_executor %INSTALL_INCLUDE_DIR%\lib\stream_executor.inc
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_static_libs_import_src.cmd %BAZEL_TARGET_DIR%\bin\tensorflow\tools %INSTALL_INCLUDE_DIR%\lib\tools.inc
    if %errorlevel% neq 0 goto error
    call %BAZEL_SCRIPTS%\create_static_libs_import_src.cmd %BAZEL_TARGET_DIR%\bin\third_party\ %INSTALL_INCLUDE_DIR%\lib\third_party.inc
    if %errorlevel% neq 0 goto error

:error
    %TENSORFLOW_BAZEL% %OUTPUT_BASE% shutdown
    set BAZEL_VS=
    set BAZEL_VC=
popd

if %errorlevel% neq 0 exit /b %errorlevel%
echo Done.
exit /b 0

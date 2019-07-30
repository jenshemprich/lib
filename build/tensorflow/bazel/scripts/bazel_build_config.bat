set PreferredToolArchitecture=x64

set TENSORFLOW_VERSION=1.14
set TENSORFLOW_RELEASE=r%TENSORFLOW_VERSION%
set TENSORFLOW_BAZEL=bazel
REM set BAZEL_VS=C:\Program Files (x86)\Microsoft Visual Studio 14.0\
set BAZEL_VS=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional
REM Since 14.0, crt is binary runtime-compatible, so the version can be any -> set to 16 to match vs 2019
REM TODO Remove from cmake&bazel scripts once bazel can produce a proper Windows dll
set TENSORFLOW_VS_VERSION=vc16

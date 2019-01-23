# Deep learning libs

Contains ms build targets and build scripts for the libraries I use. Projects simply need to include the Visual Studio Build customisation file `Deep Learning and Computer Vision libraries.targets` to reference those libraries from Visual Studio projects.

## Preparing libraries
Including the build customization into a project, automaticlly enables access to the supported libriries. THese are currently:

1. OpenCV: Platform toolset is automatically selected
2. Tensorflow: To be build manually (see below). Selection of platform toolset and build configuration.

### OpenCV
Download OpenCV 4.0.1 into the lib directory and rename the folder to "OpenCV 4.0.1".


### Building Tensorflow 1.10 with cmake and Visual Studio 2017

Install Visual Studio 2017 Community Edition, Python 3.66, Git, Cuda 10

Enable long filename for Git, otherwise you'll might not get very far.

Currently, only TensorFlow r1.10 is supported, for a couple of reasons.

1. It is the last version that that officially supports CUDA Compute Caps 3.5, and therefore runs with my slightly outdated 2013 GPU (NVidia Titan).
2. The cmake build succeed works with Cuda 10
3. Only 2 patches were necessary to build with Visual Studio 2017.

Open a Visual Studio 2017 x654 command prompt and execute the build script `build_tensorflow_r1.10-cmake-all.bat`.

The script downloads my fork of TF, selects the r1.10 branch, and builds Tensforflow for CPU/GPU. The build should take about half a day or so and leave you with a couple of TensorFlow dlls in `lib\tensorflow\r1.10\vc15` for Debug and avx, avx2, cuda, cuda-avx & avx2-fma configurations.

You can build a single configuration with `build_tensorflow_with_cmake.bat "VS Configuration"`, for instance
```
build_tensorflow_with_cmake.bat Debug
```

The special fma build will be replaced by the avx2 build later on, but I'm interested in the performance gain - we'll see about that later.
 
There's no /GL build yet because it exceeds the 4G size limit of the COFF file format.

Include files are duplicated in each configuration, that's because each cpu/gpu variant is built by a single cmake solution.

To reference the library from a project, simply add the Build Customization file `build_tensorflow_with_cmake.bat`. It sets up all include and library paths, selects the library version that corresponds to the project's platform toolset.

The cpu/gpu arch is simply matched via the configuration name, so the project references Debug/Release (both built with AVX) automatically. To match additional build-config library, just name them after the folder that contains the specific version of Tensorflow. (For instance `Release-cuda-avx2`)


### Running the test project "Hello Tensorflow"
A hello-world example derived from https://joe-antognini.github.io/machine-learning/windows-tf-project, plus a Google test suite to assert that the library works.

If you build and run the Hello-Word example, the console should display the expected result
```
 7 17
-1 -3
```

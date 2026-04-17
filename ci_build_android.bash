#!/bin/bash
set -e
export LIBFFI_VERSION=3.4.6
export ANDROID=1
#export LWJGL_BUILD_ARCH=arm64

# Setup env
if   [ "$LWJGL_BUILD_ARCH" == "arm64" ]; then
  export NDK_ABI=arm64-v8a NDK_TARGET=aarch64
elif [ "$LWJGL_BUILD_ARCH" == "arm32" ]; then
  export NDK_ABI=armeabi-v7a NDK_TARGET=armv7a NDK_SUFFIX=eabi
elif [ "$LWJGL_BUILD_ARCH" == "x86" ]; then
  export NDK_ABI=x86 NDK_TARGET=i686
  # Workaround: LWJGL 3 lacks of x86 Linux libraries
  mkdir -p bin/libs/native/linux/x86/org/lwjgl/{freetype,glfw,jemalloc}
  touch bin/libs/native/linux/x86/org/lwjgl/{freetype/libfreetype.so,glfw/libglfw.so,jemalloc/libjemalloc.so}
elif [ "$LWJGL_BUILD_ARCH" == "x64" ]; then
  export NDK_ABI=x86_64 NDK_TARGET=x86_64
fi

export TARGET=$NDK_TARGET-linux-android$NDK_SUFFIX
export PATH=$PATH:$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin

LWJGL_NATIVE=bin/libs/native/linux/$LWJGL_BUILD_ARCH/org/lwjgl
mkdir -p $LWJGL_NATIVE

if [ "$SKIP_LIBFFI" != "1" ]; then
  # Get libffi
  if [ ! -d libffi ]; then
    wget https://github.com/libffi/libffi/releases/download/v$LIBFFI_VERSION/libffi-$LIBFFI_VERSION.tar.gz
    tar xvf libffi-$LIBFFI_VERSION.tar.gz
    mv libffi-$LIBFFI_VERSION libffi
  fi
  cd libffi

  # Build libffi
  bash configure --host=$TARGET --prefix=$PWD/$NDK_TARGET-unknown-linux-android$NDK_SUFFIX CC=${TARGET}21-clang CXX=${TARGET}21-clang++
  make -j4
  cd ..

  # Copy libffi
  cp libffi/$NDK_TARGET-linux-android$NDK_SUFFIX/.libs/libffi.a $LWJGL_NATIVE/
fi

if [ "$SKIP_FREETYPE" != "1" ]; then
  #!/bin/bash
  export BUILD_FREETYPE_VERSION=2.13.2
  wget https://downloads.sourceforge.net/project/freetype/freetype2/$BUILD_FREETYPE_VERSION/freetype-$BUILD_FREETYPE_VERSION.tar.gz
  tar xf freetype-$BUILD_FREETYPE_VERSION.tar.gz
  rm  freetype-$BUILD_FREETYPE_VERSION.tar.gz
  cd freetype-$BUILD_FREETYPE_VERSION

  export CC=$NDK_TARGET-linux-android${NDK_SUFFIX}21-clang

  ./configure \
    --host=$TARGET \
    --prefix=`pwd`/build_android-$LWJGL_BUILD_ARCH \
    --without-zlib \
    --with-brotli=no \
    --with-bzip2=no \
    --with-png=no \
    --with-harfbuzz=no \
    --enable-static=no \
    --enable-shared=yes 

  make -j4
  make install
  llvm-strip ./build_android-$LWJGL_BUILD_ARCH/lib/libfreetype.so
  
  cd ..
  cp   freetype-$BUILD_FREETYPE_VERSION/build_android-$LWJGL_BUILD_ARCH/lib/libfreetype.so $LWJGL_NATIVE/
  rm -rf freetype-$BUILD_FREETYPE_VERSION
  unset BUILD_FREETYPE_VERSION
  unset CC
fi

# Download libraries
POJAV_NATIVES="https://github.com/AngelAuraMC/Amethyst-Android/raw/34fe895c4d6117b50dd19a69819cd5430de6fc06/app_pojavlauncher/src/main/jniLibs/$NDK_ABI"
wget -nc $POJAV_NATIVES/libopenal.so -P $LWJGL_NATIVE/openal
wget -nc "https://github.com/AngelAuraMC/shaderc/releases/latest/download/libshaderc-$NDK_ABI.zip"
unzip -o libshaderc-$NDK_ABI.zip -d $LWJGL_NATIVE/shaderc

# HACK: Skip compiling and running the generator to save time and keep LWJGLX functions
mkdir -p bin/classes/{generator,templates/META-INF}
touch bin/classes/{generator,templates}/touch.txt bin/classes/generator/generated-touch.txt

# Build LWJGL 3
ant -version
yes | ant init # Needed to download deps like kotlinc. We can't have this run offline, else jsr305 annotations fails to download and we get errors about annotations gone missing
export LWJGL_BUILD_OFFLINE=true
yes | ant -Dplatform.linux=true \
  -Dbinding.assimp=false \
  -Dbinding.bgfx=false \
  -Dbinding.cuda=false \
  -Dbinding.egl=false \
  -Dbinding.fmod=false \
  -Dbinding.harfbuzz=false \
  -Dbinding.hwloc=false \
  -Dbinding.jawt=false \
  -Dbinding.jemalloc=false \
  -Dbinding.ktx=false \
  -Dbinding.libdivide=false \
  -Dbinding.llvm=false \
  -Dbinding.lmdb=false \
  -Dbinding.lz4=false \
  -Dbinding.meow=false \
  -Dbinding.meshoptimizer=false \
  -Dbinding.nfd=false \
  -Dbinding.nuklear=false \
  -Dbinding.odbc=false \
  -Dbinding.opengles=false \
  -Dbinding.opencl=false \
  -Dbinding.openvr=false \
  -Dbinding.openxr=false \
  -Dbinding.opus=false \
  -Dbinding.par=false \
  -Dbinding.remotery=false \
  -Dbinding.rpmalloc=false \
  -Dbinding.sse=false \
  -Dbinding.tinyexr=false \
  -Dbinding.tootle=false \
  -Dbinding.xxhash=false \
  -Dbinding.yoga=false \
  -Dbinding.zstd=false \
  -Dbinding.shaderc=true \
  -Dbinding.vulkan=true \
  -Dbinding.vma=true \
  -Dbinding.spvc=true \
  -Dbuild.type=release/3.3.3 \
  -Djavadoc.skip=true \
  -Dnashorn.args="--no-deprecation-warning" \
  compile compile-native release

# Copy native libraries
rm -rf bin/out; mkdir bin/out
find $LWJGL_NATIVE -name 'liblwjgl*.so' -exec cp {} bin/out/ \;
cp $LWJGL_NATIVE/shaderc/libshaderc.so bin/out/
if [ -e "$LWJGL_NATIVE/libfreetype.so" ]; then
  cp $LWJGL_NATIVE/libfreetype.so bin/out/
fi

# Cleanup unused output jar files
find bin/RELEASE \( -name '*-natives-*' -o -name '*-sources.jar' \) -delete

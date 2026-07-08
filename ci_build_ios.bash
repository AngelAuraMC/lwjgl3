#!/bin/bash
set -e
export LIBFFI_VERSION=3.4.6
export LWJGL_BUILD_OFFLINE=1
export LWJGL_BUILD_ARCH=arm64

LWJGL_NATIVE=bin/libs/native/macos/$LWJGL_BUILD_ARCH/org/lwjgl
mkdir -p $LWJGL_NATIVE

if [ "$SKIP_LIBFFI" != "1" ]; then
  # Get libffi
  if [ ! -d libffi ]; then
    wget https://github.com/libffi/libffi/releases/download/v$LIBFFI_VERSION/libffi-$LIBFFI_VERSION.tar.gz
    tar xvf libffi-$LIBFFI_VERSION.tar.gz
    mv libffi-$LIBFFI_VERSION libffi
  fi
  cd libffi

  # Patch generator to produce iOS arm64 only
  sed -i'.bak' \
      -e '/\(64_platform\)/! s/build_target(ios_/#build_target(ios_/g' \
      generate-darwin-source-and-headers.py

  # Generate configure file
  python3 generate-darwin-source-and-headers.py --only-ios

  # Restore generator
  mv generate-darwin-source-and-headers.py.bak generate-darwin-source-and-headers.py

  # Build libffi
  xcodebuild -arch arm64 -sdk iphoneos -target libffi-iOS || echo "Exit code: $?"

  # Copy libffi
  cd ..
  cp libffi/build/Release-iphoneos/libffi.a $LWJGL_NATIVE/
fi

# Download libraries
#POJAV_NATIVES="https://github.com/PojavLauncherTeam/PojavLauncher_iOS/raw/main/Natives/resources/Frameworks"
#wget -nc $POJAV_NATIVES/libopenal.so -P $LWJGL_NATIVE/openal
wget -nc "https://github.com/AngelAuraMC/shaderc/releases/latest/download/libshaderc-ios.zip"
unzip -o libshaderc-ios.zip -d $LWJGL_NATIVE/shaderc
rm $LWJGL_NATIVE/shaderc/libshaderc_shared.1.dylib
mv $LWJGL_NATIVE/shaderc/libshaderc_shared.dylib $LWJGL_NATIVE/shaderc/libshaderc.dylib

# HACK: Skip compiling and running the generator to save time and keep LWJGLX functions
mkdir -p bin/classes/{generator,templates/META-INF}
touch bin/classes/{generator,templates}/touch.txt bin/classes/generator/generated-touch.txt

# Build LWJGL 3
ant -version
yes | ant -Dplatform.macos=true \
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
  -Dbinding.spvc=false \
  -Dbinding.sse=false \
  -Dbinding.tinyexr=false \
  -Dbinding.tootle=false \
  -Dbinding.xxhash=false \
  -Dbinding.yoga=false \
  -Dbinding.zstd=false \
  -Dbuild.type=release/3.3.3 \
  -Djavadoc.skip=true \
  -Dnashorn.args="--no-deprecation-warning" \
  compile compile-native release

# Copy native libraries
rm -rf bin/out; mkdir bin/out
find $LWJGL_NATIVE -name 'liblwjgl*.dylib' -exec cp {} bin/out/ \;
cp $LWJGL_NATIVE/shaderc/libshaderc.dylib bin/out/
vtool -arch arm64 -set-build-version 2 14.0 16.0 -replace -output bin/out/libfreetype.dylib $LWJGL_NATIVE/freetype/libfreetype.dylib
install_name_tool \
  -change /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation /System/Library/Frameworks/CoreFoundation.framework/CoreFoundation \
  -change /System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics /System/Library/Frameworks/CoreGraphics.framework/CoreGraphics \
  -change /System/Library/Frameworks/CoreText.framework/Versions/A/CoreText /System/Library/Frameworks/CoreText.framework/CoreText \
  bin/out/libfreetype.dylib

# Cleanup unused output jar files
find bin/RELEASE \( -name '*-natives-*' -o -name '*-sources.jar' \) -delete

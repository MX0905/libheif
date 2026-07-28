#!/bin/bash
# build_deps_android_arm64.sh
# 目标: Android arm64, API 24, NDK r27c, 全静态, 汇编优化全开

set -e

# ====== 基本配置 ======
API=24
ABI=arm64-v8a
PREFIX="$(pwd)/arm64-prefix"
JOBS=$(nproc)

NDK_ROOT="${NDK_ROOT:-/d/a/_temp/ndk/android-ndk-r27c}"
TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/windows-x86_64"
SYSROOT="$TOOLCHAIN/sysroot"

# NDK 交叉编译工具
CC="$TOOLCHAIN/bin/aarch64-linux-android$API-clang"
CXX="$TOOLCHAIN/bin/aarch64-linux-android$API-clang++"
AR="$TOOLCHAIN/bin/llvm-ar"
RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
NM="$TOOLCHAIN/bin/llvm-nm"
STRIP="$TOOLCHAIN/bin/llvm-strip"
LD="$TOOLCHAIN/bin/ld.lld"

# 公共 CFLAGS / LDFLAGS（静态、优化、NEON）
export CFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -O3 -fPIC -DANDROID -DNDEBUG"
export CXXFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -O3 -fPIC -DANDROID -DNDEBUG"
export LDFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -static -L$SYSROOT/usr/lib/$ABI"
export AR RANLIB NM STRIP LD

# cmake 工具链文件（用 NDK 自带）
CMAKE_TOOLCHAIN="$NDK_ROOT/build/cmake/android.toolchain.cmake"

# 创建安装目录
mkdir -p "$PREFIX"/{include,lib}

# 源码统一放这里
SRC_DIR="$(pwd)/deps-src"
mkdir -p "$SRC_DIR"

# 克隆助手：已存在则拉最新
clone() {
  local repo="$1" dir="$2"
  if [ -d "$SRC_DIR/$dir" ]; then
    git -C "$SRC_DIR/$dir" pull --ff-only || true
  else
    git clone --depth 1 "$repo" "$SRC_DIR/$dir"
  fi
}

# ====== 1. zlib ======
echo "===== Building zlib ====="
clone "https://github.com/madler/zlib.git" zlib
rm -rf "$SRC_DIR/zlib/build"
mkdir -p "$SRC_DIR/zlib/build" && cd "$SRC_DIR/zlib/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DZLIB_BUILD_TESTING=OFF
make -j"$JOBS" && make install
cd -

# ====== 2. libjpeg-turbo ======
echo "===== Building libjpeg-turbo ====="
clone "https://github.com/libjpeg-turbo/libjpeg-turbo.git" libjpeg-turbo
rm -rf "$SRC_DIR/libjpeg-turbo/build"
mkdir -p "$SRC_DIR/libjpeg-turbo/build" && cd "$SRC_DIR/libjpeg-turbo/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
  -DWITH_SIMD=ON
make -j"$JOBS" && make install
cd -

# ====== 3. libpng ======
echo "===== Building libpng ====="
clone "https://github.com/glennrp/libpng.git" libpng
rm -rf "$SRC_DIR/libpng/build"
mkdir -p "$SRC_DIR/libpng/build" && cd "$SRC_DIR/libpng/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DPNG_SHARED=OFF -DPNG_STATIC=ON \
  -DZLIB_INCLUDE_DIR="$PREFIX/include" \
  -DZLIB_LIBRARY="$PREFIX/lib/libz.a"
make -j"$JOBS" && make install
cd -

# ====== 4. libtiff ======
echo "===== Building libtiff ====="
clone "https://gitlab.com/libtiff/libtiff.git" libtiff
rm -rf "$SRC_DIR/libtiff-build"
mkdir -p "$SRC_DIR/libtiff-build" && cd "$SRC_DIR/libtiff-build"
cmake "$SRC_DIR/libtiff" \
  -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -Djpeg=ON -Djbig=OFF -Dlerc=OFF -Dzstd=OFF -Dwebp=OFF \
  -Dopengl=OFF -Dglut=OFF -DGLUT=OFF \
  -DOpenGL=OFF -DGL=OFF -DGLUT=OFF \
  -DBUILD_TESTING=OFF -DBUILD_DOCS=OFF -DBUILD_CONTRIB=OFF \
  -DZLIB_INCLUDE_DIR="$PREFIX/include" \
  -DZLIB_LIBRARY="$PREFIX/lib/libz.a" \
  -DJPEG_INCLUDE_DIR="$PREFIX/include" \
  -DJPEG_LIBRARY="$PREFIX/lib/libjpeg.a"
make -j"$JOBS" && make install
cd -

# ====== 5. libwebp ======
echo "===== Building libwebp ====="
clone "https://chromium.googlesource.com/webm/libwebp" libwebp
rm -rf "$SRC_DIR/libwebp/build"
mkdir -p "$SRC_DIR/libwebp/build" && cd "$SRC_DIR/libwebp/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF \
  -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF \
  -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_LIBWEBPMUX=OFF \
  -DWEBP_BUILD_WEBPMUX=OFF \
  -DWEBP_ENABLE_SIMD=ON \
  -DWEBP_USE_THREAD=ON
make -j"$JOBS" && make install
cd -

# ====== 6. brotli ======
echo "===== Building brotli ====="
clone "https://github.com/google/brotli.git" brotli
rm -rf "$SRC_DIR/brotli/build"
mkdir -p "$SRC_DIR/brotli/build" && cd "$SRC_DIR/brotli/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF
make -j"$JOBS" && make install
cd -

# ====== 7. xz (lzma) ======
echo "===== Building xz (lzma) ====="
clone "https://github.com/tukaani-project/xz.git" xz
rm -rf "$SRC_DIR/xz/build"
mkdir -p "$SRC_DIR/xz/build" && cd "$SRC_DIR/xz/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF -DBUILD_DOCS=OFF
make -j"$JOBS" && make install
cd -

# ====== 8. zstd ======
echo "===== Building zstd ====="
clone "https://github.com/facebook/zstd.git" zstd
cd "$SRC_DIR/zstd"/lib
make -j"$JOBS" \
  CC="$CC" AR="$AR" CFLAGS="-O3 -fPIC" \
  libzstd.a
cp libzstd.a "$PREFIX/lib/"
cp zstd.h "$PREFIX/include/"
mkdir -p "$PREFIX/include/zstd" && cp common/zstd_internal.h "$PREFIX/include/zstd/" 2>/dev/null || true
cd -

# ====== 9. libde265 ======
echo "===== Building libde265 ====="
clone "https://github.com/strukturag/libde265.git" libde265
rm -rf "$SRC_DIR/libde265/build"
mkdir -p "$SRC_DIR/libde265/build" && cd "$SRC_DIR/libde265/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_SDL=OFF -DENABLE_DECODER=ON -DENABLE_ENCODER=ON \
  -DENABLE_ASSEMBLY=ON -DENABLE_LOG_ERROR=ON -DENABLE_LOG_INFO=OFF
make -j"$JOBS" && make install
cd -

# ====== 10. x265 ======
# ====== x265 ======
echo "===== Building x265 ====="
clone "https://bitbucket.org/multicoreware/x265_git.git" x265
rm -rf "$SRC_DIR/x265/build-arm64"
mkdir -p "$SRC_DIR/x265/build-arm64" && cd "$SRC_DIR/x265/build-arm64"
cmake "$SRC_DIR/x265/source" \
  -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" \
  -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF \
  -DENABLE_CLI=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_ASSEMBLY=OFF
make -j"$JOBS" && make install
cd -

# ====== 11. x264 ======
# ====== x264 ======
echo "===== Building x264 ====="
clone "https://code.videolan.org/videolan/x264.git" x264
cd "$SRC_DIR/x264"
make distclean 2>/dev/null || true

env \
  CC="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android24-clang" \
  CXX="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android24-clang++" \
  AR="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-ar" \
  STRIP="$NDK/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip" \
  ./configure \
    --host=aarch64-linux-android \
    --disable-cli \
    --enable-static \
    --disable-shared \
    --prefix="$PREFIX" \
    --sysroot="$NDK/toolchains/llvm/prebuilt/windows-x86_64/sysroot"

make -j"$JOBS"
make install
cd -

# ====== 12. openh264 ======
echo "===== Building openh264 ====="
clone "https://github.com/cisco/openh264.git" openh264
cd "$SRC_DIR/openh264"
make -j"$JOBS" \
  OS=android \
  ARCH=arm64 \
  CC="$CC" CXX="$CXX" AR="$AR" \
  PREFIX="$PREFIX" \
  ENABLE_STATIC=Yes \
  install-static
cd -

# ====== 13. aom (AV1) ======
echo "===== Building aom ====="
clone "https://aomedia.googlesource.com/aom" aom
rm -rf "$SRC_DIR/aom/build"
mkdir -p "$SRC_DIR/aom/build" && cd "$SRC_DIR/aom/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_EXAMPLES=0 -DENABLE_TESTS=0 -DENABLE_DOCS=0 -DENABLE_TOOLS=0 \
  -DENABLE_NASM=0 -DENABLE_NEON=1 \
  -DAOM_TARGET_CPU=arm64 \
  -DCONFIG_AV1_ENCODER=1 -DCONFIG_AV1_DECODER=1
make -j"$JOBS" && make install
cd -

# ====== 14. vvenc ======
echo "===== Building vvenc ====="
clone "https://github.com/fraunhoferhhi/vvenc.git" vvenc
rm -rf "$SRC_DIR/vvenc/build"
mkdir -p "$SRC_DIR/vvenc/build" && cd "$SRC_DIR/vvenc/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DVVENC_ENABLE_THIRDPARTY_LIBS=OFF -DBUILD_APPS=OFF
make -j"$JOBS" && make install
cd -

# ====== 15. vvdec ======
echo "===== Building vvdec ====="
clone "https://github.com/fraunhoferhhi/vvdec.git" vvdec
rm -rf "$SRC_DIR/vvdec/build"
mkdir -p "$SRC_DIR/vvdec/build" && cd "$SRC_DIR/vvdec/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_APPS=OFF
make -j"$JOBS" && make install
cd -

# ====== 16. OpenJPEG ======
echo "===== Building OpenJPEG ====="
clone "https://github.com/uclouvain/openjpeg.git" openjpeg
rm -rf "$SRC_DIR/openjpeg/build"
mkdir -p "$SRC_DIR/openjpeg/build" && cd "$SRC_DIR/openjpeg/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF -DBUILD_DOC=OFF
make -j"$JOBS" && make install
cd -

# ====== 17. OpenJPH ======
echo "===== Building OpenJPH ====="
clone "https://github.com/aous72/OpenJPH.git" openjph
rm -rf "$SRC_DIR/openjph/build"
mkdir -p "$SRC_DIR/openjph/build" && cd "$SRC_DIR/openjph/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DOJPH_BUILD_EXECUTABLES=OFF -DOJPH_DISABLE_INTEL_SIMD=OFF
make -j"$JOBS" && make install
cd -

echo "===== ALL DEPS INSTALLED TO $PREFIX ====="
ls -la "$PREFIX/lib"

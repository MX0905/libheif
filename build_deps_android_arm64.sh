#!/bin/bash
# build_deps_android_arm64.sh
# 在 GitHub Actions Windows runner (MSYS2/bash) 下运行
# 目标: Android arm64, API 24, NDK r27c, 全静态, 汇编/NEON 优化全开
# 全部依赖从官方仓库拉取并编译到 /data/local/arm64

set -e
set -o pipefail

# ====== 基本配置 ======
API=24
ABI=arm64-v8a
PREFIX=/data/local/arm64
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

# 公共编译 flags（静态、优化、NEON）
export CFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -O3 -fPIC -DANDROID -DNDEBUG"
export CXXFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -O3 -fPIC -DANDROID -DNDEBUG -fexceptions -frtti"
export LDFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -static -L$SYSROOT/usr/lib/$ABI -L$PREFIX/lib"
export AR RANLIB NM STRIP LD

# cmake 工具链文件（NDK 自带）
CMAKE_TOOLCHAIN="$NDK_ROOT/build/cmake/android.toolchain.cmake"

# 安装目录
mkdir -p "$PREFIX"/{include,lib}

# 源码目录
SRC_DIR="$(pwd)/deps-src"
mkdir -p "$SRC_DIR"

# ---------- 工具函数 ----------
clone() {
  local repo="$1" dir="$2"
  if [ -d "$SRC_DIR/$dir/.git" ]; then
    git -C "$SRC_DIR/$dir" fetch --depth 1 origin || true
    git -C "$SRC_DIR/$dir" reset --hard origin/HEAD 2>/dev/null || true
  else
    git clone --depth 1 "$repo" "$SRC_DIR/$dir"
  fi
}

log() { echo -e "\n\033[1;34m===== $* =====\033[0m"; }

# 确保 MSYS2 有 autotools（xz 用）
if ! command -v autoreconf >/dev/null 2>&1; then
  pacman -S --noconfirm autoconf automake libtool 2>/dev/null || true
fi

# ===================================================================
log "1/16 zlib"
# ===================================================================
clone "https://github.com/madler/zlib.git" zlib
cd "$SRC_DIR/zlib"
./configure --prefix="$PREFIX" --static
make -j"$JOBS"
make install
cd -

# ===================================================================
log "2/16 libjpeg-turbo"
# ===================================================================
clone "https://github.com/libjpeg-turbo/libjpeg-turbo.git" libjpeg-turbo
rm -rf "$SRC_DIR/libjpeg-turbo/build"
mkdir -p "$SRC_DIR/libjpeg-turbo/build" && cd "$SRC_DIR/libjpeg-turbo/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
  -DWITH_SIMD=ON \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "3/16 libpng"
# ===================================================================
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
  -DZLIB_LIBRARY="$PREFIX/lib/libz.a" \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "4/16 libtiff"
# ===================================================================
clone "https://gitlab.com/libtiff/libtiff.git" libtiff
rm -rf "$SRC_DIR/libtiff/build"
mkdir -p "$SRC_DIR/libtiff/build" && cd "$SRC_DIR/libtiff/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -Djpeg=ON -Djbig=OFF -Dlerc=OFF -Dzstd=OFF -Dwebp=OFF -Dlzma=OFF \
  -DZLIB_INCLUDE_DIR="$PREFIX/include" -DZLIB_LIBRARY="$PREFIX/lib/libz.a" \
  -DJPEG_INCLUDE_DIR="$PREFIX/include" -DJPEG_LIBRARY="$PREFIX/lib/libjpeg.a" \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "5/16 libwebp"
# ===================================================================
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
  -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF \
  -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF \
  -DWEBP_ENABLE_SIMD=ON -DWEBP_USE_THREAD=ON \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "6/16 brotli"
# ===================================================================
clone "https://github.com/google/brotli.git" brotli
rm -rf "$SRC_DIR/brotli/build"
mkdir -p "$SRC_DIR/brotli/build" && cd "$SRC_DIR/brotli/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "7/16 xz (lzma)"
# ===================================================================
clone "https://github.com/tukaani-project/xz.git" xz
cd "$SRC_DIR/xz"
[ -x ./autogen.sh ] && ./autogen.sh || autoreconf -i 2>/dev/null || true
./configure \
  --host=aarch64-linux-android \
  --prefix="$PREFIX" \
  --enable-static --disable-shared \
  --disable-doc --disable-nls \
  --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo \
  CC="$CC" AR="$AR" RANLIB="$RANLIB" STRIP="$STRIP" \
  CFLAGS="-O3 -fPIC"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "8/16 zstd"
# ===================================================================
clone "https://github.com/facebook/zstd.git" zstd
cd "$SRC_DIR/zstd"/lib
make -j"$JOBS" \
  CC="$CC" AR="$AR" CFLAGS="-O3 -fPIC" \
  libzstd.a
cp libzstd.a "$PREFIX/lib/"
cp zstd.h "$PREFIX/include/"
mkdir -p "$PREFIX/include/zstd" && cp zstd_errors.h "$PREFIX/include/zstd/" 2>/dev/null || true
cd -

# ===================================================================
log "9/16 libde265"
# ===================================================================
clone "https://github.com/strukturag/libde265.git" libde265
rm -rf "$SRC_DIR/libde265/build"
mkdir -p "$SRC_DIR/libde265/build" && cd "$SRC_DIR/libde265/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_SDL=OFF -DENABLE_DECODER=ON -DENABLE_ENCODER=ON \
  -DENABLE_ASSEMBLY=ON \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "10/16 x265"
# ===================================================================
clone "https://bitbucket.org/multicoreware/x265_git.git" x265

# x265 自家 CMake, 写一份最小工具链
cat > "$SRC_DIR/x265/build/arm64-android.cmake" <<EOF
set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_SYSTEM_VERSION $API)
set(ANDROID_ABI $ABI)
set(ANDROID_PLATFORM $API)
set(CMAKE_C_COMPILER $CC)
set(CMAKE_CXX_COMPILER $CXX)
set(CMAKE_AR $AR)
set(CMAKE_RANLIB $RANLIB)
set(CMAKE_FIND_ROOT_PATH $PREFIX)
EOF

rm -rf "$SRC_DIR/x265/build/android"
mkdir -p "$SRC_DIR/x265/build/android" && cd "$SRC_DIR/x265/build/android"
cmake ../../source \
  -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$SRC_DIR/x265/build/arm64-android.cmake" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
  -DENABLE_CLI=OFF -DENABLE_TESTS=OFF \
  -DENABLE_ASSEMBLY=ON -DENABLE_NEON=ON \
  -DCMAKE_C_FLAGS="-fPIC -O3" -DCMAKE_CXX_FLAGS="-fPIC -O3"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "11/16 x264"
# ===================================================================
clone "https://code.videolan.org/videolan/x264.git" x264
cd "$SRC_DIR/x264"
./configure \
  --prefix="$PREFIX" \
  --host=aarch64-linux-android \
  --cross-prefix="$TOOLCHAIN/bin/llvm-" \
  --sysroot="$SYSROOT" \
  --enable-static --disable-shared \
  --enable-pic --disable-cli \
  --extra-cflags="-O3 -fPIC" \
  --disable-asm
make -j"$JOBS" && make install
cd -

# ===================================================================
log "12/16 openh264"
# ===================================================================
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

# ===================================================================
log "13/16 aom (AV1)"
# ===================================================================
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
  -DCONFIG_AV1_ENCODER=1 -DCONFIG_AV1_DECODER=1 \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "14/16 vvenc"
# ===================================================================
clone "https://github.com/fraunhoferhhi/vvenc.git" vvenc
rm -rf "$SRC_DIR/vvenc/build"
mkdir -p "$SRC_DIR/vvenc/build" && cd "$SRC_DIR/vvenc/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DVVENC_ENABLE_THIRDPARTY_LIBS=OFF -DBUILD_APPS=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "15/16 vvdec"
# ===================================================================
clone "https://github.com/fraunhoferhhi/vvdec.git" vvdec
rm -rf "$SRC_DIR/vvdec/build"
mkdir -p "$SRC_DIR/vvdec/build" && cd "$SRC_DIR/vvdec/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_APPS=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ===================================================================
log "16/16 OpenJPEG + OpenJPH"
# ===================================================================
clone "https://github.com/uclouvain/openjpeg.git" openjpeg
rm -rf "$SRC_DIR/openjpeg/build"
mkdir -p "$SRC_DIR/openjpeg/build" && cd "$SRC_DIR/openjpeg/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF -DBUILD_DOC=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

clone "https://github.com/aous72/OpenJPH.git" openjph
rm -rf "$SRC_DIR/openjph/build"
mkdir -p "$SRC_DIR/openjph/build" && cd "$SRC_DIR/openjph/build"
cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF \
  -DOJPH_BUILD_EXECUTABLES=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS"
make -j"$JOBS" && make install
cd -

# ====== 完成 ======
log "ALL 16 DEPS INSTALLED TO $PREFIX"
echo "--- $PREFIX/lib ---"
ls -la "$PREFIX/lib" | head -60
echo "--- $PREFIX/include ---"
ls "$PREFIX/include"

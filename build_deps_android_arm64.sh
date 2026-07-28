#!/bin/bash
# build_deps_android_arm64.sh
# Android arm64 API24 NDK r27c 全静态依赖 + libheif 单体工具
set -e

API=24
ABI=arm64-v8a
PREFIX="$(pwd)/arm64-prefix"
export NDKROOT="$NDK_ROOT"
JOBS=$(nproc)

NDK_ROOT="${NDK_ROOT:-/d/a/_temp/ndk/android-ndk-r27c}"
TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/windows-x86_64"
SYSROOT="$TOOLCHAIN/sysroot"

CC="$TOOLCHAIN/bin/aarch64-linux-android$API-clang"
CXX="$TOOLCHAIN/bin/aarch64-linux-android$API-clang++"
AR="$TOOLCHAIN/bin/llvm-ar"
RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
NM="$TOOLCHAIN/bin/llvm-nm"
STRIP="$TOOLCHAIN/bin/llvm-strip"
LD="$TOOLCHAIN/bin/ld.lld"

export CFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -O3 -fPIC -DANDROID -DNDEBUG"
export CXXFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -O3 -fPIC -DANDROID -DNDEBUG"
export LDFLAGS="--target=aarch64-linux-android$API --sysroot=$SYSROOT -static -L$SYSROOT/usr/lib/$ABI"
export AR RANLIB NM STRIP LD

CMAKE_TOOLCHAIN="$NDK_ROOT/build/cmake/android.toolchain.cmake"
mkdir -p "$PREFIX"/{include,lib,bin}
SRC_DIR="$(pwd)/deps-src"
mkdir -p "$SRC_DIR"

clone() {
  local repo="$1" dir="$2"
  if [ -d "$SRC_DIR/$dir" ]; then
    git -C "$SRC_DIR/$dir" pull --ff-only || true
  else
    git clone --depth 1 "$repo" "$SRC_DIR/$dir"
  fi
}

# ---- 1 zlib ----
echo "===== zlib ====="
clone https://github.com/madler/zlib.git zlib
rm -rf "$SRC_DIR/zlib/build"; mkdir -p "$SRC_DIR/zlib/build"; cd "$SRC_DIR/zlib/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DZLIB_BUILD_TESTING=OFF
make -j"$JOBS" && make install
cd -

# ---- 2 libjpeg-turbo ----
echo "===== libjpeg-turbo ====="
clone https://github.com/libjpeg-turbo/libjpeg-turbo.git libjpeg-turbo
rm -rf "$SRC_DIR/libjpeg-turbo/build"; mkdir -p "$SRC_DIR/libjpeg-turbo/build"; cd "$SRC_DIR/libjpeg-turbo/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_SIMD=ON
make -j"$JOBS" && make install
cd -

# ---- 3 libpng ----
echo "===== libpng ====="
clone https://github.com/glennrp/libpng.git libpng
rm -rf "$SRC_DIR/libpng/build"; mkdir -p "$SRC_DIR/libpng/build"; cd "$SRC_DIR/libpng/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DPNG_SHARED=OFF -DPNG_STATIC=ON \
  -DZLIB_INCLUDE_DIR="$PREFIX/include" -DZLIB_LIBRARY="$PREFIX/lib/libz.a"
make -j"$JOBS" && make install
cd -

# ---- 4 libtiff ----
echo "===== libtiff ====="
clone https://gitlab.com/libtiff/libtiff.git libtiff
rm -rf "$SRC_DIR/libtiff-build"; mkdir -p "$SRC_DIR/libtiff-build"; cd "$SRC_DIR/libtiff-build"
cmake "$SRC_DIR/libtiff" -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -Djpeg=ON -Djbig=OFF -Dlerc=OFF -Dzstd=OFF -Dwebp=OFF \
  -DBUILD_TESTING=OFF -DBUILD_DOCS=OFF -DBUILD_CONTRIB=OFF \
  -DZLIB_INCLUDE_DIR="$PREFIX/include" -DZLIB_LIBRARY="$PREFIX/lib/libz.a" \
  -DJPEG_INCLUDE_DIR="$PREFIX/include" -DJPEG_LIBRARY="$PREFIX/lib/libjpeg.a"
make -j"$JOBS" && make install
cd -

# ---- 5 libwebp ----
echo "===== libwebp ====="
clone https://chromium.googlesource.com/webm/libwebp libwebp
rm -rf "$SRC_DIR/libwebp/build"; mkdir -p "$SRC_DIR/libwebp/build"; cd "$SRC_DIR/libwebp/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF \
  -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF \
  -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_LIBWEBPMUX=OFF \
  -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_ENABLE_SIMD=ON -DWEBP_USE_THREAD=ON
make -j"$JOBS" && make install
cd -

# ---- 6 brotli ----
echo "===== brotli ====="
clone https://github.com/google/brotli.git brotli
rm -rf "$SRC_DIR/brotli/build"; mkdir -p "$SRC_DIR/brotli/build"; cd "$SRC_DIR/brotli/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF
make -j"$JOBS" && make install
cd -

# ---- 7 xz ----
echo "===== xz ====="
clone https://github.com/tukaani-project/xz.git xz
rm -rf "$SRC_DIR/xz/build"; mkdir -p "$SRC_DIR/xz/build"; cd "$SRC_DIR/xz/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_DOCS=OFF
make -j"$JOBS" && make install
cd -

# ---- 8 zstd ----
echo "===== zstd ====="
clone https://github.com/facebook/zstd.git zstd
cd "$SRC_DIR/zstd/lib"
make -j"$JOBS" CC="$CC" AR="$AR" CFLAGS="-O3 -fPIC" libzstd.a
cp libzstd.a "$PREFIX/lib/"
cp zstd.h "$PREFIX/include/"
cp zstd_errors.h "$PREFIX/include/" 2>/dev/null || true
cd -

# ---- 9 libde265 ----
echo "===== libde265 ====="
clone https://github.com/strukturag/libde265.git libde265
rm -rf "$SRC_DIR/libde265/build"; mkdir -p "$SRC_DIR/libde265/build"; cd "$SRC_DIR/libde265/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DENABLE_SDL=OFF -DENABLE_DECODER=ON -DENABLE_ENCODER=ON \
  -DENABLE_ASSEMBLY=ON
make -j"$JOBS" && make install
cd -

# ---- 10 x265 ----
echo "===== x265 ====="
clone https://bitbucket.org/multicoreware/x265_git.git x265
rm -rf "$SRC_DIR/x265/build-arm64"; mkdir -p "$SRC_DIR/x265/build-arm64"; cd "$SRC_DIR/x265/build-arm64"
cmake "$SRC_DIR/x265/source" -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DENABLE_SHARED=OFF -DENABLE_CLI=OFF \
  -DENABLE_TESTS=OFF -DENABLE_ASSEMBLY=OFF
make -j"$JOBS" && make install
cd -

# ---- 11 aom ----
echo "===== aom ====="
clone https://aomedia.googlesource.com/aom aom
rm -rf "$SRC_DIR/aom/build"; mkdir -p "$SRC_DIR/aom/build"; cd "$SRC_DIR/aom/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DENABLE_EXAMPLES=0 -DENABLE_TESTS=0 -DENABLE_DOCS=0 \
  -DENABLE_TOOLS=0 -DENABLE_NASM=0 -DCONFIG_AV1_ENCODER=1 -DCONFIG_AV1_DECODER=1
make -j"$JOBS" && make install
cd -

# ---- 12 vvenc / vvdec ----
echo "===== vvenc ====="
clone https://github.com/fraunhoferhhi/vvenc.git vvenc
rm -rf "$SRC_DIR/vvenc/build"; mkdir -p "$SRC_DIR/vvenc/build"; cd "$SRC_DIR/vvenc/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DVVENC_ENABLE_THIRDPARTY_LIBS=OFF -DBUILD_APPS=OFF
make -j"$JOBS" && make install
cd -

echo "===== vvdec ====="
clone https://github.com/fraunhoferhhi/vvdec.git vvdec
rm -rf "$SRC_DIR/vvdec/build"; mkdir -p "$SRC_DIR/vvdec/build"; cd "$SRC_DIR/vvdec/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_APPS=OFF
make -j"$JOBS" && make install
cd -

# ---- 13 openjpeg / openjph ----
echo "===== openjpeg ====="
clone https://github.com/uclouvain/openjpeg.git openjpeg
rm -rf "$SRC_DIR/openjpeg/build"; mkdir -p "$SRC_DIR/openjpeg/build"; cd "$SRC_DIR/openjpeg/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF -DBUILD_DOC=OFF
make -j"$JOBS" && make install
cd -

echo "===== openjph ====="
clone https://github.com/aous72/OpenJPH.git openjph
rm -rf "$SRC_DIR/openjph/build"; mkdir -p "$SRC_DIR/openjph/build"; cd "$SRC_DIR/openjph/build"
cmake .. -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED_LIBS=OFF -DOJPH_BUILD_EXECUTABLES=OFF
make -j"$JOBS" && make install
cd -

# ================= 18. libheif 本体 =================
echo "===== libheif ====="
clone https://github.com/strukturag/libheif.git libheif
rm -rf "$SRC_DIR/libheif/build-android"
mkdir -p "$SRC_DIR/libheif/build-android" && cd "$SRC_DIR/libheif/build-android"

# libde265 的 cmake 模块会找 liblibde265.a，做个副本兼容
cp "$PREFIX/lib/libde265.a" "$PREFIX/lib/liblibde265.a" 2>/dev/null || true

# ----- 写 pkg-config .pc 文件（用正确库名，不带 lib 前缀重复）-----
PC_DIR="$PREFIX/lib/pkgconfig"
mkdir -p "$PC_DIR"

write_pc() {
  local pcname="$1" libs="$2"
  cat > "$PC_DIR/${pcname}.pc" << EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: ${pcname}
Description: ${pcname}
Version: 1.0
Cflags: -I\${includedir}
Libs: -L\${libdir} ${libs}
EOF
}

# .pc 文件名和 Libs 里的名字必须匹配库的实际文件名
write_pc zlib      "-lz"
write_pc libjpeg   "-ljpeg"
write_pc libpng    "-lpng16"
write_pc libwebp   "-lwebp"
write_pc brotlienc "-lbrotlienc -lbrotlidec -lbrotlicommon"
write_pc liblzma   "-llzma"
write_pc zstd      "-lzstd"
write_pc libde265  "-lde265"
write_pc x265      "-lx265"
write_pc aom       "-laom"
write_pc vvenc     "-lvvenc"
write_pc vvdec     "-lvvdec"
write_pc openjp2   "-lopenjp2"
write_pc openjph   "-lopenjph"

# ----- 可靠的 pkg-config shim -----
cat > "$PREFIX/bin/pkg-config" << 'SH'
#!/bin/sh
PC_DIR="$PREFIX_PLACEHOLDER/lib/pkgconfig"
action=""
package=""
for arg in "$@"; do
  case "$arg" in
    --cflags|--libs|--exists|--modversion) action="$arg" ;;
    -*) ;;
    *)  [ -z "$package" ] && package="$arg" ;;
  esac
done
[ ! -f "$PC_DIR/$package.pc" ] && exit 1
case "$action" in
  --cflags)     grep '^Cflags:' "$PC_DIR/$package.pc" | sed 's/^Cflags: *//' ;;
  --libs)       grep '^Libs:'   "$PC_DIR/$package.pc" | sed 's/^Libs: *//' ;;
  --modversion) grep '^Version:' "$PC_DIR/$package.pc" | sed 's/^Version: *//' ;;
  --exists)     exit 0 ;;
  *)            cat "$PC_DIR/$package.pc" ;;
esac
SH
# 替换占位符为实际路径
sed -i "s|PREFIX_PLACEHOLDER|$PREFIX|g" "$PREFIX/bin/pkg-config"
chmod +x "$PREFIX/bin/pkg-config"

export PATH="$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PC_DIR"

cmake .. -G "Unix Makefiles" \
  -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN" \
  -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$API" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DPKG_CONFIG_EXECUTABLE="$PREFIX/bin/pkg-config" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_EXAMPLES=ON \
  -DBUILD_TOOLS=ON \
  -DENABLE_PLUGIN_LOADING=OFF \
  -DWITH_LIBDE265=ON \
  -DWITH_X265=ON \
  -DWITH_AOM_DECODER=ON \
  -DWITH_AOM_ENCODER=ON \
  -DWITH_VVDEC=ON \
  -DWITH_VVENC=ON \
  -DWITH_OPENJPEG_DECODER=ON \
  -DWITH_OPENJPEG_ENCODER=ON \
  -DWITH_OPENJPH_ENCODER=ON \
  -DWITH_JPEG_DECODER=ON \
  -DWITH_JPEG_ENCODER=ON \
  -DWITH_LIBPNG=ON \
  -DWITH_LIBWEBP=ON \
  -DWITH_BROTLI=ON \
  -DWITH_ZLIB=ON \
  -DWITH_LZMA=ON \
  -DWITH_ZSTD=ON \
  -DWITH_UNCOMPRESSED_CODEC=ON \
  -DWITH_DAV1D=OFF \
  -DWITH_KVAZAAR=OFF \
  -DWITH_RAV1E=OFF \
  -DWITH_UVG266=OFF \
  -DWITH_FFMPEG_DECODER=OFF

make -j"$JOBS" && make install
cd -# 拷贝工具（两个位置都试）
cp -v tools/heif-* "$PREFIX/bin/" 2>/dev/null
cp -v examples/heif-* "$PREFIX/bin/" 2>/dev/null
cp -v bin/heif-* "$PREFIX/bin/" 2>/dev/null

cd -

echo "===== DONE ====="
echo "静态库: $PREFIX/lib"
echo "单体工具: $PREFIX/bin"
ls -la "$PREFIX/bin/"

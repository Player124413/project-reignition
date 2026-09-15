#!/usr/bin/env bash
# Builds the EIRTeam.FFmpeg GDExtension + LGPL FFmpeg for Android arm64-v8a
# and copies the result into Project/addons/ffmpeg/android.
#
# Mirrors .github/workflows/ffmpeg-android.yml for local use.
#
# Requirements (Linux or macOS host):
#   - Android NDK 23.2.8568313 (the version hard-coded in godot-cpp/tools/android.py)
#     -> export ANDROID_NDK_ROOT=/path/to/ndk/23.2.8568313
#        or export ANDROID_HOME=/path/to/sdk (with ndk/23.2.8568313 installed)
#   - python3 + scons (pip install scons==4.4.0)
#   - git, make, pkg-config, nasm is NOT required (asm is disabled for cross builds here)
#
# Usage:
#   misc/build-ffmpeg-android.sh [work_dir]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${1:-${REPO_ROOT}/ffmpeg-android-build}"
OUT="${REPO_ROOT}/Project/addons/ffmpeg/android"

FFMPEG_REF="${FFMPEG_REF:-n6.1.2}"          # keep on the 6.x line (avcodec 60)
EIRTEAM_REF="${EIRTEAM_REF:-master}"
API="${ANDROID_API_LEVEL:-24}"
NDK_VERSION="23.2.8568313"

if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
  if [[ -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}/ndk/${NDK_VERSION}" ]]; then
    ANDROID_NDK_ROOT="${ANDROID_HOME}/ndk/${NDK_VERSION}"
  else
    echo "error: set ANDROID_NDK_ROOT (NDK ${NDK_VERSION})" >&2
    exit 1
  fi
fi
export ANDROID_NDK_ROOT

case "$(uname -s)" in
  Linux)  HOST_TAG=linux-x86_64 ;;
  Darwin) HOST_TAG=darwin-x86_64 ;;
  *) echo "error: unsupported host $(uname -s)" >&2; exit 1 ;;
esac
TOOLCHAIN="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_TAG}"
[[ -x "${TOOLCHAIN}/bin/clang" ]] || { echo "error: NDK toolchain not found at ${TOOLCHAIN}" >&2; exit 1; }

JOBS="$( (nproc 2>/dev/null || sysctl -n hw.ncpu) )"
mkdir -p "${WORK}"
cd "${WORK}"

# --- sources ---------------------------------------------------------------
if [[ ! -d ffmpeg-src ]]; then
  git clone --depth 1 --branch "${FFMPEG_REF}" https://github.com/FFmpeg/FFmpeg.git ffmpeg-src
fi
if [[ ! -d eirteam-ffmpeg ]]; then
  git clone --branch "${EIRTEAM_REF}" https://github.com/EIRTeam/EIRTeam.FFmpeg.git eirteam-ffmpeg
  (cd eirteam-ffmpeg && git submodule update --init --depth 1 gdextension_build/godot-cpp)
fi

# --- FFmpeg -----------------------------------------------------------------
PREFIX="${WORK}/ffmpeg-android-arm64"
if [[ ! -f "${PREFIX}/lib/libavcodec.so" ]]; then
  pushd ffmpeg-src >/dev/null
  ./configure \
    --prefix="${PREFIX}" \
    --target-os=android --arch=aarch64 --cpu=armv8-a --enable-cross-compile \
    --sysroot="${TOOLCHAIN}/sysroot" \
    --cc="${TOOLCHAIN}/bin/aarch64-linux-android${API}-clang" \
    --cxx="${TOOLCHAIN}/bin/aarch64-linux-android${API}-clang++" \
    --ar="${TOOLCHAIN}/bin/llvm-ar" --nm="${TOOLCHAIN}/bin/llvm-nm" \
    --ranlib="${TOOLCHAIN}/bin/llvm-ranlib" --strip="${TOOLCHAIN}/bin/llvm-strip" \
    --extra-cflags="-fPIC -O3" \
    --extra-ldflags="-Wl,-z,max-page-size=16384" \
    --enable-shared --disable-static --enable-pic \
    --disable-programs --disable-doc --disable-debug \
    --disable-avdevice --disable-postproc --disable-network \
    --disable-encoders --disable-muxers --disable-devices --disable-outdevs --disable-indevs \
    --disable-filters \
    --enable-filter=scale,format,null,anull,aformat,aresample,atrim,trim \
    --disable-decoders \
    --enable-decoder=h264,hevc,mpeg4,vp8,vp9,av1,theora,mjpeg,png \
    --enable-decoder=aac,aac_latm,mp3,mp3float,vorbis,opus,flac,pcm_s16le,pcm_s16be,pcm_f32le \
    --disable-demuxers \
    --enable-demuxer=mov,matroska,ogg,mp3,aac,wav,flac,mpegts,avi,image2 \
    --disable-parsers \
    --enable-parser=h264,hevc,mpeg4video,vp8,vp9,av1,aac,aac_latm,mpegaudio,vorbis,opus,flac,mjpeg,png \
    --disable-protocols --enable-protocol=file,pipe \
    --disable-bsfs \
    --enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,aac_adtstoasc,extract_extradata
  make -j"${JOBS}"
  make install
  popd >/dev/null
fi

# --- GDExtension ------------------------------------------------------------
pushd eirteam-ffmpeg/gdextension_build >/dev/null
python3 - <<'PY'
from pathlib import Path
p = Path("SConstruct"); s = p.read_text()
marker = 'env.Append(CPPDEFINES=["GDEXTENSION"])'
if "max-page-size" not in s:
    s = s.replace(marker, marker + '\nif env["platform"] == "android":\n    env.Append(LINKFLAGS=["-Wl,-z,max-page-size=16384", "-static-libstdc++"])\n', 1)
    p.write_text(s)
PY
for target in template_release template_debug; do
  scons platform=android arch=arm64 target="${target}" \
    android_api_level="${API}" debug_symbols=no \
    ffmpeg_path="${PREFIX}" -j"${JOBS}"
done
popd >/dev/null

# --- install into the project ----------------------------------------------
SRC="${WORK}/eirteam-ffmpeg/gdextension_build/build/addons/ffmpeg/android"
mkdir -p "${OUT}"
for lib in avcodec avfilter avformat avutil swresample swscale; do
  cp "${SRC}/lib${lib}.so" "${OUT}/lib${lib}.so"
done
cp "${SRC}"/libgdffmpeg.android.template_{release,debug}.arm64.so "${OUT}/"
"${TOOLCHAIN}/bin/llvm-strip" --strip-unneeded "${OUT}"/*.so

echo
echo "Installed into ${OUT}:"
ls -lh "${OUT}"/*.so

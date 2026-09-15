# FFmpeg (video playback) on Android

The project plays MP4 videos (boot logos, world-select demos, event cutscenes)
through the [EIRTeam.FFmpeg](https://github.com/EIRTeam/EIRTeam.FFmpeg)
GDExtension. `Project/addons/ffmpeg/ffmpeg.gdextension` already declares the
Android arm64 entries:

```
android.debug.arm64   = res://addons/ffmpeg/android/libgdffmpeg.android.template_debug.arm64.so
android.release.arm64 = res://addons/ffmpeg/android/libgdffmpeg.android.template_release.arm64.so
android.arm64 dependencies: libavcodec.so libavfilter.so libavformat.so
                            libavutil.so libswresample.so libswscale.so
```

Upstream only publishes Windows / Linux / macOS binaries, so the Android ones
have to be built by us.

## 1. Getting the binaries

### Option A — GitHub Actions (recommended)

1. Open **Actions → "FFmpeg GDExtension (Android)" → Run workflow** on the
   branch you are working on.
2. Leave `commit_to_repo = true`. When the job finishes it pushes a commit with
   the eight `.so` files into `Project/addons/ffmpeg/android/`.
   (Alternatively set it to `false` and download the
   `ffmpeg-gdextension-android-arm64` artifact, then unpack it into that folder.)
3. Run the regular **"Android APK"** workflow — the export picks up the new
   libraries automatically; Godot copies GDExtension `.so` files and their
   declared dependencies into the APK's `lib/arm64-v8a/`.

The job takes roughly 20–30 minutes (FFmpeg is compiled from source).

### Option B — local build

```bash
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/23.2.8568313   # NDK required by godot-cpp
pip install scons==4.4.0
misc/build-ffmpeg-android.sh
```

The script clones FFmpeg + EIRTeam.FFmpeg into `ffmpeg-android-build/`
(git-ignored), builds everything for `arm64-v8a` and copies the results into
`Project/addons/ffmpeg/android/`.

## 2. What exactly is built

| Component | Version | Notes |
|-----------|---------|-------|
| FFmpeg    | `n6.1.2` | Must stay on the 6.x line: the extension is compiled against avcodec 60 / avformat 60 / avutil 58, the same major versions as the desktop libs shipped in `win64/` and `linux64/`. |
| EIRTeam.FFmpeg | `master` | Built with `scons platform=android arch=arm64`. |
| Android API | 24 | Project minimum is API 29, so 24 is more than safe. |
| NDK | 23.2.8568313 | Hard-coded in `godot-cpp/tools/android.py`. |

FFmpeg is configured as **LGPL, shared, decode-only**: no encoders, muxers,
network or devices; only the decoders/demuxers needed for H.264/HEVC/VP9/AV1
video and AAC/MP3/Vorbis/Opus/FLAC audio in MP4/MKV/OGG containers. All
libraries are linked with `-Wl,-z,max-page-size=16384`, so they work on
16 KB-page Android 15+ devices, and the extension links `libc++` statically so
it does not depend on `libc++_shared.so`.

Only `arm64-v8a` is produced because that is the only architecture enabled in
`docs/android/export_presets.cfg.example`. To add `armeabi-v7a` or `x86_64`
duplicate the workflow steps with `--arch=arm`/`x86_64`, `arch=arm32`/`x86_64`
and add the matching `android.<arch>` entries to `ffmpeg.gdextension`.

## 3. Runtime behaviour

`Project/video/VideoStreamFileLoadPlayer.cs` no longer disables video on
Android unconditionally. Instead it checks whether the extension actually
loaded (`ClassDB.ClassExists("FFmpegVideoStream")`):

- extension loaded → the MP4 is loaded and played exactly like on desktop;
- extension missing (binaries absent, wrong ABI, load failure) → a warning is
  printed, the player is hidden and the surrounding animation/audio timeline
  keeps running, so the game never hard-fails on a missing decoder.

## 4. Verifying on device

```bash
adb logcat -s godot | grep -i -E "ffmpeg|gdextension|video"
```

You should not see `Can't open dynamic library` / `FFmpeg GDExtension is not
loaded`. The SEGA / SFF logos in the boot scene are the quickest visual check.

## 5. Licensing

The Android FFmpeg build is LGPL 2.1+ (no `--enable-gpl`, no x264/x265). Keep
`Project/addons/ffmpeg/LICENSE-ffmpeg.txt` in the distribution and mention
FFmpeg in the credits, as is already done for the desktop builds.

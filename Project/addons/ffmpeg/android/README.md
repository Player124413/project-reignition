# FFmpeg GDExtension — Android arm64-v8a

This folder must contain the Android build of EIRTeam.FFmpeg referenced by
`../ffmpeg.gdextension`:

```
libgdffmpeg.android.template_debug.arm64.so
libgdffmpeg.android.template_release.arm64.so
libavcodec.so
libavfilter.so
libavformat.so
libavutil.so
libswresample.so
libswscale.so
```

Upstream EIRTeam.FFmpeg does not publish Android binaries. The "Android APK"
workflow (`.github/workflows/android.yml`) builds them in its `build-ffmpeg`
job and places them here automatically before exporting the APK. For a local
export run `misc/build-ffmpeg-android.sh` or unpack the
`ffmpeg-gdextension-android-arm64` workflow artifact into this directory.

See `docs/android-ffmpeg.md` for details (FFmpeg version constraints, manual
build steps and how the runtime fallback works).

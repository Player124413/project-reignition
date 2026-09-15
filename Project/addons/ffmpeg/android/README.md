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

Upstream EIRTeam.FFmpeg does not publish Android binaries, so they are built by
the GitHub Actions workflow `.github/workflows/ffmpeg-android.yml`
(**Actions → "FFmpeg GDExtension (Android)" → Run workflow**). With
`commit_to_repo` enabled the workflow commits the `.so` files here; otherwise
download the `ffmpeg-gdextension-android-arm64` artifact and unpack it into
this directory.

See `docs/android-ffmpeg.md` for details (FFmpeg version constraints, manual
build steps and how the runtime fallback works).

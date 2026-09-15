using Godot;

namespace Project.Interface.Menus;

[Tool]
public partial class VideoStreamFileLoadPlayer : VideoStreamPlayer
{
	[Export(PropertyHint.File)]
	private string videoFilePath;
	private bool videoFallback;
	public void SetVideoFilePath(string path) => videoFilePath = path;

	/// <summary>
	/// True when the FFmpeg GDExtension (EIRTeam.FFmpeg) has been loaded by the engine.
	/// The MP4 files used by the project can only be decoded through that extension.
	/// </summary>
	public static bool IsFFmpegAvailable => ClassDB.ClassExists("FFmpegVideoStream");

	public override void _Ready()
	{
		if (Engine.IsEditorHint())
			return;

		// The FFmpeg GDExtension binaries for Android live in
		// addons/ffmpeg/android and are produced by the "FFmpeg GDExtension (Android)"
		// workflow. If the extension failed to load (missing binaries, unsupported ABI),
		// keep the surrounding animation/audio timeline usable instead of trying to
		// load an MP4 without a decoder.
		videoFallback = !IsFFmpegAvailable;
		if (videoFallback)
		{
			GD.PushWarning($"FFmpeg GDExtension is not loaded; video '{videoFilePath}' will be skipped.");
			Stream = null;
			Visible = false;
			return;
		}

		ReloadVideoPath();
	}

	public override void _Process(double _delta)
	{
		if (videoFallback)
			Visible = false;
	}

	public void ReloadVideoPath()
	{
		if (videoFallback || string.IsNullOrEmpty(videoFilePath))
			return;

		if (!ResourceLoader.Exists(videoFilePath, "VideoStream"))
		{
			GD.PushWarning($"Couldn't load video file {videoFilePath}!");
			return;
		}

		Stream = ResourceLoader.Load<VideoStream>(videoFilePath, "VideoStream");
	}
}

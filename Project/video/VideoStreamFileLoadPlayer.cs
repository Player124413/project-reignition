using Godot;

namespace Project.Interface.Menus;

[Tool]
public partial class VideoStreamFileLoadPlayer : VideoStreamPlayer
{
	[Export(PropertyHint.File)]
	private string videoFilePath;

	/// <summary>
	/// Static image shown in place of the video when the video file is missing
	/// (e.g. *.mp4 files are gitignored and absent from CI-built exports).
	/// Leave empty to keep the old "black screen" behaviour for optional videos.
	/// </summary>
	[Export(PropertyHint.File)]
	private string fallbackImagePath = "";

	private TextureRect _fallbackRect;

	public void SetVideoFilePath(string path) => videoFilePath = path;

	public override void _Ready()
	{
		if (Engine.IsEditorHint())
			return;

		ReloadVideoPath();
	}

	public void ReloadVideoPath()
	{
		if (string.IsNullOrEmpty(videoFilePath))
			return;

		if (!ResourceLoader.Exists(videoFilePath, "VideoStream"))
		{
			GD.PushWarning($"Couldn't load video file {videoFilePath}!");
			ShowFallback();
			return;
		}

		Stream = ResourceLoader.Load<VideoStream>(videoFilePath, "VideoStream");

		if (IsInstanceValid(_fallbackRect))
			_fallbackRect.Visible = false;
	}

	private void ShowFallback()
	{
		if (Stream != null)
			return; // Real video is playing — no fallback needed.

		if (string.IsNullOrEmpty(fallbackImagePath) || !ResourceLoader.Exists(fallbackImagePath))
			return;

		if (!IsInstanceValid(_fallbackRect))
		{
			_fallbackRect = new TextureRect
			{
				Name = "MissingVideoFallback",
				StretchMode = TextureRect.StretchModeEnum.KeepAspectCovered,
				MouseFilter = Control.MouseFilterEnum.Ignore,
			};
			_fallbackRect.SetAnchorsPreset(Control.LayoutPreset.FullRect);
			AddChild(_fallbackRect);
		}

		_fallbackRect.Texture = GD.Load<Texture2D>(fallbackImagePath);
		_fallbackRect.Visible = true;
	}
}

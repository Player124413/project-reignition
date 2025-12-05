using Godot;

/// <summary> Loops an audio stream seamlessly. </summary>
namespace Project;

public partial class BGMPlayer : AudioStreamPlayer
{
	[Export] private BGMResource bgmResource;
	public BGMResource GetBgmResource() => bgmResource;
	public void SetBgmResource(BGMResource resource) => bgmResource = resource;

	[Export]
	public float startPosition;
	[Export]
	public float loopStartPosition;
	[Export]
	public float loopEndPosition;
	[Export]
	public float debugSeek = -1; // Editor debug. Seeks to the specified point (in seconds)
	[Export]
	public bool isStageMusic; // TODO BGM-REWORK Remove This

	private bool canLoop;
	private float LoopLength => bgmResource.LoopEnd - bgmResource.LoopStart;

	public override void _EnterTree() => LoadBgmResource();

	public override void _Process(double _)
	{
		if (!canLoop) return;
		if (!Playing) return;

		float currentPosition = GetPlaybackPosition() + (float)AudioServer.GetTimeSinceLastMix();
		if (currentPosition >= bgmResource.LoopEnd)
			Seek(currentPosition - LoopLength);

		if (Engine.IsEditorHint() && !Mathf.IsEqualApprox(debugSeek, -1))
		{
			Seek(debugSeek);
			debugSeek = -1;
		}
	}

	/// <summary> Updates the BgmPlayer's Stream. </summary>
	public void LoadBgmResource()
	{
		if (bgmResource == null)
			return;

		canLoop = bgmResource.LoopEnd > bgmResource.LoopStart;
		if (!canLoop)
			GD.PrintErr("BGM loop points are set up incorrectly. Looping is disabled.");

		AudioStream stream = ResourceLoader.Load<AudioStream>(bgmResource.StreamPath);
		Stream = stream;

		if (Autoplay)
			Play();
	}

	public void RestartLoop()
	{
		if (GetPlaybackPosition() >= bgmResource.LoopEnd)
			Play(bgmResource.LoopStart);
	}

	public void Play() => Play(startPosition);
}
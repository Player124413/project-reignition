using Godot;

namespace Project.Core;

/// <summary> Loads a localized audio track based on the game's selected audio settings. </summary>
public partial class LocalizedTrackLoader : AudioStreamPlayer
{
	// NOTE: Getting file paths exported in Godot is funky--try not to break things by moving files around.
	[Export] private string[] audioPaths;

	public override void _Ready()
	{
		if (audioPaths.Length < (int)SaveManager.Config.voiceLanguage)
		{
			GD.PushError($"Couldn't load audio track for language {SaveManager.Config.voiceLanguage} on object {Name}!");
			return;
		}

		Stream = ResourceLoader.Load<AudioStream>(audioPaths[(int)SaveManager.Config.voiceLanguage], "AudioStream");
		if (Stream == null)
			GD.PushError($"Couldn't load audio track for language {SaveManager.Config.voiceLanguage} on object {Name}!");
	}
}

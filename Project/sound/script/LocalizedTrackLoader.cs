using Godot;

namespace Project.Core;

/// <summary> Loads a localized audio track based on the game's selected audio settings. </summary>
public partial class LocalizedTrackLoader : AudioStreamPlayer
{
	[Export(PropertyHint.File)] private string englishAudioResource;

	public override void _Ready()
	{
		Stream = ResourceLoader.Load<AudioStream>(GetAudioPath(), "AudioStream");
		if (Stream == null)
			GD.PushError($"Couldn't load audio track for language {SaveManager.Config.voiceLanguage} on object {Name}!");
	}

	private string GetAudioPath()
	{
		string audioPath = ResourceUid.UidToPath(englishAudioResource); // Default to English
		audioPath = audioPath.Replace("_en", $"_{SaveManager.VoiceLocaleToString(SaveManager.Config.voiceLanguage)}");
		return audioPath;
	}
}

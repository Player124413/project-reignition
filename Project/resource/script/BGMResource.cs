using Godot;

namespace Project;

[GlobalClass]
public partial class BGMResource : Resource
{
	/// <summary> The name of the song (used for Song Select)</summary>
	[Export] public string SongName;
	/// <summary> The path to the audiostream that should be loaded. </summary>
	[Export(PropertyHint.File, "*.mp3, *.ogg,*.wav")]
	public string StreamPath { get; set; }
	[Export] public float StartPosition { get; private set; }
	/// <summary> The time (in seconds) where the loop starts. </summary>
	[Export] public float LoopStart;
	/// <summary> The time (in seconds) where the loop ends. </summary>
	[Export] public float LoopEnd;
}

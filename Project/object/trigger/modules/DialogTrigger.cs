using Godot;
using Godot.Collections;
using Project.Core;

namespace Project.Gameplay.Triggers;

/// <summary>
/// Activates a dialog, with EN/JA/Subtitle support
/// </summary>
public partial class DialogTrigger : StageTriggerModule
{
	[Export] public bool isOneShot = true;
	[Export] public bool allowRespawn;
	[Export] public bool disableSubtitles;


	[Export] private PlaybackMode playbackType;
	private enum PlaybackMode
	{
		Queue, // Queue dialog to play after the current dialog is finished
		Always, // Always play dialog immediately
		NoSubtitles, // Only play dialog when nothing else is playing
	}

	private bool isTriggered;

	public override void Respawn()
	{
		if (allowRespawn)
			isTriggered = false;
	}

	public override void Activate()
	{
		if (Player != null && Player.IsDarkspineSonic && StageSettings.Instance.Data.LevelID != "np_last") // Disable dialog when Darkspine Sonic is active
			return;

		if (isTriggered)
			return;

		if (playbackType == PlaybackMode.NoSubtitles && SoundManager.instance.IsSubtitlesActive)
			return;

		isTriggered = isOneShot;

		if (IsCutscene || playbackType == PlaybackMode.Always || !SoundManager.instance.IsSubtitlesActive)
		{
			SoundManager.instance.ClearQueue();
			SoundManager.instance.PlayDialog(GetRandomDialogTrigger());
			return;
		}

		SoundManager.instance.QueueDialog(GetRandomDialogTrigger());
	}

	private DialogTrigger GetRandomDialogTrigger()
	{
		if (randomizedDialogTriggers == null || randomizedDialogTriggers.Length == 0) // Not randomizing dialog triggers
			return this;

		int targetIndex = Runtime.randomNumberGenerator.RandiRange(0, randomizedDialogTriggers.Length);
		if (targetIndex == randomizedDialogTriggers.Length)
			return this;

		return randomizedDialogTriggers[targetIndex];
	}

	public override void Deactivate() => SoundManager.instance.CancelDialog();

	public bool IsCutscene { get; set; }
	public int DialogCount => textKeys.Count;
	public bool HasDelay(int index) => delays != null && delays.Count > index && !Mathf.IsZeroApprox(delays[index]);
	public bool HasLength(int index) => displayLength != null && displayLength.Count > index && !Mathf.IsZeroApprox(displayLength[index]);

	/// <summary> Enable this to select a random voice clip when playing this trigger. </summary>
	[Export] public bool randomize;
	[Export(PropertyHint.Range, "0, 10")] public Array<float> delays;
	[Export(PropertyHint.Range, "0, 10")] public Array<float> displayLength; // Leave at (0) to use the raw audio length
	[Export] public Array<string> textKeys;

	/// <summary> Optional extra dialog triggers for randomly playing dialog sequences that have more than 1 voice line. </summary>
	[Export] private DialogTrigger[] randomizedDialogTriggers;
}
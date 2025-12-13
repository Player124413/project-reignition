using Godot;
using Project.Core;

namespace Project.Gameplay.Triggers;

/// <summary> Handles everybody's favorite character. </summary>
public partial class BigTrigger : Area3D
{
	[Signal] public delegate void BigSightedEventHandler();
	[Signal] public delegate void BigFinishedEventHandler();

	[Export] private StringName bigAnimation;
	[Export] private AnimationPlayer bigAnimator;
	[Export] private AnimationPlayer cameraAnimator;
	[Export] private CameraTrigger cameraTrigger;
	[Export] private LockoutTrigger stopLockout;
	[Export] private Timer timer;

	private readonly StringName CameraActivateString = "activate";

	public override void _Ready()
	{
		AreaEntered += OnEntered;
		AreaExited += OnExited;

		timer.Timeout += StartCutscene;
		cameraAnimator.AnimationFinished += FinishCutscene;

		Visible = false;
	}

	private void StartCutscene()
	{
		Visible = true;

		bigAnimator.Play(bigAnimation);
		cameraAnimator.Play(CameraActivateString);
		stopLockout.Activate();
		cameraTrigger.Activate();
		StageSettings.Player.Skills.DisableBreakSkills();
		StageSettings.Player.Deactivate();
		HeadsUpDisplay.Instance.SetVisibility(false);
		EmitSignal(SignalName.BigSighted);
	}

	private void FinishCutscene(StringName anim)
	{
		if (!anim.Equals(CameraActivateString))
			return;

		FinishCutscene();
	}
	private void FinishCutscene()
	{
		stopLockout.Deactivate();
		cameraTrigger.Deactivate();
		StageSettings.Player.Activate();
		HeadsUpDisplay.Instance.SetVisibility(true);

		// Write to file immediately
		if (!SaveManager.SharedData.bigCameos.Contains(StageSettings.Instance.Data.LevelID))
			SaveManager.SharedData.bigCameos.Add(StageSettings.Instance.Data.LevelID);

		EmitSignal(SignalName.BigFinished);
		StageSettings.Player.Skills.EnableBreakSkills();
		Visible = false;
		ProcessMode = ProcessModeEnum.Disabled;
	}

	public void OnEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		timer.Start();
	}

	public void OnExited(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		timer.Stop();
	}
}

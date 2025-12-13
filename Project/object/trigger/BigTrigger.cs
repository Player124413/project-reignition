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

	private PlayerController Player => StageSettings.Player;
	private float bigTimer;
	private bool isInteractingWithPlayer;

	private readonly float ActivationTimeLength = 3.0f;
	private readonly StringName CameraActivateString = "activate";

	public override void _Ready()
	{
		AreaEntered += OnEntered;
		AreaExited += OnExited;

		cameraAnimator.AnimationFinished += FinishCutscene;

		Visible = false;
	}

	public override void _PhysicsProcess(double _)
	{
		if (!isInteractingWithPlayer)
			return;

		if (!Player.IsOnGround || !Mathf.IsZeroApprox(Player.MoveSpeed))
			return;

		bigTimer += PhysicsManager.physicsDelta;
		if (bigTimer >= ActivationTimeLength)
			StartCutscene();
	}


	private void StartCutscene()
	{
		Visible = true;

		bigAnimator.Play(bigAnimation);
		cameraAnimator.Play(CameraActivateString);
		stopLockout.Activate();
		cameraTrigger.Activate();
		Player.Skills.DisableBreakSkills();
		Player.Deactivate();
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
		Player.Activate();
		HeadsUpDisplay.Instance.SetVisibility(true);

		// Write to file immediately
		if (!SaveManager.SharedData.bigCameos.Contains(StageSettings.Instance.Data.LevelID))
			SaveManager.SharedData.bigCameos.Add(StageSettings.Instance.Data.LevelID);

		EmitSignal(SignalName.BigFinished);
		Player.Skills.EnableBreakSkills();
		Visible = false;
		ProcessMode = ProcessModeEnum.Disabled;
	}

	public void OnEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		bigTimer = 0f;
		isInteractingWithPlayer = true;
	}

	public void OnExited(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = false;
	}
}

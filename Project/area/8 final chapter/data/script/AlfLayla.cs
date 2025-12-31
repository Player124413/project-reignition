using Godot;
using Project.Core;
using Project.Gameplay.Triggers;

namespace Project.Gameplay.Bosses;

public partial class AlfLayla : Node3D
{
	[Export] private AnimationTree animationTree;
	[Export] private PathFollow3D bossPathFollower;

	[Export] private DialogTrigger[] dialogTriggers;
	private int currentDialogIndex;

	private PlayerController Player => StageSettings.Player;

	[Export] private string[] attackPatterns;
	/// <summary> Tracks the index of the current phase. </summary>
	private int currentPatternIndex;
	/// <summary> Tracks the index character being processed in the current phase. </summary>
	private int currentActionIndex;
	/// <summary> Tracks the string currently being processed. </summary>
	private string currentActionString;
	private float actionTimer;

	/// <summary> Tracks Alf's current action. </summary>
	private FightState CurrentFightState;
	private enum FightState
	{
		Introduction,
		Idle,
		Action,
		Hitstun,
		Defeated,
	}

	private float currentDistance;
	private readonly float BombDistance = 80.0f;
	private readonly float FarDistance = 60.0f;
	private readonly float NormalDistance = 40.0f;
	private readonly float CloseDistance = 20.0f;

	public override void _Ready()
	{
		currentDistance = BombDistance;
	}

	public override void _PhysicsProcess(double _delta)
	{
		ProcessDistance();
		ProcessAction();
	}

	private void ProcessDistance()
	{
		bossPathFollower.Progress = Player.PathFollower.Progress + currentDistance;
		GlobalPosition = bossPathFollower.GlobalPosition;
	}

	private void ProcessAction()
	{
		if (CurrentFightState != FightState.Idle)
			return;

		actionTimer = Mathf.MoveToward(actionTimer, 0f, PhysicsManager.physicsDelta);
		if (!Mathf.IsZeroApprox(actionTimer))
			return;

		GetNextAction();
		StartAction();
	}

	private void GetNextAction()
	{
		currentActionString = string.Empty;
		while (currentActionIndex < attackPatterns[currentPatternIndex].Length && attackPatterns[currentPatternIndex][currentActionIndex] != ' ')
		{
			currentActionString += attackPatterns[currentPatternIndex][currentActionIndex];
			currentActionIndex++;
		}

		currentActionIndex++;
		if (currentActionIndex >= attackPatterns[currentPatternIndex].Length)
			currentActionIndex = 0;

		GD.Print($"Alf's action was set to {currentActionString}.");
	}

	private void StartAction()
	{
	}
}

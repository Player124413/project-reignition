using Godot;
using Project.Core;
using Project.Gameplay.Triggers;

namespace Project.Gameplay.Bosses;

public partial class AlfLayla : Node3D
{
	[ExportGroup("Components")]
	[Export] private AnimationTree animationTree;
	[Export] private PathFollow3D bossPathFollower;
	[Export] private CameraTrigger cutsceneCamera;

	[Export] private DialogTrigger[] dialogTriggers;
	private int currentDialogIndex;

	private PlayerController Player => StageSettings.Player;
	private PlayerPathController PlayerPathFollower => Player.PathFollower;

	[ExportGroup("Patterns")]
	[Export] private string[] attackPatterns;
	/// <summary> Tracks the index of the current phase. </summary>
	private int currentPatternIndex;
	/// <summary> Tracks the index character being processed in the current phase. </summary>
	private int currentActionIndex;
	/// <summary> Tracks the character associated with the action currently being processed. </summary>
	private char currentActionCharacter;
	private float actionTimer;

	/// <summary> Tracks Alf's current health. </summary>
	private int currentHealth;
	private readonly int MaxHealth = 25;

	/// <summary> Tracks Alf's current action. </summary>
	private FightState CurrentFightState;
	private enum FightState
	{
		Introduction,
		Idle,
		Movement,
		AttackWindup,
		AttackStrike,
		Hitstun,
		Defeated,
	}

	/// <summary> Curve that determines how Alf advances. </summary>
	[Export] private Curve advanceMovementCurve;
	/// <summary> Curve that determines how Alf retreats. </summary>
	[Export] private Curve retreatMovementCurve;
	private Curve currentMovementCurve;
	/// <summary> Tracks Alf's current distance to the player. </summary>
	private float currentDistance;
	/// <summary> [0, CurveMaxDomain] Samples the curve. </summary>
	private float movementSample;
	/// <summary> The starting distance of a movement. </summary>
	private float initialDistance;
	/// <summary> The ending distance of a movement. </summary>
	private float targetDistance;
	private readonly float BombDistance = 80.0f;
	private readonly float FarDistance = 50.0f;
	private readonly float NormalDistance = 30.0f;
	private readonly float CloseDistance = 15.0f;

	////////////////////////////////
	///// ANIMATION PARAMETERS /////
	////////////////////////////////
	private readonly string IntroCutsceneID = "last_boss_intro";
	private readonly string DefeatCutsceneID = "last_boss_defeat";
	private readonly string MovePlayback = "parameters/move-state/playback";
	private readonly string SlashDirection = "parameters/slash-side-transition/transition_request";
	private readonly string SlashTrigger = "parameters/slash-trigger/request";
	private readonly string SlashSpeed = "parameters/slash-speed/scale";
	private readonly string SixOrbTrigger = "parameters/six-orb-trigger/request";
	private readonly string SixOrbSpeed = "parameters/six-orb-speed/scale";
	private AnimationNodeStateMachinePlayback MoveStatePlayback => animationTree.Get(MovePlayback).Obj as AnimationNodeStateMachinePlayback;

	/*
	///////////////////////////////
	///////// ACTION KEYS /////////
	///////////////////////////////
	
	F - Far Distance
	M - Medium Distance
	C - Close Distance

	6 - Six orb attack
	3 - Three orb attack, goes from left to right (L M R)

	\ - \\ Two slashes right
	/ - // Two slashes left
	> - \\\ Three slashes right
	< - /// Three slashes left
	X - cross slash
	_ - Horizontal slash from right to left (<--)
	# - Net slash, covers the whole screen
	| - Three slashes down

	B - Bomb (Move to Bomb distance before using it)
	*/

	public override void _Ready()
	{
		animationTree.Active = true; // Activate animation trees

		StageSettings.Instance.RespawnedEnemies += Respawn;
		StageSettings.Instance.LevelStarted += StartIntroduction;
	}

	public override void _PhysicsProcess(double _delta)
	{
		ProcessAction();
		switch (CurrentFightState)
		{
			case FightState.Introduction:
				if ((Input.IsActionJustPressed("sys_pause") || Input.IsActionJustPressed("button_jump")) &&
					SaveManager.ActiveGameData.CanSkipCutscene(IntroCutsceneID))
				{
					FinishIntroduction();
				}
				return;
			case FightState.Defeated:
				if ((Input.IsActionJustPressed("sys_pause") || Input.IsActionJustPressed("button_jump")) &&
					SaveManager.ActiveGameData.CanSkipCutscene(DefeatCutsceneID))
				{
					//FinishDefeat();
				}

				bossPathFollower.Progress = PlayerPathFollower.Progress;
				GlobalTransform = bossPathFollower.GlobalTransform;
				ResetPhysicsInterpolation();
				return;
		}

		SnapDistance();
		GlobalTransform = bossPathFollower.GlobalTransform;
	}

	private void Respawn()
	{
		Player.Animator.CancelOneshot();

		CurrentFightState = FightState.Idle;

		currentHealth = MaxHealth;

		currentPatternIndex = 0;
		currentActionIndex = 0;
		currentActionCharacter = '\0';

		currentDistance = BombDistance;
		targetDistance = BombDistance;
		SnapDistance();

		Player.Camera.LookaroundAmount = Vector2.Zero;

		Transform = Transform3D.Identity;
		ResetPhysicsInterpolation();

		// TODO Reset Animations
	}

	private void StartIntroduction()
	{
		GlobalTransform = Player.GlobalTransform;
		ResetPhysicsInterpolation();

		// TODO Import Boss Start Event
		//animationTree.Set(IntroductionTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);
		cutsceneCamera.Activate();
		Interface.PauseMenu.AllowInputs = false;
		HeadsUpDisplay.Instance.SetVisibility(false);
		Player.Skills.DisableBreakSkills();
		Player.Animator.PlayOneshotAnimation(IntroCutsceneID);
	}

	private void FinishIntroduction()
	{
		if (TransitionManager.IsTransitionActive) return; // Player must have skipped the introduction animation

		TransitionManager.StartTransition(new()
		{
			inSpeed = 0f,
			outSpeed = .5f,
			color = Colors.Black
		});
		TransitionManager.Instance.Connect(TransitionManager.SignalName.TransitionProcess, new Callable(this, MethodName.StartBattle), (uint)ConnectFlags.OneShot);
		SaveManager.ActiveGameData.AllowSkippingCutscene(IntroCutsceneID);
		//animationTree.Set(IntroductionTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
		Player.Animator.CancelOneshot();
	}

	private void StartBattle()
	{
		cutsceneCamera.Deactivate();

		Respawn();
		Player.Skills.EnableBreakSkills();
		TransitionManager.FinishTransition();
		Interface.PauseMenu.AllowInputs = true;
		HeadsUpDisplay.Instance.SetVisibility(true);
	}

	/// <summary> Snaps Alf's distance to currentDistance. </summary>
	private void SnapDistance() => bossPathFollower.Progress = PlayerPathFollower.Progress + currentDistance;

	private void ProcessAction()
	{
		if (CurrentFightState == FightState.Movement)
		{
			ProcessMovement();
			return;
		}

		if (CurrentFightState != FightState.Idle)
			return;

		actionTimer = Mathf.MoveToward(actionTimer, 0f, PhysicsManager.physicsDelta);
		if (!Mathf.IsZeroApprox(actionTimer))
			return;

		StartNextAction();
	}

	private void GetNextAction()
	{
		currentActionCharacter = attackPatterns[currentPatternIndex][currentActionIndex];
		currentActionIndex = (currentActionIndex + 1) % attackPatterns[currentPatternIndex].Length;

		GD.Print($"Alf's action was set to {currentActionCharacter}.");
	}

	/// <summary>
	/// Updates animations and sets them off.
	/// </summary>
	private void StartNextAction()
	{
		GetNextAction();

		if (StartMove()) // Started movement pattern
			return;
	}

	private bool StartMove()
	{
		switch (currentActionCharacter)
		{
			case 'B':
				targetDistance = BombDistance;
				break;
			case 'F':
				targetDistance = FarDistance;
				break;
			case 'M':
				targetDistance = NormalDistance;
				break;
			case 'C':
				targetDistance = CloseDistance;
				break;
			default:
				return false;
		}

		initialDistance = currentDistance; // Store the current distance

		if (Mathf.IsEqualApprox(initialDistance, targetDistance)) // No movement needed-skip
			return false;

		// Start Animation
		bool isAdvancing = initialDistance > targetDistance;
		MoveStatePlayback.Travel(isAdvancing ? "advance-start" : "retreat-start");
		currentMovementCurve = isAdvancing ? advanceMovementCurve : retreatMovementCurve;
		CurrentFightState = FightState.Movement;
		movementSample = 0f;

		return true;
	}

	private void ProcessMovement()
	{
		GD.PrintT(movementSample, currentMovementCurve.MaxDomain);

		if (Mathf.IsEqualApprox(movementSample, currentMovementCurve.MaxDomain))
		{
			CurrentFightState = FightState.Idle;
			return;
		}

		movementSample = Mathf.MoveToward(movementSample, currentMovementCurve.MaxDomain, PhysicsManager.physicsDelta);
		float t = currentMovementCurve.Sample(movementSample);

		if (Mathf.IsEqualApprox(t, 1.0f))
		{
			MoveStatePlayback.Travel("idle");
			actionTimer = 1f;
		}

		currentDistance = Mathf.Lerp(initialDistance, targetDistance, t);
	}
}

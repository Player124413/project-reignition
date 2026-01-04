using Godot;
using Project.Core;
using Project.Gameplay.Triggers;

namespace Project.Gameplay.Bosses;

public partial class AlfLayla : Node3D
{
	[ExportGroup("Components")]
	[Export] private AnimationTree animationTree;
	[Export] private CameraTrigger cutsceneCamera;
	[Export] private LockoutTrigger autorunLockout;

	[Export] private SpiritBomb spiritBomb;

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
		Stunned,
		Defeated,
	}

	[ExportGroup("Movement Settings")]
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
	private readonly string SlashType = "parameters/slash-type-transition/transition_request";
	private readonly string SlashTrigger = "parameters/slash-trigger/request";
	private readonly string SlashSpeed = "parameters/slash-speed/scale";
	private readonly string SixOrbTrigger = "parameters/six-orb-trigger/request";
	private readonly string SixOrbSpeed = "parameters/six-orb-speed/scale";
	private readonly string SpiritBombTrigger = "parameters/spirit-bomb-trigger/request";
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

				GlobalTransform = PlayerPathFollower.GlobalTransform;
				ResetPhysicsInterpolation();
				return;
		}

		if (CurrentFightState == FightState.Stunned)
			return;

		SnapPosition();
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
		SnapPosition();

		Player.Camera.LookaroundAmount = Vector2.Zero;

		Transform = Transform3D.Identity;
		ResetPhysicsInterpolation();

		// TODO Reset Animations
	}

	private void StartIntroduction()
	{
		StageSettings.Player.KnockbackFinished += FinishAttack; // Finish the spirit bomb attack after the player gets up
		spiritBomb.AlfExploded += StartHitstun;

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
		autorunLockout.Activate();

		Respawn();
		Player.Skills.EnableBreakSkills();
		TransitionManager.FinishTransition();
		Interface.PauseMenu.AllowInputs = true;
		HeadsUpDisplay.Instance.SetVisibility(true);
	}

	private readonly Vector3 VisualOffset = Vector3.Down * 5f;
	/// <summary> Snaps Alf's position to the correct position. </summary>
	private void SnapPosition()
	{
		GlobalPosition = PlayerPathFollower.GlobalPosition + PlayerPathFollower.Forward() * currentDistance + VisualOffset;
		GlobalRotation = Vector3.Zero;
	}


	private void ProcessAction()
	{
		if (CurrentFightState == FightState.Movement)
		{
			ProcessMovement();
			return;
		}

		if (CurrentFightState == FightState.Stunned)
		{
			ProcessStun();
			return;
		}

		if (CurrentFightState == FightState.AttackWindup || CurrentFightState == FightState.AttackStrike)
		{
			ProcessAttack();
			return;
		}

		if (CurrentFightState != FightState.Idle || spiritBomb.IsTravelling)
			return;

		if (!ProcessActionTimer())
			return;

		StartNextAction();
	}

	private bool ProcessActionTimer()
	{
		actionTimer = Mathf.MoveToward(actionTimer, 0f, PhysicsManager.physicsDelta);
		return Mathf.IsZeroApprox(actionTimer);
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

		StartAttack();
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
		if (Mathf.IsEqualApprox(movementSample, currentMovementCurve.MaxDomain))
			return;

		movementSample = Mathf.MoveToward(movementSample, currentMovementCurve.MaxDomain, PhysicsManager.physicsDelta);
		float t = currentMovementCurve.Sample(movementSample);

		if (Mathf.IsEqualApprox(t, 1.0f))
			MoveStatePlayback.Travel("idle");

		currentDistance = Mathf.Lerp(initialDistance, targetDistance, t);
	}

	private void FinishMovement()
	{
		CurrentFightState = FightState.Idle;
		actionTimer = 1f;
	}

	private void StartAttack()
	{
		switch (currentActionCharacter)
		{
			case '6':
				actionTimer = 0.5f;
				break;
			case '\\':
			case '>':
			case '|':
				animationTree.Set(SlashType, "right");
				actionTimer = 2f;
				animationTree.Set(SlashSpeed, 1.2f);
				break;
			case '/':
			case '<':
			case '_':
				animationTree.Set(SlashType, "left");
				animationTree.Set(SlashSpeed, 1.2f);
				actionTimer = 0.5f;
				break;
			case 'X':
			case '#':
				animationTree.Set(SlashType, "middle");
				animationTree.Set(SlashSpeed, 1.5f);
				actionTimer = 0.5f;
				break;
			case 'B':
				animationTree.Set(SpiritBombTrigger, (uint)AnimationNodeOneShot.OneShotRequest.Fire);
				spiritBomb.Respawn();
				break;
			default: // Unimplmented
				GD.Print($"Action {currentActionCharacter} is not implemented!");
				return;
		}

		CurrentFightState = FightState.AttackWindup;
	}

	private void ProcessAttack()
	{
		if (CurrentFightState != FightState.AttackWindup || !ProcessActionTimer())
			return;

		CurrentFightState = FightState.AttackStrike;
		switch (currentActionCharacter)
		{
			case '6':
				animationTree.Set(SixOrbTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);
				break;
			case '\\':
			case '/':
			case '>':
			case '<':
			case 'X':
			case '#':
			case '|':
			case '_':
				animationTree.Set(SlashTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);
				break;
			case 'B':
				break;
			default: // Unimplmented
				FinishAttack();
				return;
		}
	}

	private void FinishAttack()
	{
		switch (currentActionCharacter)
		{
			case '6':
				actionTimer = 2f;
				break;
			default:
				actionTimer = 0.1f;
				break;
		}

		CurrentFightState = FightState.Idle;
	}

	/// <summary> Release the spirit bomb from Alf's hands and have it start flying. </summary>
	private void LaunchSpiritBomb() => spiritBomb.StartTravelling();

	private readonly string StunTransition = "parameters/stun-transition/transition_request";
	private readonly string StunPlaybackPath = "parameters/stun-state/playback";
	private AnimationNodeStateMachinePlayback StunPlayback => (AnimationNodeStateMachinePlayback)animationTree.Get(StunPlaybackPath);
	/// <summary> Called when the spirit bomb explodes on Alf. </summary>
	private void StartHitstun()
	{
		CurrentFightState = FightState.Stunned;
		StunPlayback.Start("stun-start");
		animationTree.Set(StunTransition, "enabled");
		actionTimer = MaxStunLength;
	}

	private readonly float MaxStunLength = 20f;
	private void ProcessStun()
	{
		actionTimer = Mathf.MoveToward(actionTimer, 0, PhysicsManager.physicsDelta);
		if (Mathf.IsZeroApprox(actionTimer))
			FinishStun();
	}

	private void FinishStun()
	{
		currentDistance = Mathf.Abs(Player.GlobalPosition.Z - GlobalPosition.Z);
		actionTimer = 1f;
		StunPlayback.Travel("stun-stop");
		CurrentFightState = FightState.Idle;
	}
}

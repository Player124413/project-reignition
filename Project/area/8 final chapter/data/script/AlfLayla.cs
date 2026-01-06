using Godot;
using Project.Core;
using Project.Gameplay.Objects;
using Project.Gameplay.Triggers;

namespace Project.Gameplay.Bosses;

public partial class AlfLayla : Node3D
{
	[ExportGroup("Components")]
	[Export] private AnimationTree animationTree;
	[Export] private CameraTrigger cutsceneCamera;
	[Export] private LockoutTrigger autorunLockout;
	[Export] private Node3D strikeParent;

	[Export] private SpiritBomb spiritBomb;

	[Export] private DialogTrigger[] dialogTriggers;

	[Export] private AlfSlash[] slashControllers;

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
	private readonly float CloseDistance = 10.0f;

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
		autorunLockout.Activate();
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

		foreach (AlfSlash slash in slashControllers)
			slash.Respawn();
		// TODO Reset Animations
	}

	private void StartIntroduction()
	{
		StageSettings.Player.KnockbackFinished += OnPlayerKnockbackFinished; // Finish the spirit bomb attack after the player gets up
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
		strikeParent.GlobalPosition = Vector3.Back * Player.PathFollower.GlobalPosition.Z;
	}

	private void ProcessAction()
	{
		if (spiritBomb.IsTravelling || Player.IsSpiritBombActive) // Idle when spirit bomb is active
			return;

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

		if (CurrentFightState == FightState.AttackWindup)
		{
			ProcessAttackWindup();
			return;
		}

		if (CurrentFightState == FightState.AttackStrike)
			return;

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

		// Allow the player to interupt movement patterns with a bomb
		if (Player.Skills.IsSoulGaugeFilled &&
			(currentActionCharacter == 'F' || currentActionCharacter == 'C' || currentActionCharacter == 'M'))
		{
			currentActionCharacter = 'B';
		}
		else // Otherwise, increment the action index
		{
			currentActionIndex = (currentActionIndex + 1) % attackPatterns[currentPatternIndex].Length;
		}

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

		StartAttackWindup();
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
		if (currentActionCharacter == 'B') // Start bomb attack
		{
			StartAttackWindup();
			actionTimer = 0.8f;
			return;
		}

		actionTimer = 0.3f;
		CurrentFightState = FightState.Idle;
	}

	private void StartAttackWindup()
	{
		float slashSpeed = 1.2f;
		if (currentPatternIndex == 2)
			slashSpeed = 1.5f;

		// Update the delay for each attack as needed below
		switch (currentActionCharacter)
		{
			case '\\':
			case '>':
			case '|':
				actionTimer = 1f;
				animationTree.Set(SlashType, "right");
				animationTree.Set(SlashSpeed, slashSpeed);
				break;
			case '/':
			case '<':
			case '_':
				actionTimer = 0.2f;
				animationTree.Set(SlashType, "left");
				animationTree.Set(SlashSpeed, slashSpeed);
				break;
			case 'X':
			case '#':
				actionTimer = 0.5f;
				animationTree.Set(SlashType, "middle");
				animationTree.Set(SlashSpeed, slashSpeed * 1.5f);
				break;
			case 'B':
				actionTimer = 0.2f;
				break;
			default: // No windup
				actionTimer = 0f;
				break;
		}

		CurrentFightState = FightState.AttackWindup;
	}

	private void ProcessAttackWindup()
	{
		if (!ProcessActionTimer())
			return;

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
				animationTree.Set(SpiritBombTrigger, (uint)AnimationNodeOneShot.OneShotRequest.Fire);
				spiritBomb.Respawn();
				break;
			default: // Unimplmented
				GD.Print($"Action {currentActionCharacter} is not implemented!");
				FinishAttack();
				return;
		}

		CurrentFightState = FightState.AttackStrike;
	}

	/// <summary> Activate the slashes. </summary>
	public void StartSlashAttack()
	{
		switch (currentActionCharacter)
		{
			case '\\':
				slashControllers[0].Activate();
				break;
			case '/':
				slashControllers[1].Activate();
				break;
			case '>':
				slashControllers[2].Activate();
				break;
			case '<':
				slashControllers[3].Activate();
				break;
			case 'X':
				slashControllers[4].Activate();
				break;
			case '#':
				slashControllers[5].Activate();
				break;
			case '|':
				slashControllers[6].Activate();
				break;
			case '_':
				slashControllers[7].Activate();
				break;
		}
	}

	private void OnPlayerKnockbackFinished()
	{
		if (currentActionCharacter != 'B')
			return;

		FinishAttack();
	}

	private void FinishAttack()
	{
		switch (currentActionCharacter)
		{
			case '6':
				actionTimer = 1f;
				break;
			case '<':
				actionTimer = 1f;
				break;
			default:
				actionTimer = 0.1f;
				break;
		}

		CurrentFightState = FightState.Idle;
	}

	/// <summary> Release the spirit bomb from Alf's hands and have it start flying. </summary>
	private void LaunchSpiritBomb() => spiritBomb.StartTravelling();

	public bool IsStunned => CurrentFightState == FightState.Stunned;
	private readonly string StunTransition = "parameters/stun-transition/transition_request";
	private readonly string StunPlaybackPath = "parameters/stun-state/playback";
	private readonly string StunDamageTrigger = "parameters/stun-damage-trigger/request";
	private readonly string StunDamageFinalTrigger = "parameters/stun-damage-final-trigger/request";
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
		if (Player.IsMultiPunchActive) // Use timer in player state instead
			return;

		actionTimer = Mathf.MoveToward(actionTimer, 0, PhysicsManager.physicsDelta);
		if (Mathf.IsZeroApprox(actionTimer))
			FinishStun();
	}

	private void FinishStun()
	{
		// TODO Add a camera cut to hide this teleportation
		currentDistance = CloseDistance;
		SnapPosition();

		actionTimer = 1f;
		StunPlayback.Travel("stun-stop");
		CurrentFightState = FightState.Idle;
	}

	public void FinishMultiPunch()
	{
		// TODO Check for world ring explosions
		FinishStun();
		GD.Print("Checking for explosions.");
	}

	// Play a super cool animation
	public void StartFinalMultiPunch() => animationTree.Set(StunDamageFinalTrigger, (uint)AnimationNodeOneShot.OneShotRequest.Fire);

	public void TakeDamage()
	{
		currentHealth--;
		animationTree.Set(StunDamageTrigger, (uint)AnimationNodeOneShot.OneShotRequest.Fire);
	}
}

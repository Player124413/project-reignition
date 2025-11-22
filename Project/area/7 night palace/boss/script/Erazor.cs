using Godot;
using Project.Core;
using Project.Gameplay.Triggers;

namespace Project.Gameplay.Bosses;

public partial class Erazor : Node3D
{
	[Export] private AnimationTree animationTree;
	[Export] private PathFollow3D bossPathFollower;
	[Export] private CameraTrigger cutsceneCamera;

	[Export] private string[] attackPatterns;
	/// <summary> Tracks the index of the current phase. </summary>
	private int currentAttackPatternIndex;
	/// <summary> Tracks the index character being processed in the current phase. </summary>
	private int currentCharacterIndex;
	/// <summary> Tracks the character being processed in the current phase. </summary>
	private char currentCharacter;

	[Export] private float[] attackDelays;
	[Export] private float[] attackSpeedScales;
	[Export] private float[] teleportDelays;
	[Export] private float[] windupDelays;
	/// <summary> Keeps track of attack intervals and windup times. </summary>
	private float stateTimer;

	/// <summary> Tracks Erazor's current action. </summary>
	private FightState CurrentFightState;
	private enum FightState
	{
		Introduction,
		Idle,
		Teleport,
		Hitstun,
		AttackWindup,
		AttackStrike,
		Duel,
		Defeated,
	}

	private int currentHealth;
	/// <summary> Tracks whether the head hitbox is being interacted with. </summary>
	private bool isHeadHitboxEntered;
	private readonly int MaxHealth = 25;

	/// <summary> Is Erazor far-away from the player? </summary>
	private bool isFarAway;
	/// <summary> Should Erazor track the player's horizontal position? </summary>
	private bool isTrackingHorizontal;
	private float currentDistance;
	private float distanceVelocity;
	private float trackingVelocity;
	/// <summary> The preferred distance when far from the player. </summary>
	private readonly float FarDistance = 30f;
	/// <summary> The preferred distance when attacking the player. </summary>
	private readonly float CloseDistance = 10f;
	private readonly float DistanceSmoothing = 5f;
	/// <summary> The speed at which to track the player horizontally. </summary>
	private readonly float HorizontalTrackingSmoothing = 10f;
	/// <summary> The maximum amount Erazor can track horizontally. </summary>
	private readonly float MaxHorizontalTracking = 5f;

	/// ANIMATION PARAMETERS
	private readonly string IntroCutsceneID = "np_boss_intro";
	private readonly string DefeatCutsceneID = "np_boss_defeat";
	private readonly StringName TeleportTrigger = "parameters/teleport_trigger/request";
	private readonly StringName TeleportSpeed = "parameters/teleport_speed/scale";
	private readonly StringName AttackTrigger = "parameters/attack_trigger/request";
	private readonly StringName AttackPlayback = "parameters/attack_state/playback";
	private readonly StringName AttackSpeed = "parameters/attack_speed/scale";
	private AnimationNodeStateMachinePlayback AttackStatePlayback => animationTree.Get(AttackPlayback).Obj as AnimationNodeStateMachinePlayback;

	private PlayerController Player => StageSettings.Player;
	private PlayerPathController PathFollower => Player.PathFollower;

	public override void _Ready()
	{
		animationTree.Active = true; // Activate animation trees

		StageSettings.Instance.Respawned += Respawn;
		StageSettings.Instance.LevelStarted += StartIntroduction;
	}

	public void Respawn()
	{
		CurrentFightState = FightState.Idle;

		currentHealth = MaxHealth;

		currentAttackPatternIndex = 0;
		currentCharacterIndex = 0;

		isTrackingHorizontal = false;
		bossPathFollower.HOffset = 0;
		trackingVelocity = 0;

		isFarAway = false;
		currentDistance = CloseDistance;
		distanceVelocity = 0;

		bossPathFollower.Progress = PathFollower.Progress + currentDistance;
		Transform = Transform3D.Identity;
		ResetPhysicsInterpolation();

		// Reset Animations
		animationTree.Set(TeleportTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
		animationTree.Set(AttackTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
	}

	private void StartIntroduction()
	{
		GlobalTransform = Transform3D.Identity;
		ResetPhysicsInterpolation();

		cutsceneCamera.Activate();
		Player.Deactivate();
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
		TransitionManager.instance.Connect(TransitionManager.SignalName.TransitionProcess, new Callable(this, MethodName.StartBattle), (uint)ConnectFlags.OneShot);
		SaveManager.ActiveGameData.AllowSkippingCutscene(IntroCutsceneID);
	}

	private void StartBattle()
	{
		cutsceneCamera.Deactivate();

		Respawn();
		TransitionManager.FinishTransition();
		Player.Activate();
	}

	private void StartFinalBlow()
	{
		TransitionManager.StartTransition(new()
		{
			inSpeed = 0f,
			outSpeed = .5f,
			color = Colors.Black
		});
		TransitionManager.FinishTransition();

		Player.Skills.CancelBreakSkills();
		Player.Skills.DisableBreakSkills();
		Player.MoveSpeed = 0;

		Player.Visible = false;
		Player.AddLockoutData(Runtime.Instance.DefaultCompletionLockout);
		Interface.PauseMenu.AllowInputs = false;

		// Award 1000 points for defeating the boss
		BonusManager.instance.QueueBonus(new(BonusType.Boss, 1000));
	}

	private void DefeatBoss()
	{
		cutsceneCamera.Activate();
		// TODO animationTree.Set(DefeatParameter, (int)AnimationNodeOneShot.OneShotRequest.Fire);

		CurrentFightState = FightState.Defeated;
		Player.Deactivate();
	}

	private void FinishDefeat()
	{
		cutsceneCamera.Deactivate();
		// animationTree.Active = false;
		// eventAnimator.Play("finish-defeat");

		Player.Activate();
		StageSettings.Instance.FinishLevel(true);
		SaveManager.ActiveGameData.AllowSkippingCutscene(DefeatCutsceneID);
	}

	public override void _PhysicsProcess(double _)
	{
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
					//eventAnimator.Play("finish-defeat");
					//rootAnimationTree.Set(DefeatSeekParameter, 10);
				}
				return;
		}

		UpdateTimer();
		UpdatePosition();
	}

	public void TakeDamage()
	{
		currentHealth -= CurrentFightState == FightState.Duel ? 6 : 1;

		if (currentHealth <= 0)
		{
			StartFinalBlow();
			return;
		}

		if ((currentAttackPatternIndex == 0 && currentHealth <= 20) || (currentAttackPatternIndex == 1 && currentHealth <= 7))
		{
			// Advance Phase
			currentAttackPatternIndex++;
			currentCharacterIndex = 0;
		}
	}

	private void UpdatePosition()
	{
		if (Player.IsHomingAttacking || CurrentFightState == FightState.Hitstun)
			currentDistance = ExtensionMethods.SmoothDamp(currentDistance, 0, ref distanceVelocity, DistanceSmoothing * PhysicsManager.physicsDelta);

		bossPathFollower.Progress = Player.PathFollower.Progress + currentDistance;


		float targetHorizontalTracking = bossPathFollower.HOffset;
		if (isTrackingHorizontal)
			targetHorizontalTracking = Mathf.Clamp(PathFollower.LocalPlayerPositionDelta.X, -MaxHorizontalTracking, MaxHorizontalTracking);

		bossPathFollower.HOffset = ExtensionMethods.SmoothDamp(bossPathFollower.HOffset,
			targetHorizontalTracking, ref trackingVelocity, HorizontalTrackingSmoothing * PhysicsManager.physicsDelta);
	}

	private void UpdateTimer()
	{
		// Wait for attack animations
		if (CurrentFightState == FightState.AttackWindup && !AttackStatePlayback.GetCurrentNode().ToString().EndsWith("-loop"))
			return;

		stateTimer = Mathf.MoveToward(stateTimer, 0, PhysicsManager.physicsDelta);

		if (!Mathf.IsZeroApprox(stateTimer))
			return;

		switch (CurrentFightState)
		{
			case FightState.Idle:
				ProcessAttackPattern();
				break;
			case FightState.AttackWindup:
				StartAttackStrike();
				break;
		}
	}

	/// <summary> Performs an action based on the character read from the attack pattern string. </summary>
	private void ProcessAttackPattern()
	{
		currentCharacter = attackPatterns[currentAttackPatternIndex][currentCharacterIndex];
		GD.Print("Processing character " + currentCharacter);

		if (currentCharacter == 'd')
		{
			GD.Print("STARTING A DUEL...");
		}
		else if (currentCharacter == 'c' || currentCharacter == 'f')
		{
			StartTeleport();
		}
		else
		{
			if (isFarAway) // Don't process attacks when far away--teleport closer first
			{
				StartTeleport();
				return;
			}

			StartAttackWindup();
		}

		// Queue the next character
		currentCharacterIndex = (currentCharacterIndex + 1) % attackPatterns[currentAttackPatternIndex].Length;
	}

	private void StartTeleport()
	{
		CurrentFightState = FightState.Teleport;
		animationTree.Set(TeleportTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);
	}

	/// <summary> Instantly moves Erazor to his proper position. </summary>
	public void ApplyTeleport()
	{
		isFarAway = currentCharacter == 'f';
		currentDistance = isFarAway ? FarDistance : CloseDistance;
		distanceVelocity = 0;
		isTrackingHorizontal = false;
		bossPathFollower.HOffset = 0;
		trackingVelocity = 0;
	}

	public void FinishTeleport()
	{
		CurrentFightState = FightState.Idle;
		if (currentCharacter == 'f')
			stateTimer = teleportDelays[currentAttackPatternIndex];
	}

	public void StartAttackWindup()
	{
		CurrentFightState = FightState.AttackWindup;

		isTrackingHorizontal = currentCharacter == 'i' || currentCharacter == 'v';
		stateTimer = windupDelays[currentAttackPatternIndex];

		AttackStatePlayback.Start($"attack-{currentCharacter}-start");
		animationTree.Set(AttackSpeed, attackSpeedScales[currentAttackPatternIndex]);
		animationTree.Set(AttackTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);
	}

	private void StartAttackStrike()
	{
		isTrackingHorizontal = false;
		AttackStatePlayback.Start($"attack-{currentCharacter}-strike");
		CurrentFightState = FightState.AttackStrike;
	}

	private void FinishAttackStrike()
	{
		CurrentFightState = FightState.Idle;
		stateTimer = attackDelays[currentAttackPatternIndex];
	}

	public void OnHeadEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isHeadHitboxEntered = true;

		if (Player.IsHomingAttacking)
		{
			TakeDamage();
			Player.StartBounce();
		}
	}

	public void OnHeadExited(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isHeadHitboxEntered = false;
	}
}
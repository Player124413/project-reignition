using Godot;
using Project.Core;
using Project.Gameplay.Triggers;

namespace Project.Gameplay.Bosses;

public partial class Erazor : Node3D
{
	[Signal] public delegate void CutsceneStartedEventHandler();
	[Signal] public delegate void CutsceneFinishedEventHandler();
	[Signal] public delegate void DuelStartedEventHandler();

	[Export] private AnimationTree animationTree;
	[Export] private PathFollow3D bossPathFollower;
	[Export] private CameraTrigger cutsceneCamera;
	[Export] private CameraTrigger duelCamera;
	[Export] private CameraSettingsResource normalCameraResource;
	[Export] private CameraSettingsResource duelCameraResource;
	[Export] private LockoutTrigger recenterLockout;
	[Export] private LockoutTrigger stopLockout;

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
		DuelHitstun,
		Defeated,
	}

	private int currentHealth;
	/// <summary> Tracks whether the head hitbox is being interacted with. </summary>
	private bool isInteractingWithPlayer;
	/// <summary> True when a particular playerinteraction has already been processed. </summary>
	private bool isInteractionProcessed;
	/// <summary> How long it's been since Erazor last interacted with the player. </summary>
	private float timeSinceLastInteraction;
	/// <summary> How long an interaction can last before being "reset". </summary>
	private readonly float MaxInteractionLength = .2f;
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
	private readonly float CloseDistance = 9f;
	/// <summary> Use more smoothing to allow evasion via backflips. </summary>
	private readonly float BackflipSmoothing = 5f;
	/// <summary> Snappy smoothing to ensure attacks connect. </summary>
	private readonly float DistanceSmoothing = 1f;
	/// <summary> The speed at which to track the player horizontally. </summary>
	private readonly float HorizontalTrackingSmoothing = 10f;
	/// <summary> The maximum amount Erazor can track horizontally. </summary>
	private readonly float MaxHorizontalTracking = 5f;
	/// <summary> How fast to move towards the player during the duel. </summary>
	private readonly float DuelSpeed = 60f;
	private readonly float DuelDistance = 60f;
	/// <summary> The distance at which the Duel Slash comes out. </summary>
	private readonly float SlashDistance = 8f;
	/// <summary> The distance at which the Duel Windup comes out. </summary>
	private readonly float DuelWindupDistance = 25f;
	/// <summary> How long before Erazor lunges towards Sonic in the duel. Retail is 6 seconds. </summary>
	private readonly float DuelAttackStartup = 5f;

	/// ANIMATION PARAMETERS
	private readonly string IntroCutsceneID = "np_boss_intro";
	private readonly string DefeatCutsceneID = "np_boss_defeat";
	private readonly StringName IntroductionTrigger = "parameters/introduction_trigger/request";
	private readonly StringName DefeatTrigger = "parameters/defeat_trigger/request";
	private readonly StringName DefeatSeek = "parameters/defeat_seek/seek_request";
	private readonly StringName TeleportTrigger = "parameters/teleport_trigger/request";
	private readonly StringName TeleportSpeed = "parameters/teleport_speed/scale";
	private readonly StringName AttackTrigger = "parameters/attack_trigger/request";
	private readonly StringName AttackPlayback = "parameters/attack_state/playback";
	private readonly StringName AttackSpeed = "parameters/attack_speed/scale";
	private readonly StringName DamageTrigger = "parameters/damage_trigger/request";
	private AnimationNodeStateMachinePlayback AttackStatePlayback => animationTree.Get(AttackPlayback).Obj as AnimationNodeStateMachinePlayback;

	private PlayerController Player => StageSettings.Player;
	private PlayerPathController PlayerPathFollower => Player.PathFollower;

	public override void _Ready()
	{
		animationTree.Active = true; // Activate animation trees

		StageSettings.Instance.RespawnedEnemies += Respawn;
		StageSettings.Instance.LevelStarted += StartIntroduction;
	}

	public void Respawn()
	{
		cutsceneCamera.Deactivate();
		duelCamera.Deactivate();
		recenterLockout.Deactivate();
		stopLockout.Deactivate();
		Player.Animator.CancelOneshot();

		CurrentFightState = FightState.Idle;

		currentHealth = MaxHealth;

		currentAttackPatternIndex = 0;
		currentCharacterIndex = 0;

		isTrackingHorizontal = false;
		bossPathFollower.HOffset = 0;
		trackingVelocity = 0;

		isFarAway = false;
		currentDistance = CloseDistance;
		SnapDistance();

		cameraVelocity = 0f;
		lookaroundVelocity = Vector2.Zero;
		Player.Camera.LookaroundAmount = Vector2.Zero;

		Transform = Transform3D.Identity;
		ResetPhysicsInterpolation();

		// Reset Animations
		animationTree.Set(IntroductionTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
		animationTree.Set(DefeatTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
		animationTree.Set(TeleportTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
		animationTree.Set(AttackTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
		animationTree.Set(DamageTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
	}

	private void StartIntroduction()
	{
		GlobalTransform = Player.GlobalTransform;
		ResetPhysicsInterpolation();

		animationTree.Set(IntroductionTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);
		cutsceneCamera.Activate();
		Interface.PauseMenu.AllowInputs = false;
		HeadsUpDisplay.Instance.SetVisibility(false);
		Player.Skills.DisableBreakSkills();
		Player.Animator.PlayOneshotAnimation(IntroCutsceneID);
		stopLockout.Activate();

		EmitSignal(SignalName.CutsceneStarted);
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
		animationTree.Set(IntroductionTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
		Player.Animator.CancelOneshot();

		EmitSignal(SignalName.CutsceneFinished);
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
		Player.SnapToGround();
		Player.Effect.CanelSpinFX();
		Player.Effect.StopTrailFX();
		Player.Animator.ResetState(0.0f);
		Player.Animator.PlayOneshotAnimation(DefeatCutsceneID);
		Player.AddLockoutData(Runtime.Instance.DefaultCompletionLockout);
		Interface.PauseMenu.AllowInputs = false;
		HeadsUpDisplay.Instance.SetVisibility(false);

		cutsceneCamera.Activate();
		animationTree.Set(DefeatTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);

		CurrentFightState = FightState.Defeated;

		// Award 1000 points for defeating the boss
		BonusManager.instance.QueueBonus(new(BonusType.Boss, 1000));
		EmitSignal(SignalName.CutsceneStarted);
	}

	private void FinishDefeat()
	{
		cutsceneCamera.Deactivate();

		animationTree.Set(DefeatSeek, 16.5f);
		animationTree.SetDeferred("active", false);

		Player.Animator.CancelOneshot();

		StageSettings.Instance.FinishLevel(true);
		SaveManager.ActiveGameData.AllowSkippingCutscene(DefeatCutsceneID);
		EmitSignal(SignalName.CutsceneFinished);
	}

	public override void _PhysicsProcess(double _)
	{
		UpdateDamage();
		UpdateCameras();

		switch (CurrentFightState)
		{
			case FightState.Duel:
				UpdateDuel();
				GlobalTransform = bossPathFollower.GlobalTransform;
				return;
			case FightState.DuelHitstun:
				GlobalTransform = bossPathFollower.GlobalTransform;
				return;
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
					FinishDefeat();
				}

				bossPathFollower.Progress = PlayerPathFollower.Progress;
				GlobalTransform = bossPathFollower.GlobalTransform;
				ResetPhysicsInterpolation();
				return;
		}

		GlobalTransform = bossPathFollower.GlobalTransform;
		UpdateTimer();
		UpdatePosition();
	}

	private void UpdateDamage()
	{
		if (!isInteractingWithPlayer)
			return;

		if (CurrentFightState == FightState.DuelHitstun)
			return;

		TakeDamage();
	}

	public void TakeDamage()
	{
		if (CurrentFightState == FightState.Defeated)
			return;

		if (isInteractionProcessed)
		{
			timeSinceLastInteraction += PhysicsManager.physicsDelta;
			if (timeSinceLastInteraction < MaxInteractionLength)
				return;

			ResetInteractionProcessed();
		}

		if (CurrentFightState == FightState.Duel)
			currentHealth -= 6;
		else
			currentHealth -= Player.AttackState == PlayerController.AttackStates.Strong ? 2 : 1;

		GD.Print($"Erazor's Health is now {currentHealth}");

		if (currentHealth <= 0)
		{
			StartFinalBlow();
			return;
		}

		if (CurrentFightState == FightState.Duel)
		{
			StartDuelResultAnimation(true);
		}
		else
		{
			if (CurrentFightState != FightState.Hitstun)
			{
				animationTree.Set(DamageTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);
				animationTree.Set(AttackTrigger, (int)AnimationNodeOneShot.OneShotRequest.FadeOut);
				CurrentFightState = FightState.Hitstun;
			}

			Player.StartBounce();
		}

		SetInteractionProcessed();

		if ((currentAttackPatternIndex == 0 && currentHealth <= 20) || (currentAttackPatternIndex == 1 && currentHealth <= 7))
		{
			// Advance Phase
			currentAttackPatternIndex++;
			currentCharacterIndex = 0;

			GD.Print($"Advanced Phase to {currentAttackPatternIndex}.");
		}
	}

	private void FinishHitstun()
	{
		// Cram in a far teleport into the pattern so Erazor doesn't shift in front of the player
		if (attackPatterns[currentAttackPatternIndex][currentCharacterIndex] != 'f')
		{
			currentCharacter = 'f';
			StartTeleport();
			return;
		}

		CurrentFightState = FightState.Idle;
	}

	private void SetInteractionProcessed()
	{
		isInteractionProcessed = true;
		timeSinceLastInteraction = 0;
		Player.AttackStateChanged += ResetInteractionProcessed;
	}

	private void ResetInteractionProcessed()
	{
		isInteractionProcessed = false;
		timeSinceLastInteraction = 0;
		Player.AttackStateChanged -= ResetInteractionProcessed;
	}

	private void UpdatePosition()
	{
		float targetProgress = PlayerPathFollower.Progress + currentDistance;
		float smoothing = DistanceSmoothing;
		if (Player.IsHomingAttacking || CurrentFightState == FightState.Hitstun || PlayerPathFollower.IsAheadOfPoint(GlobalPosition))
			targetProgress = bossPathFollower.Progress;

		if (Player.IsBackflipping &&
			CurrentFightState == FightState.AttackStrike &&
			ExtensionMethods.DotAngle(Player.MovementAngle, Player.PathFollower.ForwardAngle) < -0.5f)
		{
			smoothing = BackflipSmoothing;
		}

		bossPathFollower.Progress = ExtensionMethods.SmoothDamp(bossPathFollower.Progress, targetProgress, ref distanceVelocity, smoothing * PhysicsManager.physicsDelta);

		float targetHorizontalTracking = bossPathFollower.HOffset;
		if (isTrackingHorizontal)
			targetHorizontalTracking = Mathf.Clamp(PlayerPathFollower.LocalPlayerPositionDelta.X, -MaxHorizontalTracking, MaxHorizontalTracking);

		bossPathFollower.HOffset = ExtensionMethods.SmoothDamp(bossPathFollower.HOffset,
			targetHorizontalTracking, ref trackingVelocity, HorizontalTrackingSmoothing * PhysicsManager.physicsDelta);

		GlobalTransform = bossPathFollower.GlobalTransform;
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
			StartDuel();
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
		SnapDistance();

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

	public void StartDuel()
	{
		CurrentFightState = FightState.Duel;
		AttackStatePlayback.Start($"attack-d-charge");
		animationTree.Set(AttackSpeed, 1f);
		animationTree.Set(AttackTrigger, (int)AnimationNodeOneShot.OneShotRequest.Fire);

		// Quick Transition
		TransitionManager.StartTransition(new()
		{
			inSpeed = 0f,
			outSpeed = .2f,
			color = Colors.Black
		});
		TransitionManager.FinishTransition();
		duelCamera.Activate();
		duelCameraResource.distance = DuelInitialDistance;
		recenterLockout.Activate();
		currentDistance = DuelDistance;
		SnapDistance();

		stateTimer = DuelAttackStartup;
		EmitSignal(SignalName.DuelStarted);
	}

	public void UpdateDuel()
	{
		stateTimer = Mathf.MoveToward(stateTimer, 0, PhysicsManager.physicsDelta);
		if (Mathf.IsZeroApprox(stateTimer))
		{
			currentDistance = Mathf.MoveToward(currentDistance, 0, DuelSpeed * PhysicsManager.physicsDelta);

			if (currentDistance <= DuelWindupDistance)
				AttackStatePlayback.Travel("attack-d-windup");
		}

		bossPathFollower.Progress = PlayerPathFollower.Progress + currentDistance;
		if (currentDistance <= SlashDistance && !Player.IsHomingAttacking)
			StartDuelResultAnimation(false);
	}

	private void StartDuelResultAnimation(bool isSuccess)
	{
		if (isSuccess)
			AttackStatePlayback.Start($"attack-d-damage");
		else
			StartAttackStrike();

		Player.MoveSpeed = 0;
		Player.SnapToGround();
		Player.Skills.CancelBreakSkills();
		Player.Skills.DisableBreakSkills();
		stopLockout.Activate();

		cutsceneCamera.Activate();
		currentDistance = 0f;
		SnapDistance();

		// Play special animation for Sonic
		if (isSuccess)
		{
			Player.StateMachine.ResetStateMachine();
			Player.Animator.PlayOneshotAnimation("np_duel_success");
			CurrentFightState = FightState.DuelHitstun;
		}
		else
		{
			Player.TakeDamage();
			Player.StartInvincibility();
			Player.Animator.PlayOneshotAnimation("np_duel_fail");
		}

		if (Player.IsDefeated)
			return;

		TransitionManager.StartTransition(new()
		{
			inSpeed = 0f,
			outSpeed = .2f,
			color = Colors.Black
		});
		TransitionManager.FinishTransition();
	}

	public void FinishDuel()
	{
		CurrentFightState = FightState.Idle;
		stateTimer = 0f;

		TransitionManager.StartTransition(new()
		{
			inSpeed = 0f,
			outSpeed = .2f,
			color = Colors.Black
		});
		TransitionManager.FinishTransition();

		// Reset animations
		animationTree.Set(AttackTrigger, (int)AnimationNodeOneShot.OneShotRequest.Abort);
		currentDistance = CloseDistance;
		SnapDistance();
		Player.Animator.CancelOneshot();
		Player.Skills.EnableBreakSkills();

		cutsceneCamera.Deactivate();
		recenterLockout.Deactivate();
		stopLockout.Deactivate();
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

	public void FinishAttackStrike()
	{
		CurrentFightState = FightState.Idle;
		stateTimer = attackDelays[currentAttackPatternIndex];
	}

	/// <summary> Snaps Erazor's distance to currentDistance. </summary>
	private void SnapDistance()
	{
		distanceVelocity = 0;
		bossPathFollower.Progress = PlayerPathFollower.Progress + currentDistance;
	}

	private float cameraVelocity;
	private Vector2 lookaroundVelocity;
	private readonly float CameraSmoothing = 10f;
	private readonly float DuelCloseDistance = 5f;
	private readonly float DuelFarDistance = 40f;
	private readonly float DuelInitialDistance = 40f;
	private readonly float CloseLookaroundAmount = Mathf.Pi * 0.05f;
	private readonly float HorizontalTrackingLookaroundAmount = Mathf.Pi * 0.05f;
	private readonly Vector2 DuelFarOffset = new(30f, 10f);
	private readonly Vector2 DuelCloseOffset = new(0f, 2f);
	private void UpdateCameras()
	{
		Vector2 targetCameraLookaround = Vector2.Zero;

		if (CurrentFightState == FightState.Duel)
		{
			float factor = Mathf.SmoothStep(0f, 1f, currentDistance / DuelDistance);
			float targetDistance = Mathf.Lerp(DuelCloseDistance, DuelFarDistance, factor);
			Vector2 targetOffset = DuelCloseOffset.Lerp(DuelFarOffset, factor);
			duelCameraResource.distance = targetDistance;
			duelCameraResource.viewportOffset = targetOffset;
		}

		if (!isFarAway && CurrentFightState != FightState.Introduction && CurrentFightState != FightState.Defeated)
		{
			float rotationFactor = (PlayerPathFollower.LocalPlayerPositionDelta.X - bossPathFollower.HOffset) / MaxHorizontalTracking;
			targetCameraLookaround.X = HorizontalTrackingLookaroundAmount * rotationFactor;

			if (!Player.IsHomingAttacking && CurrentFightState != FightState.Hitstun)
				targetCameraLookaround.Y = CloseLookaroundAmount;
		}

		Player.Camera.LookaroundAmount = Player.Camera.LookaroundAmount.SmoothDamp(targetCameraLookaround,
			ref lookaroundVelocity, CameraSmoothing * PhysicsManager.physicsDelta);
	}

	public void PlayScreenShake(float magnitude)
	{
		StageSettings.Player.Camera.StartCameraShake(new()
		{
			magnitude = Vector3.One.RemoveDepth() * magnitude,
		});
	}

	public void OnHeadEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = true;
		UpdateDamage();
	}

	public void OnHeadExited(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = false;
	}
}
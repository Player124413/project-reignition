using Godot;
using Project.Core;

namespace Project.Gameplay;

public partial class SlideState : PlayerState
{
	[Export] private PlayerState runState;
	[Export] private PlayerState crouchState;
	[Export] private PlayerState jumpState;
	[Export] private PlayerState backflipState;
	[Export] private PlayerState fallState;
	[Export] private PlayerState homingAttackState;
	/// <summary> Maximum amount the player can turn when sliding. </summary>
	private readonly float MaxTurningAdjustment = Mathf.Pi * .4f;

	public override void EnterState()
	{
		if (!SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.ChargeJump))
		{
			// Only add initial slide speed for normal sliding
			if (Player.MoveSpeed <= Player.Stats.InitialSlideSpeed)
				Player.MoveSpeed = Player.Stats.InitialSlideSpeed;

			// So the SlideSFX can be synced to the ChargeFX
			Player.Effect.PlayActionSFX(Player.Effect.SlideSfx);
		}

		Player.DisableSidle = true;
		Player.Animator.StartSliding();
		Player.Effect.StartDust();
		Player.ChangeHitbox("slide");

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.SlideDefense))
		{
			Player.DisableDamage = true;
			Player.Effect.StartAegisFX();
		}

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.SlideAttack))
		{
			Player.Effect.PlayFireFX();
			Player.Effect.StartVolcanoFX();
			Player.AttackState = PlayerController.AttackStates.Weak;
			Player.ChangeHitbox("volcano-slide");
		}

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.SlideExp))
		{
			Player.Skills.StartSoulSlide();
			Player.Effect.StartSoulSlideFX();
			Player.Effect.PlayDarkSpiralFX();
		}
	}

	public override void ExitState()
	{
		Player.DisableSidle = false;
		Player.ChangeHitbox("RESET");
		Player.Effect.StopDust();

		if (!Player.IsDrifting &&
			Player.StateMachine.QueuedState != jumpState &&
			Player.StateMachine.QueuedState != crouchState)
		{
			Player.Skills.ConsumeJumpCharge();
		}

		if (!Mathf.IsZeroApprox(Player.MoveSpeed))
			Player.Animator.CrouchToMoveTransition();

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.SlideDefense))
		{
			Player.DisableDamage = false;
			Player.Effect.StopAegisFX();
		}

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.SlideAttack))
		{
			Player.Effect.StopVolcanoFX();
			Player.AttackState = PlayerController.AttackStates.None;
		}

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.SlideExp))
			Player.Effect.StopSoulSlideFX();
	}

	public override PlayerState ProcessPhysics()
	{
		ProcessMoveSpeed();
		ProcessTurning();
		Player.AddSlopeSpeed(true);
		Player.ApplyMovement();
		Player.CheckWall();
		if (Player.CheckCeiling())
			return null;

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.SlideExp))
			Player.Skills.UpdateSoulSlide();

		if (!Player.CheckGround())
			return fallState;

		if (Player.Skills.IsSpeedBreakActive)
			return runState;

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.ChargeJump))
		{
			Player.Skills.ChargeJump();

			if (Player.Controller.IsBrakePressed())
			{
				Player.Effect.AbortActionSFX(Player.Effect.SlideSfx);
				Player.Skills.ConsumeJumpCharge();
				return runState;
			}
			else if (!Input.IsActionPressed("button_jump"))
			{
				Player.Effect.AbortActionSFX(Player.Effect.SlideSfx);
				return jumpState;
			}
		}
		else if (Player.Controller.IsJumpBufferActive)
		{
			Player.Controller.ResetJumpBuffer();

			if (Player.IsBackflipInputValid())
				return backflipState;

			return jumpState;
		}
		else if (!Input.IsActionPressed("button_action") && !Player.Animator.IsSlideTransitionActive)
		{
			return runState;
		}

		if (Player.Controller.IsAttackBufferActive && Player.Lockon.IsTargetAttackable)
		{
			Player.Controller.ResetAttackBuffer();
			return homingAttackState;
		}

		// Lockout is disabling action button (slides included)
		if (Player.IsLockoutDisablingAction(LockoutResource.ActionFlags.ActionButton))
			return runState;

		if (Mathf.IsZeroApprox(Player.MoveSpeed))
		{
			Player.Animator.SlideToCrouch();
			Player.ChangeHitbox("crouch");
			return crouchState;
		}

		return null;
	}

	protected override void ProcessMoveSpeed()
	{
		Player.Stats.UpdateSlideSpeed(Player.SlopeRatio);

		// Influence speed based on input strength
		float inputAmount = -.5f; // Default to halfway
		float inputStrength = Player.Controller.GetInputStrength();
		float inputAngle = Player.Controller.GetTargetMovementAngle();
		if (Player.Controller.IsHoldingDirection(inputAngle, Player.MovementAngle + Mathf.Pi))
			inputAmount = -(1 + inputStrength) * .5f; // -0.5 to -1
		else if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.Autorun))
			inputAmount = 0;
		else if (Player.Controller.IsHoldingDirection(inputAngle, Player.MovementAngle))
			inputAmount = -(1 - inputStrength) * .5f; // 0 to -0.5
		Player.MoveSpeed = Player.Stats.SlideSettings.UpdateSlide(Player.MoveSpeed, inputAmount);
	}

	protected override float ProcessTargetMovementAngle(float targetMovementAngle)
	{
		targetMovementAngle = base.ProcessTargetMovementAngle(targetMovementAngle);

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.FreeRoam))
			return targetMovementAngle;

		return ExtensionMethods.ClampAngleRange(targetMovementAngle, Player.PathFollower.ForwardAngle, MaxTurningAdjustment);
	}
}

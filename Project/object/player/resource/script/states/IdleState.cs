using Godot;
using Project.Core;

namespace Project.Gameplay;

public partial class IdleState : PlayerState
{
	[Export] private PlayerState runState;
	[Export] private PlayerState backstepState;
	[Export] private PlayerState crouchState;
	[Export] private PlayerState jumpState;
	[Export] private PlayerState backflipState;
	[Export] private PlayerState fallState;
	[Export] private PlayerState homingAttackState;
	[Export] private PlayerState darkspineSpinState;

	public override void EnterState()
	{
		Player.MoveSpeed = 0;
		Player.StrafeSpeed = 0;
	}

	public override PlayerState ProcessPhysics()
	{
		if (Player.IsLockoutActive &&
			Player.ActiveLockoutData.overrideSpeed &&
			Mathf.IsZeroApprox(Player.ActiveLockoutData.speedRatio))
		{
			Player.Animator.IdleAnimation();
			Player.ApplyMovement();
			return null;
		}

		if (Player.Skills.IsSpeedBreakActive)
			return runState;

		if (Player.Controller.IsJumpBufferActive)
		{
			Player.Controller.ResetJumpBuffer();

			if (Player.IsBackflipInputValid())
				return backflipState;

			if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.ChargeJump) &&
				!Player.IsLockoutDisablingAction(LockoutResource.ActionFlags.FullJump))
			{
				return crouchState;
			}

			return jumpState;
		}

		if (!SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.ChargeJump) &&
			Player.Controller.IsActionBufferActive)
		{
			Player.Controller.ResetActionBuffer();
			return crouchState;
		}

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.LightSpeedDash) &&
			Player.Controller.IsLightDashBufferActive && Player.StartLightSpeedDash())
		{
			return null;
		}

		if (Player.Controller.IsAttackBufferActive)
		{
			Player.Controller.ResetAttackBuffer();

			if (Player.Lockon.IsTargetAttackable && !Player.Controller.IsBrakeHeld())
				return homingAttackState;

			if (Player.IsDarkspineSonic)
				return darkspineSpinState;
		}

		float targetInputAngle = Player.Controller.GetTargetInputAngle();
		float targetInputStrength = Player.Controller.GetInputStrength();
		if (SaveManager.ActiveSkillRing.IsAutorunActive && !Player.Controller.IsBrakeHeld())
			Player.IsMovingBackward = Player.Controller.IsHoldingDirection(targetInputAngle, Player.PathFollower.BackAngle);

		if (!Player.CheckGround())
			return fallState;

		Player.CheckWall(CalculateWallCastDirection(targetInputAngle, targetInputStrength));
		if (Player.CheckCeiling())
			return null;

		if (Player.Controller.IsBackTiltActive())
			return backstepState;

		if (!Player.IsOnWall || Player.Controller.IsStrafeModeActive)
		{
			if (Player.IsLockoutActive && Player.ActiveLockoutData.overrideSpeed && !Mathf.IsZeroApprox(Player.ActiveLockoutData.speedRatio))
				return runState;

			bool hasInputStrength = !Mathf.IsZeroApprox(targetInputStrength);
			if (!Player.Controller.IsBrakeHeld() &&
				((SaveManager.ActiveSkillRing.IsAutorunActive && !Player.IsOnWall) || hasInputStrength))
			{
				if (Player.Controller.GetHoldingDistance(targetInputAngle, Player.PathFollower.ForwardAngle) >= 1.0f &&
					hasInputStrength && !SaveManager.ActiveSkillRing.IsFreeRoamActive)
				{
					return backstepState;
				}

				return runState;
			}
		}

		if (!Mathf.IsZeroApprox(Player.MoveSpeed) ||
			(Player.Controller.IsStrafeModeActive && !Mathf.IsZeroApprox(Player.StrafeSpeed)))
		{
			return runState;
		}

		Player.Animator.IdleAnimation();
		Player.ApplyMovement();
		return null;
	}

	private Vector3 CalculateWallCastDirection(float inputAngle, float inputStrength)
	{
		if (!SaveManager.ActiveSkillRing.IsAutorunActive &&
			Mathf.IsZeroApprox(inputStrength))
		{
			return Player.GetMovementDirection();
		}

		float deltaAngle = ExtensionMethods.SignedDeltaAngleRad(inputAngle, Player.PathFollower.ForwardAngle);
		return Player.PathFollower.ForwardAxis.Rotated(Player.UpDirection, deltaAngle);
	}
}

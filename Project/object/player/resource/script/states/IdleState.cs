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

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.Autorun) && !Player.Controller.IsBrakeHeld())
			Player.IsMovingBackward = Player.Controller.IsHoldingDirection(Player.Controller.GetTargetInputAngle(), Player.PathFollower.BackAngle);

		if (!Player.CheckGround())
			return fallState;
		Player.CheckWall(CalculateWallCastDirection());
		if (Player.CheckCeiling())
			return null;

		if (Player.Controller.IsBackTiltActive())
			return backstepState;

		if (!Player.IsOnWall)
		{
			if (Player.IsLockoutActive && Player.ActiveLockoutData.overrideSpeed && !Mathf.IsZeroApprox(Player.ActiveLockoutData.speedRatio))
				return runState;

			bool hasInputStrength = !Mathf.IsZeroApprox(Player.Controller.GetInputStrength());
			if (!Player.Controller.IsBrakeHeld() &&
				(SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.Autorun) || hasInputStrength))
			{
				if (Player.Controller.GetHoldingDistance(Player.Controller.GetTargetInputAngle(), Player.PathFollower.ForwardAngle) >= 1.0f &&
					hasInputStrength && !SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.FreeRoam))
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

	private Vector3 CalculateWallCastDirection()
	{
		if (!SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.Autorun) &&
			Mathf.IsZeroApprox(Player.Controller.GetInputStrength()))
		{
			return Player.GetMovementDirection();
		}

		float targetAngle = Player.Controller.GetTargetMovementAngle();
		float deltaAngle = ExtensionMethods.SignedDeltaAngleRad(targetAngle, Player.PathFollower.ForwardAngle);
		return Player.PathFollower.ForwardAxis.Rotated(Player.UpDirection, deltaAngle);
	}
}

using Godot;
using Project.Core;

namespace Project.Gameplay;

public partial class CrouchState : PlayerState
{
	[Export] private PlayerState idleState;
	[Export] private PlayerState runState;
	[Export] private PlayerState jumpState;
	[Export] private PlayerState backflipState;
	[Export] private PlayerState fallState;
	[Export] private PlayerState homingAttackState;

	public override void EnterState()
	{
		Player.Animator.StartCrouching();
		Player.ChangeHitbox("crouch");
		Player.StrafeSpeed = 0f;
	}

	public override void ExitState()
	{
		Player.ChangeHitbox("RESET");

		if (!Player.IsDrifting &&
			Player.StateMachine.QueuedState != jumpState)
		{
			Player.Skills.ConsumeJumpCharge();
		}

		float inputStrength = Player.Controller.GetInputStrength();
		if (!Mathf.IsZeroApprox(inputStrength) || Player.Skills.IsSpeedBreakActive) // Transition into moving state
		{
			Player.Animator.CrouchToMoveTransition();
			return;
		}

		Player.Animator.StopCrouching();
	}

	public override PlayerState ProcessPhysics()
	{
		Player.MoveSpeed *= .5f;
		Player.ApplyMovement();
		Player.CheckGround();
		if (Player.CheckCeiling())
			return null;

		if (!Player.IsOnGround)
			return fallState;

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.ChargeJump))
		{
			Player.Skills.ChargeJump();
			if (!Input.IsActionPressed("button_jump"))
			{
				if (!Player.Controller.IsBrakeHeld())
					return jumpState;

				Player.Skills.ConsumeJumpCharge();
				return idleState;
			}
		}
		else if (Player.Controller.IsJumpBufferActive)
		{
			Player.Controller.ResetJumpBuffer();

			if (Player.IsBackflipInputValid())
				return backflipState;

			return jumpState;
		}
		else if (!Input.IsActionPressed("button_action") && !Player.Animator.IsCrouchTransitionActive)
		{
			return idleState;
		}

		if (Player.Controller.IsAttackBufferActive && Player.Lockon.IsTargetAttackable && !Player.Controller.IsBrakeHeld())
		{
			Player.Controller.ResetAttackBuffer();
			return homingAttackState;
		}

		if (Player.Skills.IsSpeedBreakActive)
			return runState;

		return null;
	}
}

using Godot;
using Project.Core;

namespace Project.Gameplay;

public partial class AirBoostState : PlayerState
{
	[Export] private PlayerState landState;
	[Export] private PlayerState fallState;

	private float airBoostTimer;
	private readonly float AirBoostLength = 0.2f;

	public override void EnterState()
	{
		airBoostTimer = 0;

		if (ExtensionMethods.DeltaAngleRad(Player.MovementAngle, Player.PathFollower.BackAngle) <= Mathf.Pi * .25f)
			Player.MovementAngle = Player.PathFollower.ForwardAngle;
		else
			Player.MovementAngle = ExtensionMethods.ClampAngleRange(Player.MovementAngle, Player.PathFollower.ForwardAngle, Mathf.Pi * .5f);

		Player.IsMovingBackward = false;
		Player.MoveSpeed = Player.Skills.speedBreakSpeed;
		Player.VerticalSpeed = Runtime.CalculateJumpPower(0.2f);
		Player.Animator.JumpDashAnimation();
		Player.AttackState = PlayerController.AttackStates.OneShot;
	}

	public override void ExitState()
	{
		if (Player.Skills.IsSpeedBreakActive)
			Player.Skills.ToggleSpeedBreak();

		Player.AttackState = PlayerController.AttackStates.None;
	}

	public override PlayerState ProcessPhysics()
	{
		ProcessMoveSpeed();
		ProcessGravity();
		Player.ApplyMovement();
		Player.CheckGround();
		Player.CheckWall(Vector3.Zero, false);
		if (Player.CheckCeiling())
			return null;
		Player.UpdateUpDirection(true, Player.PathFollower.HeightAxis);

		if (Player.IsOnGround)
			return landState;

		airBoostTimer = Mathf.MoveToward(airBoostTimer, AirBoostLength, PhysicsManager.physicsDelta);
		if (Mathf.IsEqualApprox(airBoostTimer, AirBoostLength))
			return fallState;

		return null;
	}

	protected override void ProcessMoveSpeed()
	{
		float inputAngle = Player.Controller.GetTargetInputAngle();
		float inputStrength = Player.Controller.GetInputStrength();

		if (Player.Controller.IsHoldingDirection(inputAngle, Player.PathFollower.ForwardAngle) ||
			Player.Controller.IsBrakeHeld())
		{
			Player.MoveSpeed = Player.Stats.BackflipSettings.UpdateInterpolate(Player.MoveSpeed, -1);
			return;
		}

		if (Player.Controller.IsHoldingDirection(inputAngle, Player.PathFollower.BackAngle))
			Player.MoveSpeed = Player.Stats.BackflipSettings.UpdateInterpolate(Player.MoveSpeed, inputStrength);
		else if (Mathf.IsZeroApprox(inputStrength))
			Player.MoveSpeed = Player.Stats.BackflipSettings.UpdateInterpolate(Player.MoveSpeed, 0);
	}

	protected override void ProcessTurning()
	{
		float pathControlAmount = Player.Controller.CalculatePathControlAmount();
		float targetMovementAngle = Player.Controller.GetTargetMovementAngle() + pathControlAmount;
		if (DisableTurning(targetMovementAngle))
			return;

		// Use GroundSettings so backstep turning feels consistent with the run state
		float speedRatio = Player.Stats.GroundSettings.GetSpeedRatioClamped(Player.MoveSpeed);
		float turnSmoothing = Mathf.Lerp(Player.Stats.MinTurnAmount, Player.Stats.MaxTurnAmount, speedRatio);
		Player.MovementAngle = ExtensionMethods.SmoothDampAngle(Player.MovementAngle + Player.PathTurnInfluence, targetMovementAngle, ref turningVelocity, turnSmoothing);
	}

	protected override bool DisableTurning(float targetMovementAngle)
	{
		if (Player.IsLockoutActive &&
			Player.ActiveLockoutData.movementMode == LockoutResource.MovementModes.Replace) // Direction is being overridden
		{
			Player.MovementAngle = targetMovementAngle;
			return true;
		}

		if (Player.Controller.IsHoldingDirection(targetMovementAngle, Player.MovementAngle + Mathf.Pi, Mathf.Pi * .2f) &&
			!Player.Controller.IsStrafeModeActive)
		{
			return true;
		}

		return false;
	}
}

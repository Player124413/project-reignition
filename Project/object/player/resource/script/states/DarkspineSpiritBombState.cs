using Godot;
using Project.Core;
using Project.Gameplay.Bosses;

namespace Project.Gameplay;

/// <summary> Handles the darkspine spirit bomb state. </summary>
public partial class DarkspineSpiritBombState : PlayerState
{
	[Export] private PlayerState idleState;

	public SpiritBomb SpiritBomb { get; set; }
	private float holdTimer;

	/// Charging implementation is copied from DarkspineSpinState.cs
	private float slowChargeTimer;
	private bool isKickingSpiritBomb;

	/// <summary> Amount to instantly charge when the button is pressed. </summary>
	private readonly int BurstChargeAmount = 2;
	/// <summary> How quickly to charge when held down. </summary>
	private readonly float SlowChargeInterval = 0.1f;
	/// <summary> How long to remain in the Spin State after the button is released (to allow for mashing). </summary>
	private readonly float SpiritBombHoldLength = 1f;

	public override void EnterState()
	{
		Player.IsSpiritBombActive = true;

		Player.MoveSpeed = 0;
		Player.VerticalSpeed = 0;

		isKickingSpiritBomb = false;
		holdTimer = SpiritBombHoldLength;

		Player.Animator.StartSpiritBomb();
		Player.StartExternal(SpiritBomb, SpiritBomb.PushPosition, 0.5f);

		slowChargeTimer = SlowChargeInterval;
		Player.Skills.ModifySoulGauge(BurstChargeAmount);
	}

	public override void ExitState()
	{
		Player.IsSpiritBombActive = false;
		Player.Animator.ResetState(0.2f);
		Player.StopExternal();
	}

	public override PlayerState ProcessPhysics()
	{
		if (isKickingSpiritBomb)
			return Player.Animator.IsDarkspineKickFinished ? idleState : null;

		Player.UpdateExternalControl();
		holdTimer = Mathf.MoveToward(holdTimer, 0, PhysicsManager.physicsDelta);
		if (Mathf.IsZeroApprox(holdTimer))
		{
			ProcessHold();
			return null;
		}

		if (Player.Skills.IsSoulGaugeEmpty) // Take damage
		{
			SpiritBomb.Explode();
			return null;
		}

		if (Input.IsActionJustPressed("button_attack")) // Provide more soul power when mashing
			Player.Skills.ModifySoulGauge(BurstChargeAmount);

		slowChargeTimer = Mathf.MoveToward(slowChargeTimer, 0, PhysicsManager.physicsDelta);
		if (Mathf.IsZeroApprox(slowChargeTimer))
		{
			Player.Skills.ModifySoulGauge(1);
			slowChargeTimer = SlowChargeInterval;
		}

		return null;
	}

	private void ProcessHold()
	{
		Player.Skills.ModifySoulGauge(-Player.Skills.MaxSoulPower);
		isKickingSpiritBomb = true;
		Player.Animator.KickSpiritBomb();
		Player.Animator.SpiritBombKicked += OnSpiritBombKicked;
	}

	private void OnSpiritBombKicked()
	{
		SpiritBomb.KickSpiritBomb();
		Player.Animator.SpiritBombKicked -= OnSpiritBombKicked;
		Player.StopExternal();
	}
}

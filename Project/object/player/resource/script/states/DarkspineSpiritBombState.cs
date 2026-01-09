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
	private readonly int BurstChargeAmount = 4;
	/// <summary> How quickly to charge when held down. </summary>
	private readonly float SlowChargeInterval = 0.1f;
	/// <summary> How long the spirit bomb must be pushed before it is kicked. </summary>
	private readonly float SpiritBombHoldLength = 3f;

	public override void EnterState()
	{
		Player.IsSpiritBombActive = true;

		Player.MoveSpeed = 0;
		Player.VerticalSpeed = 0;

		isKickingSpiritBomb = false;
		holdTimer = SpiritBombHoldLength;

		Player.Skills.IsTimeBreakEnabled = false;
		Player.Animator.StartSpiritBomb();
		Player.StartExternal(SpiritBomb, SpiritBomb.PushPosition, 0.5f);

		slowChargeTimer = SlowChargeInterval;
		Player.Skills.ModifySoulGauge(BurstChargeAmount);

		SpiritBomb.PushCamera.Activate();
	}

	public override void ExitState()
	{
		Player.Skills.IsTimeBreakEnabled = true;
		Player.IsSpiritBombActive = false;
		Player.StopExternal();

		if (Player.IsKnockback)
			return;

		Player.Animator.ResetState(0.2f);
	}

	public override PlayerState ProcessPhysics()
	{
		if (isKickingSpiritBomb)
		{
			if (Player.Animator.IsDarkspineKickFinished)
			{
				SpiritBomb.AlfLayla.ReceiveSpiritBombKick();
				return idleState;
			}

			return null;
		}

		Player.UpdateExternalControl();

		if (Player.Skills.IsSoulGaugeEmpty) // Take damage
		{
			SpiritBomb.Explode();
			return null;
		}

		holdTimer = Mathf.MoveToward(holdTimer, 0, PhysicsManager.physicsDelta);
		if (Mathf.IsZeroApprox(holdTimer))
		{
			ProcessHold();
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
		isKickingSpiritBomb = true;
		SpiritBomb.KickCamera.Activate();
		Player.Skills.ModifySoulGauge(-Player.Skills.MaxSoulPower);
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

using Godot;
using Project.Core;

namespace Project.Gameplay;

public partial class KnockbackState : PlayerState
{
	[Export] private PlayerState landState;
	[Export] private PlayerState jumpState;
	[Export] private PlayerState idleState;

	public KnockbackSettings Settings { get; set; }
	public KnockbackSettings PreviousSettings { get; set; }
	private readonly float DamageFriction = 20f;

	public override void EnterState()
	{
		Player.Camera.SetLockonTarget(null);

		if (Player.IsLockoutActive &&
			Player.ActiveLockoutData.resetFlags.HasFlag(LockoutResource.ResetFlags.OnKnockback))
		{
			Player.RemoveLockoutData(Player.ActiveLockoutData);
		}

		if (Player.Skills.IsSpeedBreakActive) // Disable speedbreak
			Player.Skills.ToggleSpeedBreak();

		Player.IsKnockback = true;

		if (!SaveManager.ActiveSkillRing.IsFreeRoamActive)
			Player.MovementAngle = Player.PathFollower.ForwardAngle; // Prevent being knocked sideways

		Player.Animator.StartHurt(Settings.knockbackType);
		Player.Animator.ResetState();
		PreviousSettings = Settings;

		Player.StrafeSpeed = 0;
		Player.MoveSpeed = Settings.overrideKnockbackSpeed ? Settings.knockbackSpeed : 8f;
		if (Settings.knockbackType != KnockbackSettings.KnockbackAnimation.Forward)
			Player.MoveSpeed *= -1;

		if (!Settings.stayOnGround)
		{
			Player.IsOnGround = false;
			Player.VerticalSpeed = Runtime.CalculateJumpPower(Settings.overrideKnockbackHeight ? Settings.knockbackHeight : 1);
		}

		if (Player.ExternalController != null)
			return; // Only allow autorespawning when not using external controller

		if (Player.IsInvincible)
			return;

		if (!Settings.disableInvincibility)
			Player.StartInvincibility();

		if (Settings.disableDamage)
			return;

		Player.TakeDamage();
	}

	public override void ExitState()
	{
		if (Settings.knockbackType == KnockbackSettings.KnockbackAnimation.Forward) // NOTE: This is handled in LandState if we're being knocked forward
			return;

		Player.IsKnockback = false;
		Player.FinishKnockback();
		Player.Animator.StopHurt(Settings.knockbackType);
		Player.Animator.ResetState();
	}

	public override PlayerState ProcessPhysics()
	{
		if (StageSettings.Instance.Data.LevelID == "np_last" && Player.IsFinalDarkspineDefeated)
			return null;

		Player.MoveSpeed = Mathf.MoveToward(Player.MoveSpeed, 0, DamageFriction * PhysicsManager.physicsDelta);
		Player.VerticalSpeed -= Runtime.Gravity * PhysicsManager.physicsDelta;
		Player.ApplyMovement();
		Player.UpdateUpDirection();

		if (!Settings.disableDownCancel &&
			SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.DownCancel) &&
			Player.Controller.IsJumpBufferActive)
		{
			Player.Controller.ResetJumpBuffer();
			Player.ForceAccelerationJump = true;
			Player.StartInvincibility(1f);
			return jumpState;
		}

		if (Player.CheckGround())
		{
			if (!Settings.stayOnGround && Settings.knockbackType != KnockbackSettings.KnockbackAnimation.Darkspine)
			{
				Player.Animator.StopHurt(Settings.knockbackType);
				return landState;
			}

			if (Settings.knockbackType == KnockbackSettings.KnockbackAnimation.Darkspine && Player.Animator.IsDarkspineHurtFinished)
			{
				Player.MoveSpeed = 0;
				Player.StrafeSpeed = 0;
			}

			if (Mathf.IsZeroApprox(Player.MoveSpeed))
			{
				Player.Animator.StopHurt(Settings.knockbackType);
				return idleState;
			}
		}

		Player.AttemptFallIntoTheVoid();
		return null;
	}
}

public struct KnockbackSettings
{
	/// <summary> Should the player be knocked forward? Default is false. </summary>
	public KnockbackAnimation knockbackType;
	public enum KnockbackAnimation
	{
		Normal,
		Forward,
		Block,
		Darkspine, // Darkspine Knockback used in the final boss
		DarkspineDefeat,
	}

	/// <summary> Knock the player around without bouncing them into the air. </summary>
	public bool stayOnGround;
	/// <summary> Apply knockback even when invincible? </summary>
	public bool ignoreInvincibility;
	/// <summary> Don't apply invincibility? </summary>
	public bool disableInvincibility;
	/// <summary> Don't damage the player? </summary>
	public bool disableDamage;
	/// <summary> Always apply knockback, regardless of state. </summary>
	public bool ignoreMovementState;

	/// <summary> Don't allow the player to down cancel damage? </summary>
	public bool disableDownCancel;

	/// <summary> Override default knockback amount? </summary>
	public bool overrideKnockbackSpeed;
	/// <summary> Speed to assign to player. </summary>
	public float knockbackSpeed;

	/// <summary> Override default knockback height? </summary>
	public bool overrideKnockbackHeight;
	/// <summary> Height to move player by. </summary>
	public float knockbackHeight;
}
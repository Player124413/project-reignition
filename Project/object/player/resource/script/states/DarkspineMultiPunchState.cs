using Godot;
using Project.Core;
using Project.Gameplay.Bosses;

namespace Project.Gameplay;

/// <summary> Handles the darkspine multiple punches on Alf. </summary>
public partial class DarkspineMultiPunchState : PlayerState
{
	[Export] private IdleState idleState;

	public AlfCore Core { get; set; }

	private bool isAttackQueued;
	private bool isPerformingFinalPunch;
	private int currentAttackCount;
	private int currentPunchStringIndex;
	private readonly int MaxPunchCount = 12;
	private readonly int MultiPunchStringLength = 6;

	private float alfStunTimer;
	private readonly float AlfStunLength = 4.5f;
	private readonly string AttackAction = "action_attack";

	public override void EnterState()
	{
		currentAttackCount = 0;
		currentPunchStringIndex = 0;
		alfStunTimer = AlfStunLength;
		isAttackQueued = false;

		Player.IsMultiPunchActive = true;
		Player.MoveSpeed = 0;
		Player.StrafeSpeed = 0;
		Player.VerticalSpeed = 0;
		Player.StartExternal(Core, Core.MultiPunchPosition, 0.5f);
		Player.Lockon.IsMonitoring = false;
		Player.Animator.StartMultiPunch();
		Core.AlfLayla.StartStunCamera();
		Core.AlfLayla.HideObjects();

		if (Player.Skills.IsSpeedBreakActive)
		{
			// Extra point of damage
			Core.AlfLayla.TakeDamage();
		}

		Player.Skills.DisableBreakSkills();

		HeadsUpDisplay.Instance.SetPrompt(AttackAction, 2);
		HeadsUpDisplay.Instance.ShowPrompts();
	}

	public override void ExitState()
	{
		isPerformingFinalPunch = false;

		Player.IsMultiPunchActive = false;
		Player.StopExternal();
		Player.Skills.EnableBreakSkills();
		Player.Animator.ResetState(0f);
		HeadsUpDisplay.Instance.HidePrompts();
	}

	public override PlayerState ProcessPhysics()
	{
		Player.UpdateExternalControl();

		if (!Core.AlfLayla.IsStunned)
			return idleState;

		if (Core.AlfLayla.IsExploding)
			return idleState;

		if (isPerformingFinalPunch)
			return null;

		alfStunTimer = Mathf.MoveToward(alfStunTimer, 0, PhysicsManager.physicsDelta);
		if (Mathf.IsZeroApprox(alfStunTimer) || (currentAttackCount == MaxPunchCount && Player.Animator.CanPerformDarkspinePunch) ||
			Core.AlfLayla.IsDefeated) // Limit Punches
		{
			HeadsUpDisplay.Instance.HidePrompts();
			if (Player.Animator.IsDarkspinePunchFinished)
			{
				// No world ring explosions. Player goofed.
				Core.AlfLayla.FinishStun();
				return null;
			}

			// Play a cool animation
			isPerformingFinalPunch = true;
			Player.Animator.PerformMultipunch(-1);
			Core.AlfLayla.StartFinalMultiPunch();
			return null;
		}

		if (Player.Controller.IsActionBufferActive || Player.Controller.IsAttackBufferActive)
		{
			Player.Controller.ResetActionBuffer();
			Player.Controller.ResetAttackBuffer();
			isAttackQueued = true;
		}

		if (!isAttackQueued)
			return null;

		if (Player.Animator.IsDarkspinePunchFinished)
		{
			currentPunchStringIndex = 0;
			Player.Animator.PerformMultipunch(currentPunchStringIndex);
			Player.Effect.StartDarkspineSpinFX(true);
			return null;
		}

		if (!Player.Animator.CanPerformDarkspinePunch) // Still punching...
			return null;

		// Throw a punch
		isAttackQueued = false;

		// Deal damage
		currentAttackCount++;
		Core.AlfLayla.TakeDamage();

		// Throw hands
		if (Player.Effect.IsDarkspineSpinFxPlaying)
			Player.Effect.StopDarkspineSpinFX();
		Player.Animator.PerformMultipunch((currentPunchStringIndex % MultiPunchStringLength) + 1);
		currentPunchStringIndex++;

		return null;
	}
}

using Godot;
using Project.Gameplay.Bosses;

namespace Project.Gameplay;

/// <summary> Handles the darkspine multiple punches on Alf. </summary>
public partial class DarkspineMultiPunchState : PlayerState
{
	[Export] private IdleState idle;
	public AlfCore Core { get; set; }
	private bool isAttackQueued;
	private int currentAttackCount;
	private int currentPunchStringIndex;
	private readonly int MaxPunchCount = 12;
	private readonly int MultiPunchStringLength = 6;

	public override void EnterState()
	{
		currentAttackCount = 0;
		currentPunchStringIndex = 0;

		Player.IsMultiPunchActive = true;
		Player.MoveSpeed = 0;
		Player.VerticalSpeed = 0;
		Player.StartExternal(Core, Core.MultiPunchPosition, 0.5f);
		Player.Lockon.IsMonitoring = false;
		Player.Animator.StartMultiPunch();

		if (Player.Skills.IsSpeedBreakActive)
		{
			// Extra point of damage
			Core.AlfLayla.TakeDamage();
		}

		Player.Skills.DisableBreakSkills();
	}

	public override void ExitState()
	{
		Player.IsMultiPunchActive = false;

		Player.StopExternal();
		Player.Skills.EnableBreakSkills();
	}

	public override PlayerState ProcessPhysics()
	{
		/*
		TODO Limit Punches
		if (currentAttackCount == MaxPunchCount)
			return null;
		*/

		Player.UpdateExternalControl();
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
			return null;
		}

		if (!Player.Animator.CanPerformDarkspinePunch) // Still punching...
			return null;

		// Throw a punch
		isAttackQueued = false;

		// Deal damage
		currentAttackCount++;
		Core.AlfLayla.TakeDamage();

		/*
		// TODO Play a cool animation
		if (currentAttackCount == MaxPunchCount)
			return null;
		*/

		// Throw hands
		Player.Animator.PerformMultipunch((currentPunchStringIndex % MultiPunchStringLength) + 1);
		currentPunchStringIndex++;

		return null;
	}
}

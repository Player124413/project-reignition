using Godot;
using Project.Core;
using Project.Gameplay.Bosses;

namespace Project.Gameplay;

/// <summary> Handles the darkspine multiple punches on Alf. </summary>
public partial class DarkspineMultiPunchState : PlayerState
{
	private const int MaxPunchCount = 12;

	public override void EnterState()
	{
		if (Player.Skills.IsSpeedBreakActive)
		{
			// Extra point of damage
		}

		Player.Skills.DisableBreakSkills();
	}
}

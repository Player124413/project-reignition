using Godot;
using Project.Gameplay.Triggers;

namespace Project.Gameplay.Objects
{
	/// <summary>
	/// Behaviour of the Hourglass found in Night Palace.
	/// </summary>
	public partial class Hourglass : TeleportTrigger
	{
		[Signal] public delegate void ActivatedEventHandler();
		[Export] private bool disableTeleportation;
		[Export] private EventTrigger eventHandler;
		private bool isInteractingWithPlayer;

		public override void _PhysicsProcess(double _)
		{
			if (!isInteractingWithPlayer) return;

			if (Player.AttackState == PlayerController.AttackStates.None) return;

			Player.StartBounce();

			if (Player.Skills.IsSpeedBreakActive) // Turn off speedbreak
				Player.Skills.ToggleSpeedBreak();

			eventHandler.Activate();
		}

		public override void Activate()
		{
			if (!disableTeleportation)
				base.Activate();

			EmitSignal(SignalName.Activated);
		}

		public void OnEntered(Area3D a)
		{
			if (!a.IsInGroup("player")) return;
			isInteractingWithPlayer = true;
		}

		public void OnExited(Area3D a)
		{
			if (!a.IsInGroup("player")) return;
			isInteractingWithPlayer = false;
		}
	}
}

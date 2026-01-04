using Godot;
using Project.Core;

namespace Project.Gameplay.Bosses;

public partial class SpiritBomb : Area3D
{
	private bool isInteractingWithPlayer;
	private PlayerController Player => StageSettings.Player;

	[Export] private bool isTravelling;
	[Export] private float moveSpeed;

	public override void _PhysicsProcess(double _delta)
	{
		if (!isInteractingWithPlayer)
		{
			if (isTravelling)
				GlobalPosition += this.Forward() * moveSpeed * PhysicsManager.physicsDelta;

			return;
		}

		ProcessInteraction();
	}


	private void ProcessInteraction()
	{
	}

	public void OnEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = true;
	}

	public void OnExited(Area3D a)
	{

	}
}

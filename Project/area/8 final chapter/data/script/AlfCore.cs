using Godot;

namespace Project.Gameplay.Bosses;

public partial class AlfCore : Area3D
{
	[Export] public AlfLayla AlfLayla { get; private set; }
	[Export] public Node3D MultiPunchPosition { get; private set; }

	public void OnEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		if (StageSettings.Player.IsMultiPunchActive)
			return;

		StageSettings.Player.StartMultiPunch(this);
	}
}

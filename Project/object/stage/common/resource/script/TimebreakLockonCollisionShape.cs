using Godot;

namespace Project.Gameplay.Objects;

public partial class TimebreakLockonCollisionShape : CollisionShape3D
{

	public PlayerController Player => StageSettings.Player;

	public override void _Ready()
	{
		Player.Skills.TimeBreakStarted += UpdateCollision;
		Player.Skills.TimeBreakStopped += UpdateCollision;
		CallDeferred(MethodName.UpdateCollision);
	}

	private void UpdateCollision() => Disabled = !Player.Skills.IsTimeBreakActive;
}

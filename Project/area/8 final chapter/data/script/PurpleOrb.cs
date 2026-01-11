using Godot;
using Project.Core;

namespace Project.Gameplay.Bosses;

public partial class PurpleOrb : Node3D
{
	[Export] private float moveSpeed;
	[Export] private AnimationPlayer animator;
	private bool isActive;
	private readonly int ExplosionDistance = 3;

	public override void _PhysicsProcess(double _)
	{
		if (!isActive)
			return;

		GlobalPosition += this.Back() * moveSpeed * PhysicsManager.physicsDelta;
		if (GlobalPosition.Z < StageSettings.Player.GlobalPosition.Z - ExplosionDistance)
			Respawn();
	}

	public void Activate()
	{
		animator.Play("spawn");
		LookAt(StageSettings.Player.CenterPosition, Vector3.Up);
		isActive = true;
	}

	public void Respawn()
	{
		animator.Play("init");
		isActive = false;
	}

	public void Explode()
	{
		animator.Play("explode");
		isActive = false;
	}
}

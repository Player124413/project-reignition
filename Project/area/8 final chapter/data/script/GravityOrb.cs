using Godot;
using Project.Core;

namespace Project.Gameplay.Bosses;

public partial class GravityOrb : Node3D
{
	[Export] private AnimationPlayer animator;
	[Export] private float gravityPull;
	[Export] private Curve gravityCurve;
	private bool isInteractingWithPlayer;
	private PlayerController Player => StageSettings.Player;

	public override void _PhysicsProcess(double _delta)
	{
		if (!isInteractingWithPlayer)
			return;

		if (!Player.IsOnGround)
			return;

		if (Player.Skills.IsUsingBreakSkills)
			return;

		Player.MoveSpeed *= 0.95f;
		int pullDirection = Mathf.Sign(GlobalPosition.X - Player.GlobalPosition.X);
		float pullAmount = Mathf.Abs(GlobalPosition.X - Player.GlobalPosition.X);
		pullAmount = gravityCurve.Sample(pullAmount) * gravityPull;
		Player.GlobalPosition += Vector3.Right * pullDirection * pullAmount * PhysicsManager.physicsDelta;
	}

	public void OnEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = true;
	}

	public void OnExited(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = false;
	}

	public void Activate()
	{
		animator.Play("spawn");
	}

	public void Respawn()
	{
		animator.Play("RESET");
	}

	public void Explode()
	{
		animator.Play("explode");
		isInteractingWithPlayer = false;
	}
}

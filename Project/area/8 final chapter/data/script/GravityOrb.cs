using Godot;
using Project.Core;

namespace Project.Gameplay.Bosses;

public partial class GravityOrb : Node3D
{
	[Export] private AnimationPlayer animator;
	[Export] private float gravityPull;
	[Export] private float moveSpeed;
	[Export] private Curve gravityCurve;
	[Export] private AudioStreamPlayer pullSfx;

	private bool isSpawned;
	private bool isInteractingWithPlayer;
	private PlayerController Player => StageSettings.Player;
	private readonly int ExplosionDistance = 3;

	public override void _PhysicsProcess(double _delta)
	{
		if (isSpawned)
		{
			float playerFactor = ExtensionMethods.DotAngle(Player.MovementAngle, Player.PathFollower.ForwardAngle) * Player.MoveSpeed;
			GlobalPosition += Vector3.Forward * (moveSpeed - playerFactor) * PhysicsManager.physicsDelta;

			if (GlobalPosition.Z < StageSettings.Player.GlobalPosition.Z - ExplosionDistance)
				Respawn();
		}

		if (!isInteractingWithPlayer)
			return;

		if (Player.Skills.IsUsingBreakSkills)
			return;

		Player.MoveSpeed *= 0.95f;
		Vector3 pullDirection = GlobalPosition - Player.GlobalPosition;
		float pullAmount = pullDirection.Length();
		pullAmount = gravityCurve.Sample(pullAmount) * gravityPull;
		Player.GlobalPosition += pullDirection * pullAmount * PhysicsManager.physicsDelta;
	}

	public void OnEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = true;
		pullSfx.Play();
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
		isSpawned = true;
		TopLevel = true;
	}

	public void Respawn()
	{
		animator.Play("init");
		isSpawned = false;
		TopLevel = false;
	}

	public void Explode()
	{
		animator.Play("explode");
		isInteractingWithPlayer = false;
		TopLevel = false;
	}
}

using Godot;
using Project.Core;

namespace Project.Gameplay.Bosses;

public partial class SpiritBomb : Area3D
{
	private bool isInteractingWithPlayer;
	private PlayerController Player => StageSettings.Player;

	public bool IsTravelling { get; private set; }
	[Export] private float moveSpeed;
	[Export] private float returnSpeed;
	[Export] private AnimationPlayer animator;

	public override void _PhysicsProcess(double _delta)
	{
		if (!isInteractingWithPlayer)
		{
			if (IsTravelling)
				ProcessTravelling();

			return;
		}

		ProcessInteraction();
	}

	private void ProcessTravelling()
	{
		if (TopLevel)
		{
			// Travelling to the player
			GlobalPosition += this.Forward() * moveSpeed * PhysicsManager.physicsDelta;
			return;
		}

		Position = Position.MoveToward(Vector3.Zero, returnSpeed * PhysicsManager.physicsDelta);
		if (Position.IsZeroApprox())
			Explode();
	}

	public void StartTravelling()
	{
		IsTravelling = true;
		TopLevel = true;
		animator.Play("launch");
	}

	public void ReturnToAlf()
	{
		IsTravelling = true;
		TopLevel = false;
	}

	public void Respawn()
	{
		Position = Vector3.Zero;
	}

	/// <summary> Blow up. </summary>
	public void Explode()
	{
		IsTravelling = false;
		animator.Play("explode");

		if (isInteractingWithPlayer)
		{
			isInteractingWithPlayer = false;
			Player.StartKnockback(new KnockbackSettings()
			{
				knockbackType = KnockbackSettings.KnockbackAnimation.Darkspine,
				ignoreInvincibility = true,
				disableInvincibility = true,
				overrideKnockbackSpeed = true,
				knockbackSpeed = 40f,
			});
		}
	}

	private void ProcessInteraction()
	{
		if (Player.Skills.IsSpeedBreakActive)
		{
			IsTravelling = false;
			// TODO Set Player State to SpiritBombState
			return;
		}

		Explode();
	}

	public void OnEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = true;
		ProcessInteraction();
	}

	public void OnExited(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = false;
	}
}

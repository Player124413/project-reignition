using Godot;
using Project.Core;
using Project.CustomNodes;
using Project.Gameplay.Triggers;

namespace Project.Gameplay.Bosses;

public partial class SpiritBomb : Area3D
{
	[Signal] public delegate void AlfExplodedEventHandler();
	[Signal] public delegate void PlayerExplodedEventHandler();

	public bool IsTargetingAlf { get; set; }
	private bool isInteractingWithPlayer;
	private PlayerController Player => StageSettings.Player;

	public bool IsTravelling { get; private set; }
	[Export] private float moveSpeed;
	[Export] private float returnSpeed;
	[Export] public Node3D PushPosition { get; private set; }
	[Export] public Node3D MeshRoot { get; private set; }
	[Export] public CameraTrigger PushCamera { get; private set; }
	[Export] public CameraTrigger KickCamera { get; private set; }
	[Export] public CameraTrigger DamageCamera { get; private set; }
	[Export] public GroupGpuParticles3D KickVfx { get; private set; }
	[Export] private AudioStreamPlayer PushSfx { get; set; }
	[Export] private AudioStreamPlayer KickSfx { get; set; }
	[Export] private AnimationPlayer animator;
	[Export] public AlfLayla AlfLayla { get; private set; }

	public override void _PhysicsProcess(double _delta)
	{
		MeshRoot.GlobalRotation = Player.Camera.Camera.GlobalRotation;
		if (isInteractingWithPlayer)
			return;

		if (IsTravelling)
			ProcessTravelling();
	}

	private void ProcessTravelling()
	{
		if (TopLevel)
		{
			// Travelling to the player
			GlobalPosition += this.Forward() * moveSpeed * PhysicsManager.physicsDelta;
			return;
		}

		if (IsTargetingAlf)
			Position = Position.MoveToward(Vector3.Zero, moveSpeed * PhysicsManager.physicsDelta);
		else
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

	/// <summary> Returns the spirit bomb to alf-layla. </summary>
	public void KickSpiritBomb()
	{
		isInteractingWithPlayer = false;
		IsTravelling = true;
		TopLevel = false;
		PushSfx.Stop();
		KickSfx.Play();
		Player.Camera.StartCameraShake(new PlayerCameraController.CameraShakeSettings()
		{
			fadeIn = 0,
			fadeOut = 0.1f,
			duration = 0.4f,
			magnitude = Vector3.One * 4f,
		});
	}

	public void Respawn()
	{
		TopLevel = false;
		IsTargetingAlf = false;
		Position = Vector3.Zero;
		animator.Play("RESET");
		animator.Advance(0.0);
	}

	/// <summary> Blow up. </summary>
	public void Explode()
	{
		if (!IsTargetingAlf && !isInteractingWithPlayer)
			return;

		IsTravelling = false;
		animator.Play("explode");
		PushSfx.Stop();

		if (isInteractingWithPlayer)
		{
			isInteractingWithPlayer = false;
			Player.StartKnockback(new KnockbackSettings()
			{
				knockbackType = KnockbackSettings.KnockbackAnimation.Darkspine,
				ignoreInvincibility = true,
				disableInvincibility = true,
				overrideKnockbackSpeed = true,
				ignoreMovementState = true,
				knockbackSpeed = 20f,
			});

			AlfLayla.HideObjects();
			DamageCamera.Activate();
			EmitSignal(SignalName.PlayerExploded);
			return;
		}

		EmitSignal(SignalName.AlfExploded);
	}

	public void StartSpiritBombKick()
	{
		KickCamera.Activate();
		AlfLayla.StartSpiritBombKick();
		animator.Play("kick");
	}

	public void OnEntered(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = true;

		if (Player.Skills.IsSpeedBreakActive && !Player.Skills.IsSpeedBreakCharging)
		{
			IsTravelling = false;
			PushSfx.Play();
			Player.StartSpiritBomb(this);
			AlfLayla.PlaySpiritBombPushDialog();
			return;
		}

		Explode();
	}

	public void ApplyKickFX()
	{
		KickSfx.Play();
		Player.Camera.StartCameraShake(new PlayerCameraController.CameraShakeSettings()
		{
			fadeIn = 0,
			fadeOut = 0.05f,
			duration = 0.1f,
			magnitude = Vector3.One * 2.5f,
		});
	}

	public void OnExited(Area3D a)
	{
		if (!a.IsInGroup("player"))
			return;

		isInteractingWithPlayer = false;
	}
}

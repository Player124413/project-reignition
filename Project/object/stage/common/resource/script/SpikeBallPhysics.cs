using Godot;
using Project.Core;

namespace Project.Gameplay.Hazards
{
	public partial class SpikeBallPhysics : RigidBody3D
	{
		/// <summary> Spikeball's current lifetime. </summary>
		private float Lifetime { get; set; }
		/// <summary> How long should the spikeball last? </summary>
		[Export] public float MaxLifetime { get; set; }
		/// <summary> Is this spikeball spawned directly from the editor? </summary>
		[Export] public bool IsSpawnedFromEditor { get; set; }
		/// <summary> Is this spikeball currently spawned? </summary>
		public bool IsSpawned { get; private set; }
		/// <summary> Spikeball's animator. </summary>
		[Export] private Vector3 startingVelocity;
		[Export] private AnimationPlayer animator;

		public override void _Ready()
		{
			StageSettings.Instance.Unloaded += Unload;

			if (IsSpawnedFromEditor)
			{
				if (Sleeping)
					Freeze = true;
			}
		}

		public override void _PhysicsProcess(double _)
		{
			if (!IsSpawned) return;

			if (Lifetime < MaxLifetime)
			{
				Lifetime += PhysicsManager.physicsDelta;
				if (Lifetime >= MaxLifetime)
					animator.Play("despawn");
			}
			else if (!animator.IsPlaying()) //Wait until despawn animation finishes
				Despawn();
		}


		public void Spawn()
		{
			Visible = true;
			ProcessMode = ProcessModeEnum.Inherit;

			GlobalRotation = Vector3.Zero;
			LinearVelocity = GlobalBasis * startingVelocity;
			AngularVelocity = Vector3.Zero;
			animator.Play("spawn");

			Lifetime = 0;
			IsSpawned = true;
		}


		public void Despawn()
		{
			IsSpawned = false;
			Visible = false;
			ProcessMode = ProcessModeEnum.Disabled;
		}

		/// <summary>
		/// Called when the player runs into the Spike Ball.
		/// </summary>
		public void BounceFromPlayer()
		{
			if (!Freeze) // Only apply artificial physics when frozen
				return;

			Freeze = false;
			Vector3 impulse = (GlobalPosition - StageSettings.Player.GlobalPosition) * StageSettings.Player.GetRealVelocity().Length();
			ApplyCentralImpulse(impulse);
			ApplyTorqueImpulse(impulse);
		}

		private void Unload() => QueueFree();
	}
}

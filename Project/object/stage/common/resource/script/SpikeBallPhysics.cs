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
		[Export] private Vector3 startingVelocity;
		/// <summary> Spikeball's animator. </summary>
		[Export] private AnimationPlayer animator;
		private SpawnData spawnData;

		public override void _Ready()
		{
			StageSettings.Instance.Unloaded += Unload;

			if (IsSpawnedFromEditor)
			{
				if (Sleeping)
					Freeze = true;

				spawnData = new(GetParent(), Transform);
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
			if (IsSpawnedFromEditor)
				spawnData.Respawn(this);
			else
				GlobalRotation = Vector3.Zero;

			Visible = true;
			ProcessMode = ProcessModeEnum.Inherit;

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

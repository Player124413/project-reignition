using Godot;

namespace Project.Gameplay.Triggers
{
	public partial class ReflectionTrigger : StageTriggerModule
	{
		[Export] private PlanarReflectionRenderer reflectionRenderer;

		// Store previous data for deactivation.
		private Transform3D previousTransform;

		public override void Activate()
		{
			// Cache data
			previousTransform = reflectionRenderer.GlobalTransform;

			// Move to new position
			reflectionRenderer.GlobalTransform = GlobalTransform;
			reflectionRenderer.ResetPhysicsInterpolation();
		}

		public override void Deactivate() => reflectionRenderer.GlobalTransform = previousTransform;
	}
}

using Godot;

namespace Project.Gameplay.Triggers
{
	/// <summary>
	/// Activates a ControlLockoutResource. Use this for automated sections where the player still needs some control.
	/// </summary>
	public partial class LockoutTrigger : StageTriggerModule
	{
		[Export] public LockoutResource lockoutData;

		public override void Activate()
		{
			Player.CallDeferred(PlayerController.MethodName.AddLockoutData, lockoutData);

			if (!StageSettings.Instance.IsConnected(StageSettings.SignalName.Respawned, new(this, MethodName.Deactivate)))
				StageSettings.Instance.Connect(StageSettings.SignalName.Respawned, new(this, MethodName.Deactivate), (uint)ConnectFlags.OneShot + (uint)ConnectFlags.Deferred);
		}

		public override void Deactivate()
		{
			Player.RemoveLockoutData(lockoutData);

			if (StageSettings.Instance.IsConnected(StageSettings.SignalName.Respawned, new(this, MethodName.Deactivate)))
				StageSettings.Instance.Disconnect(StageSettings.SignalName.Respawned, new(this, MethodName.Deactivate));
		}
	}
}

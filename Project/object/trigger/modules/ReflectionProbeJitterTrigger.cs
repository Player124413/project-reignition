using Godot;
using Project.Core;

namespace Project.Gameplay.Triggers;

/// <summary> Basic script that has a method to jitter/update a reflection probe. </summary>
public partial class ReflectionProbeJitterTrigger : Node3D
{
	private Vector3 basePosition;
	[Export] private CullingTrigger parentCuller;

	public override void _Ready()
	{
		basePosition = GlobalPosition;

		if (parentCuller != null)
			parentCuller.Activated += Refresh;
	}

	public void Refresh()
	{
		Visible = false;
		GetTree().CreateTimer(0.05f).Timeout += () => Visible = true;
	}
}

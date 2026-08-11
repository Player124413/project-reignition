using Godot;
using Project.Core;

namespace Project.Interface;

public partial class Boot : Node
{
	public override void _Ready() => TransitionManager.Instance.LoadCommonResources();

	[Export] private AnimationPlayer animator;

	public override void _Process(double _delta)
	{
		if (!animator.IsPlaying())
			return;

		if (Input.IsActionJustPressed("sys_select"))
			AdvanceVideo();
	}

	private void StartTitleTransition()
	{
		TransitionManager.QueueSceneChange("res://interface/menu/Menu.tscn");
		TransitionManager.StartTransition(new()
		{
			inSpeed = .1f,
			outSpeed = .5f,
			color = Colors.Black
		});
	}

	private void AdvanceVideo() => animator.Advance(animator.CurrentAnimationLength);
}

using Godot;

namespace Project.Gameplay.Objects;

public partial class AlfSlash : Hazard
{
	[Export] private AnimationPlayer animator;
	/// <summary> Array of other slashes that should run with this one. </summary>
	[Export] private AlfSlash[] childSlashes;

	public void Activate()
	{
		animator.Seek(0.0);
		animator.Play("strike");

		for (int i = 0; i < childSlashes.Length; i++)
			childSlashes[i].Activate();
	}

	public void Respawn()
	{
		animator.Play("init");
		animator.Advance(0.0);

		for (int i = 0; i < childSlashes.Length; i++)
			childSlashes[i].Respawn();
	}
}

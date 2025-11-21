using Godot;

namespace Project.Gameplay.Bosses;

public partial class Erazor : Node3D
{
	[Export] private AnimationTree animationTree;
	[Export] private PathFollow3D pathFollower;


	[Export] private string attackPattern;
	private int remainingHealth;

	/// <summary> The preferred distance when attacking the player </summary>
	private readonly float AttackDistance = 10f;

	public override void _Ready()
	{
		animationTree.Active = true; // Activate animation trees

		StageSettings.Instance.Respawned += Respawn;
		StageSettings.Instance.LevelStarted += StartIntroduction;
	}

	public void Respawn()
	{

	}

	public void StartIntroduction()
	{

	}
}
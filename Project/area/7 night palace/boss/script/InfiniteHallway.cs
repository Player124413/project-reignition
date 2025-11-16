using System;
using Godot;

/// <summary>
/// Handles the infinite hallway in Erazor's boss fight.
/// </summary>
namespace Project.Gameplay.Bosses;

public partial class InfiniteHallway : Node3D
{
	[Export] private Node3D hallRoot;
	[Export] private Node3D sky;

	/// <summary> Respawn the same object multiple times since only one item bundle is ever present at a time. </summary>
	[Export] private Node3D itemBundle;
	/// <summary> Determines how many chunks away each item bundle is. </summary>
	[Export] public int[] itemBundleInterval;
	private int itemBundleIndex;
	private int itemBundleCounter;

	[Export] private Node3D primaryCollision;
	[Export] private Node3D secondaryCollision;

	private PlayerController Player => StageSettings.Player;
	private const float CollisionPieceSpacing = -87f;
	private const float CollisionPieceRotation = 1;

	/// <summary> Called when a duel attack ends. Resets positions and respawns objects. </summary>
	[Signal] public delegate void HallResetEventHandler();
	/// <summary> Called when item bundle is respawned. </summary>
	[Signal] public delegate void ItemBundleRespawnedEventHandler();
	/// <summary> Called when entering the final phase. </summary>
	[Signal] public delegate void ItemBundleDeactivatedEventHandler();

	public override void _Ready()
	{
		StageSettings.Instance.Respawned += Respawn;
	}

	public override void _PhysicsProcess(double _)
	{
		float extraRotation = Player.PathFollower.ProgressRatio * Mathf.Tau;
		sky.Rotation = Vector3.Up * (Mathf.Pi * .4f + extraRotation);
	}

	/// <summary> Resets the hallway back to its initial position. Called after a showdown attack. </summary>
	public void Respawn()
	{
		hallRoot.GlobalTransform = Transform3D.Identity;
		primaryCollision.GlobalTransform = Transform3D.Identity;
		secondaryCollision.GlobalTransform = Transform3D.Identity;
		itemBundleIndex = 0;
		itemBundleCounter = 0;
		MoveNode(secondaryCollision, 1);
	}

	/// <summary>
	/// Called from a signal. 
	/// Advances the visuals of the hallway to create the illusion of infinity.
	/// </summary>
	public void AdvanceHall(int direction)
	{
		ProcessItemBundle(direction);
		MoveNode(hallRoot, direction);
	}

	/// <summary>
	/// Called from a signal. 
	/// Advances the visuals of the hallway to create the illusion of infinity.
	/// </summary>
	public void AdvanceItemBundleIndex()
	{
		if (itemBundleIndex >= itemBundleInterval.Length) // Item bundles aren't active
			return;

		itemBundleIndex++;

		if (itemBundleIndex < itemBundleInterval.Length)
			return;

		// Deactivate item bundles
		EmitSignal(SignalName.ItemBundleDeactivated);
	}

	/// <summary> Determines whether the item bundle needs to be spawned. </summary>
	private void ProcessItemBundle(int direction)
	{
		if (itemBundleIndex >= itemBundleInterval.Length) // Finished spawning item bundles
			return;

		itemBundleCounter += itemBundleCounter + direction;
		if (Mathf.Abs(itemBundleCounter) < itemBundleInterval[itemBundleIndex])
			return;

		EmitSignal(SignalName.ItemBundleRespawned);

		itemBundle.GlobalTransform = hallRoot.GlobalTransform;
		for (int i = 0; i < itemBundleCounter; i++) // Move item bundle the correct distance away
			MoveNode(itemBundle, direction); // Each iteration moves the item bundle one chunk

		itemBundleCounter = 0; // Reset item bundle counter
	}

	/// <summary>
	/// Called from a signal. 
	/// Collision only advances after player stops colliding with it to avoid jittering.
	/// </summary>
	public void AdvanceCollision(bool isPrimaryPiece, int direction)
	{
		Node3D targetPiece = isPrimaryPiece ? primaryCollision : secondaryCollision;
		for (int i = 0; i < 2; i++) // Perform twice to skip over the current collision piece
			MoveNode(targetPiece, direction);
	}

	/// <summary>
	/// Moves the given node one chunk forward or backwards.
	/// </summary>
	private void MoveNode(Node3D node, int direction)
	{
		if (direction == -1)
			node.Rotation -= Vector3.Up * Mathf.DegToRad(CollisionPieceRotation);

		node.GlobalPosition += node.Forward() * direction * CollisionPieceSpacing;

		if (direction == 1)
			node.Rotation += Vector3.Up * Mathf.DegToRad(CollisionPieceRotation);
	}
}
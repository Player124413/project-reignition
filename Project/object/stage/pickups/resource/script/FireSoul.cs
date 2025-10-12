using Godot;
using Project.Core;

namespace Project.Gameplay.Objects;

public partial class FireSoul : Pickup
{
	/// <summary> Determines which save data index this fire soul references. </summary>
	[Export(PropertyHint.Range, "1, 3")] public int fireSoulIndex = 1;
	/// <summary> Enable this if you want to hide the firesoul behind a Time Break. </summary>
	[Export] private bool isTimeBreakOnly;
	private bool isCollected;
	private bool isCollectedInCheckpoint;
	private bool isCollectedInSaveFile;
	[Export(PropertyHint.NodePathValidTypes, "AnimationPlayer")] private NodePath animator;
	private AnimationPlayer Animator;

	protected override void SetUp()
	{
		Animator = GetNodeOrNull<AnimationPlayer>(animator);

		base.SetUp();

		// Check save data
		isCollectedInSaveFile = SaveManager.ActiveGameData.LevelData.IsFireSoulCollected(Stage.Data.LevelID, fireSoulIndex);

		Stage.Respawned += Respawn;
		Stage.TriggeredCheckpoint += SaveCheckpoint;

		UpdateLockon();
		Respawn();

		if (isTimeBreakOnly)
		{
			Player.Skills.TimeBreakStarted += ShowFireSoul;
			Player.Skills.TimeBreakStopped += HideFireSoul;
		}
	}

	protected override void Collect()
	{
		if (isCollected)
			return;

		isCollected = true;
		Animator.Play("collect");

		Stage.SetFireSoulCheckpointFlag(fireSoulIndex - 1, true);
		HeadsUpDisplay.Instance.CollectFireSoul(fireSoulIndex - 1);

		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.FireSoulLockon) &&
			Player.IsHomingAttacking)
		{
			Player.StartBounce();
		}

		if (isTimeBreakOnly)
		{
			Player.Skills.TimeBreakStarted -= ShowFireSoul;
			Player.Skills.TimeBreakStopped -= HideFireSoul;
		}
	}

	public override void Respawn()
	{
		isCollected = false;
		Animator.Play(isCollectedInSaveFile || isCollectedInCheckpoint ? "collected" : "RESET");
		Animator.Advance(0);
		UpdateLockon();

		if (isTimeBreakOnly)
			HideFireSoul();
		else
			Animator.Play("loop");

		if (!isCollectedInCheckpoint)
		{
			StageSettings.Instance.SetFireSoulCheckpointFlag(fireSoulIndex - 1, false);
			HeadsUpDisplay.Instance.UncollectFireSoul(fireSoulIndex - 1);
		}

		base.Respawn();
	}

	private void UpdateLockon()
	{
		if (SaveManager.ActiveSkillRing.IsSkillEquipped(SkillKey.FireSoulLockon))
		{
			Animator.Play("enable-lockon");
			Animator.Advance(0);
		}
	}

	private void ShowFireSoul()
	{
		if (isCollected)
			return;

		Animator.Play("show");
	}

	private void HideFireSoul()
	{
		if (isCollected)
			return;

		Animator.Play("hide");
	}

	private void SaveCheckpoint()
	{
		if (isCollectedInCheckpoint || !isCollected)
			return;

		isCollectedInCheckpoint = true;
	}

	public override void Unload()
	{
		if (isCollected && Stage.LevelState == StageSettings.LevelStateEnum.Success) // Write save data
			SaveManager.ActiveGameData.LevelData.SetFireSoulCollected(Stage.Data.LevelID, fireSoulIndex);

		base.Unload();
	}
}
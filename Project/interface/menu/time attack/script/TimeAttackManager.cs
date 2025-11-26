using Godot;
using System;
using Godot.Collections;
using System.Collections.Generic;
using Project.Gameplay;

namespace Project.Core;

public partial class TimeAttackManager : Node
{

	public static TimeAttackManager Instance;
	public enum RunType
	{
		AnyP,
		AnyPercentPlus,
		GoalPercent,
		SingleRun,
		BossRush,
		Custom
	}

	public RunType CurrentRunType { get; private set; }

	[Export]
	private LevelDataResource[] Levels_AnyPercent;
	[Export]
	private LevelDataResource[] Levels_GoalPercent;
	[Export]
	private LevelDataResource[] Levels_BossRush;
	private LevelDataResource[] Levels_Custom;

	public int CurrentLevel { get; private set; }
	public int IsRunActive { get; private set; }


	public override void _EnterTree()
	{
		Instance = this;
	}
	public void SetRunType(RunType type) => CurrentRunType = type;

	public void SetCustomRun(LevelDataResource[] custom) => custom.CopyTo(Levels_Custom, 0);

	public LevelDataResource[] GetCurrentRunLevels(RunType type)
	{
		switch (type)
		{
			case RunType.AnyP:
				return Levels_AnyPercent;
			case RunType.AnyPercentPlus:
				return Levels_AnyPercent;
			case RunType.GoalPercent:
				return Levels_GoalPercent;
			case RunType.BossRush:
				return Levels_BossRush;
			case RunType.Custom:
				return Levels_Custom;
		}
		return Levels_AnyPercent;
	}

	public LevelDataResource GetNextLevel()
	{
		return GetCurrentRunLevels(CurrentRunType)[CurrentLevel + 1];
	}

	public bool IsLastLevel()
	{
		if (GetCurrentRunLevels(CurrentRunType)[CurrentLevel + 1] == null)
			return true;
		else
			return false;
	}

	public void ResetLevelCount() => CurrentLevel = 0;
}

using Godot;
using System;
using Godot.Collections;
using Project.Gameplay;

namespace Project.Core;

public partial class TimeAttackManager : Node
{

	public static TimeAttackManager Instance;
	public enum RunType
	{
		AnyP,
		GoalPercent,
		SingleRun,
		BossRush,
		Custom
	}

	public RunType CurrentRunType { get; private set; }

	private float[] CurrentRunTimes;

	[Export]
	private LevelDataResource[] Levels_AnyPercent;
	[Export]
	private LevelDataResource[] Levels_GoalPercent;
	[Export]
	private LevelDataResource[] Levels_BossRush;
	private LevelDataResource[] Levels_Custom;

	public int CurrentLevel { get; private set; }
	public bool IsRunActive { get; private set; }


	public override void _EnterTree()
	{
		Instance = this;
	}
	public void SetRunType(RunType type)
	{
		CurrentRunType = type;
		CurrentRunTimes = new float[GetCurrentRun().Length];
	}

	public void SetCustomRun(LevelDataResource[] custom) => custom.CopyTo(Levels_Custom, 0);

	public LevelDataResource[] GetCurrentRunLevels(RunType type)
	{
		switch (type)
		{
			case RunType.AnyP:
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

	///<summary> Gets all levels of the selected run </summary>
	public LevelDataResource[] GetCurrentRun()
	{
		return GetCurrentRunLevels(CurrentRunType);
	}

	///<summary> Gets the current level of the run being played </summary>
	public LevelDataResource GetCurrentLevel()
	{
		return GetCurrentRunLevels(CurrentRunType)[CurrentLevel];
	}
	///<summary> Gets the next level of the run being played </summary>
	public LevelDataResource GetNextLevel()
	{
		return GetCurrentRunLevels(CurrentRunType)[CurrentLevel + 1];
	}

	///<summary> Are we on the last level? </summary>
	public bool IsLastLevel()
	{
		if (GetCurrentRunLevels(CurrentRunType)[CurrentLevel + 1] == null)
			return true;
		else
			return false;
	}

	public void IncreaseLevel() => CurrentLevel += 1;
	public void ResetLevelCount() => CurrentLevel = 0;

	public void SetRunActive(bool isActive) => IsRunActive = isActive;
	public void LoadLevel(LevelDataResource level)
	{
		TransitionManager.QueueSceneChange(level.LevelPath);
		TransitionManager.StartTransition(new()
		{
			inSpeed = 0.2f,
			color = Colors.Black,
			loadAsynchronously = true,
			disableAutoTransition = true,
			showMissionDescription = true
		});
		TransitionManager.Instance.SetMissionDescriptionText(level.MissionTypeKey, level.MissionDescriptionKey);
		TransitionManager.Instance.UpdateLoadingText("load_level");
	}

	public void RestartRun()
	{
		ResetRunTimes();
		ResetLevelCount();
		LoadLevel(GetCurrentLevel());
	}

	public void AddTime(float time)
	{
		CurrentRunTimes[CurrentLevel] = time;
	}
	public float GetTotalRunTime()
	{
		float results = 0;
		foreach (float time in CurrentRunTimes)
		{
			//GD.Print("Time: " + time);
			results += time;
		}
		//GD.Print("Total Run Time: " + results);
		return results;
	}

	private void ResetRunTimes()
	{
		for (int i = 0; i < GetCurrentRun().Length; i++)
		{
			CurrentRunTimes[i] = 0;
		}
	}


}

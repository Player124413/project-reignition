using Godot;
using System;
using Godot.Collections;
using Project.Gameplay;
using System.Linq;

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
	public LevelDataResource Level_Single;

	//Used for Daily Run
	[Export]
	private LevelDataResource[] Levels_LP;
	[Export]
	private LevelDataResource[] Levels_SO;
	[Export]
	private LevelDataResource[] Levels_DJ;
	[Export]
	private LevelDataResource[] Levels_EF;
	[Export]
	private LevelDataResource[] Levels_LR;
	[Export]
	private LevelDataResource[] Levels_PS;
	[Export]
	private LevelDataResource[] Levels_SD;
	[Export]
	private LevelDataResource[] Levels_NP;



	public int CurrentLevel { get; private set; }
	public bool IsRunActive { get; private set; }


	public override void _EnterTree()
	{
		Instance = this;
	}
	public void SetRunType(RunType type)
	{
		CurrentRunType = type;
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
	public LevelDataResource[] GetCurrentRunLevels()
	{
		switch (CurrentRunType)
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
		if (CurrentRunType != RunType.SingleRun)
			return GetCurrentRunLevels(CurrentRunType)[CurrentLevel];
		else
			return Level_Single;
	}
	///<summary> Gets the next level of the run being played </summary>
	public LevelDataResource GetNextLevel()
	{
		return GetCurrentRunLevels(CurrentRunType)[CurrentLevel + 1];
	}

	///<summary> Are we on the last level? </summary>
	public bool IsLastLevel()
	{
		if (GetCurrentLevel() == GetCurrentRunLevels().Last() || CurrentRunType == RunType.SingleRun)
			return true;
		else
			return false;
	}

	///<summary> 
	/// Generates a daily run with a seed based on the date.
	/// The run generates one unique mission from each world, with the last mission always being a boss.
	/// </summary>
	public void GenerateDailyRun()
	{
		int world1, world2, world3, world4;
		int mission1, mission2, mission3, mission4, mission5;
		Levels_Custom = new LevelDataResource[5];

		RandomNumberGenerator random = new RandomNumberGenerator();

		random.Seed = Time.GetDateStringFromSystem().Hash();

		world1 = random.RandiRange(0, 7);

		//Makes sure each world is unique
		do { world2 = random.RandiRange(0, 7); }
		while (world2 == world1);

		do { world3 = random.RandiRange(0, 7); }
		while (world3 == world1 || world3 == world2);

		do { world4 = random.RandiRange(0, 7); }
		while (world4 == world1 || world4 == world2 || world4 == world3);

		mission1 = GetMissionBasedOnWorld(world1, random);
		mission2 = GetMissionBasedOnWorld(world2, random);
		mission3 = GetMissionBasedOnWorld(world3, random);
		mission4 = GetMissionBasedOnWorld(world4, random);
		mission5 = random.RandiRange(0, Levels_BossRush.Length - 1);

		Levels_Custom[0] = GetMission(world1, mission1);
		Levels_Custom[1] = GetMission(world2, mission2);
		Levels_Custom[2] = GetMission(world3, mission3);
		Levels_Custom[3] = GetMission(world4, mission4);
		Levels_Custom[4] = Levels_BossRush[mission5];

	}

	private int GetMissionBasedOnWorld(int world, RandomNumberGenerator rand)
	{
		switch (world)
		{
			case 0://LP
				return rand.RandiRange(0, Levels_LP.Length - 1);
			case 1://SO
				return rand.RandiRange(0, Levels_SO.Length - 1);
			case 2://DJ
				return rand.RandiRange(0, Levels_DJ.Length - 1);
			case 3://EF
				return rand.RandiRange(0, Levels_EF.Length - 1);
			case 4://LR
				return rand.RandiRange(0, Levels_LR.Length - 1);
			case 5://PS
				return rand.RandiRange(0, Levels_PS.Length - 1);
			case 6://SD
				return rand.RandiRange(0, Levels_SD.Length - 1);
			case 7://NP
				return rand.RandiRange(0, Levels_NP.Length - 1);
		}

		return 0;
	}

	private LevelDataResource GetMission(int world, int mission)
	{
		switch (world)
		{
			case 0://LP
				return Levels_LP[mission];
			case 1://SO
				return Levels_SO[mission];
			case 2://DJ
				return Levels_DJ[mission];
			case 3://EF
				return Levels_EF[mission];
			case 4://LR
				return Levels_LR[mission];
			case 5://PS
				return Levels_PS[mission];
			case 6://SD
				return Levels_SD[mission];
			case 7://NP
				return Levels_NP[mission];
		}
		return Levels_LP[0];
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

	public void LoadResults()
	{
		TransitionManager.QueueSceneChange(TransitionManager.TimeAttackResultsPath);
		TransitionManager.StartTransition(new()
		{
			inSpeed = 0.2f,
			outSpeed = 0.5f,
			color = Colors.Black,
			disableAutoTransition = false
		});
		ClearCurrentSavedRun();
	}

	public void LoadTimeAttack()
	{
		TimeAttackManager.Instance.SetRunActive(false);
		TransitionManager.QueueSceneChange(TransitionManager.TimeAttackScenePath);
		TransitionManager.StartTransition(new()
		{
			inSpeed = 0.2f,
			outSpeed = 0.5f,
			color = Colors.Black,
			disableAutoTransition = false
		});
	}

	public void RestartRun()
	{
		ResetRunTimes();
		ResetLevelCount();
		ClearCurrentSavedRun();
		ClearCurrentRun();
		LoadLevel(GetCurrentLevel());
	}

	public void ClearCurrentSavedRun()
	{
		SaveManager.TimeData.CurrentPlacement = 0;
		SaveManager.TimeData.RunInProgress = [];
		SaveManager.SaveTimeAttackData();
	}

	public void ClearCurrentRun()
	{
		CurrentLevel = 0;
		if (GetCurrentRun() != null)
			CurrentRunTimes = new float[GetCurrentRun().Length];

	}

	public void AddTime(float time)
	{
		CurrentRunTimes[CurrentLevel] = time;
	}

	public float[] GetCurrentRunTimes()
	{
		return CurrentRunTimes;
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
		CurrentRunTimes = [];
	}


}

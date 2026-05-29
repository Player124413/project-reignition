using Godot;
using System;
using System.Collections.Generic;
using Project.Gameplay;

namespace Project.Core;

public partial class ModManager : Node
{

	public static ModManager Instance;
	public List<LevelDataResource> ModdedLevels { get; private set; }
	private readonly string CustomLevelPath = "user://custom/levels/";

	public override void _EnterTree()
	{
		Instance = this;
		SetUpMods();
	}

	private void SetUpMods()
	{
		ModdedLevels = new List<LevelDataResource>();
		if (!DirAccess.DirExistsAbsolute(CustomLevelPath))
			DirAccess.MakeDirRecursiveAbsolute(CustomLevelPath);

		DirAccess dir = DirAccess.Open(CustomLevelPath);

		if (dir == null)
			return;

		foreach (string file in dir.GetFiles()) //Iterates through all level mods
		{
			GD.Print("LOADING MOD: " + CustomLevelPath + file);
			if (file.GetExtension().Equals("pck"))
			{
				var success = ProjectSettings.LoadResourcePack(CustomLevelPath + file); //Loads the pck
				if (!success)
					continue; //If we failed, keep looking for pcks
				else
					GD.Print("LOADING MOD Succeeded");
			}
		}

		DirAccess modDir = DirAccess.Open("res://mods/levels/");

		if (modDir == null)
			return;

		foreach (string mod in modDir.GetDirectories())//Gets all the directories that were added
		{
			GD.Print("res://mods/levels/" + mod);
			DirAccess levelDir = DirAccess.Open("res://mods/levels/" + mod + "/"); //Access the specific mod directory

			for (int i = 0; i < levelDir.GetFiles().Length; i++)
			{
				if (levelDir.GetFiles()[i].GetFile().GetExtension().Equals("tres")) //Finds the first tres in the directory, which should be the level data resource
				{
					LevelDataResource data = ResourceLoader.Load(levelDir.GetCurrentDir() + "/" + levelDir.GetFiles()[i]) as LevelDataResource;
					GD.Print("Loading mod: " + levelDir.GetFiles()[i]);
					ModdedLevels.Add(data);

					GD.Print("Mission Name: " + ModdedLevels[i].MissionTypeKey);
					GD.Print("Mission Description: " + ModdedLevels[i].MissionDescriptionKey);
					break;//Break out of the loop when we find the tres
				}

			}
		}

	}
}

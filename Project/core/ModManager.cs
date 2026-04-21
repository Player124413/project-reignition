using Godot;
using System;
using Godot.Collections;
using Project.Gameplay;

namespace Project.Core;

public partial class ModManager : Node
{

	public static ModManager Instance;
	public LevelDataResource[] ModdedLevels { get; private set; }
	private readonly string CustomLevelPath = "user://custom/levels/";

	public override void _EnterTree()
	{
		SetUpMods();
	}

	private void SetUpMods()
	{

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
			GD.Print("FINISHED LOADING MOD: " + file);
		}

		DirAccess modDir = DirAccess.Open("res://mods/levels/");

		foreach (string mod in modDir.GetDirectories())//Gets all the directories that were added
		{
			DirAccess levelDir = DirAccess.Open("res://mods/levels/" + mod); //Access the specific mod directory

			foreach (string level in levelDir.GetFiles()) //Look through the files for the stage resource
			{
				GD.Print("Level File: " + level);
			}
			GD.Print(mod);
		}


	}
}

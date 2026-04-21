using Godot;
using System;
using Godot.Collections;
using Project.Gameplay;

namespace Project.Core;

public partial class ModManager : Node
{

	public LevelDataResource[] ModdedLevels { get; private set; }
	private readonly string CustomLevelPath = "user://custom/levels/";

	public override void _EnterTree()
	{
		SetUpMods();
	}

	private void SetUpMods()
	{
		DirAccess dir = DirAccess.Open(CustomLevelPath);

		if (dir == null)
			return;

		foreach (string file in dir.GetFiles())
		{
			GD.Print("LOADING MOD: " + file);
			if (file.GetExtension().Equals(".pck"))
			{

			}
		}
	}
}

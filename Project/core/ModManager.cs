using Godot;
using System;
using System.Collections.Generic;
using Project.Gameplay;

namespace Project.Core;

public partial class ModManager : Node
{
	public static ModManager Instance;
	public readonly List<LevelDataResource> ModdedLevels = [];
	public readonly List<SkillResource> CharacterMods = [];

	// Mod paths
	private readonly string ResourceModPath = "res://mods/";
	private readonly string LevelPaths = "levels/";
	private readonly string CustomCharacterPaths = "characters/";
	private readonly string PackExtension = "pck";
	private readonly string ResourceExtension = "tres";

	public override void _EnterTree() => Instance = this;

	public override void _Ready() => SetUpMods();

	public void SetUpMods()
	{
		InitializeModDirectories();
		LoadLevelMods();
	}

	/// <summary> Ensures that mod folders exist. </summary>
	private void InitializeModDirectories()
	{
		if (!DirAccess.DirExistsAbsolute(CustomCharacterPaths))
			DirAccess.MakeDirRecursiveAbsolute(CustomCharacterPaths);
	}

	/// <summary> Loads a .pck from a directory. </summary>
	private void LoadPck(string file, string dir)
	{
		if (!file.GetExtension().Equals(PackExtension))
			return;

		if (!ProjectSettings.LoadResourcePack(dir + file))
			GD.PrintErr($"Couldn't load mod {dir + file}!");
	}

	private void LoadLevelMods()
	{
		if (!DirAccess.DirExistsAbsolute(SaveManager.ModDirectory + LevelPaths)) // No level mods to load
			return;

		DirAccess dirAccess = DirAccess.Open(SaveManager.ModDirectory + LevelPaths);
		foreach (string file in dirAccess.GetFiles())
			LoadPck(file, SaveManager.ModDirectory + LevelPaths);

		if (!DirAccess.DirExistsAbsolute(ResourceModPath + LevelPaths)) // Failed to load any levels
			return;

		// Switch to local resource folder, now that pcks are loaded
		dirAccess = DirAccess.Open(ResourceModPath + LevelPaths);
		foreach (string level in dirAccess.GetDirectories())
			LoadModLevel(ResourceModPath + LevelPaths + level + "/");
	}

	private void LoadModLevel(string dir)
	{
		DirAccess levelDir = DirAccess.Open(dir); // Access the specific mod directory
		string[] files = levelDir.GetFiles();
		foreach (string file in files) // Find the level data resource
		{
			if (!file.GetFile().GetExtension().Equals(ResourceExtension))
				continue;

			Resource resource = ResourceLoader.Load(dir + file);
			if (resource is not LevelDataResource)
				continue;

			ModdedLevels.Add(resource as LevelDataResource);
			GD.Print($"Loaded custom level {file}.");
			break; // Found our level data resource
		}
	}
}

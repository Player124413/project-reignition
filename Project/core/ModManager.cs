using Godot;
using System;
using System.Collections.Generic;
using Project.Gameplay;

namespace Project.Core;

public partial class ModManager : Node
{
	public static ModManager Instance;
	public readonly List<LevelDataResource> LevelMods = [];
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
		LoadLevelMods();
		LoadCharacterMods();
	}

	/// <summary> Loads a .pck from a directory. </summary>
	private void LoadPck(string file, string dir)
	{
		if (!file.GetExtension().Equals(PackExtension))
			return;

		if (!ProjectSettings.LoadResourcePack(dir + file))
			GD.PrintErr($"Couldn't load mod {dir + file}!");

		GD.Print($"Loaded PCK {dir + file}");
	}

	/// <summary> Loads pcks from a given directory. </summary>
	private bool LoadPcks(string dir)
	{
		if (!DirAccess.DirExistsAbsolute(dir)) // No level mods to load
			return false;

		DirAccess dirAccess = DirAccess.Open(dir);
		foreach (string file in dirAccess.GetFiles())
			LoadPck(file, dir);

		return true;
	}

	private void LoadLevelMods()
	{
		if (!LoadPcks(SaveManager.ModDirectory + LevelPaths)
			|| !DirAccess.DirExistsAbsolute(ResourceModPath + LevelPaths))
		{
			// Failed to load any levels
			return;
		}

		// Switch to local resource folder, now that pcks are loaded
		DirAccess dirAccess = DirAccess.Open(ResourceModPath + LevelPaths);
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

			LevelMods.Add(resource as LevelDataResource);
			GD.Print($"Loaded custom level {file}.");
			break; // Found our level data resource
		}
	}

	private void LoadCharacterMods()
	{
		if (!LoadPcks(SaveManager.ModDirectory + CustomCharacterPaths)
			|| !DirAccess.DirExistsAbsolute(ResourceModPath + CustomCharacterPaths))
		{
			// Failed to load any levels
			return;
		}

		// Switch to local resource folder, now that pcks are loaded
		DirAccess dirAccess = DirAccess.Open(ResourceModPath + CustomCharacterPaths);
		foreach (string character in dirAccess.GetDirectories())
			LoadModCharacter(ResourceModPath + CustomCharacterPaths + character + "/");
	}

	private void LoadModCharacter(string dir)
	{
		DirAccess levelDir = DirAccess.Open(dir); // Access the specific mod directory
		string[] files = levelDir.GetFiles();
		foreach (string file in files) // Find the level data resource
		{
			if (!file.GetFile().GetExtension().Equals(ResourceExtension))
				continue;

			Resource resource = ResourceLoader.Load(dir + file);
			if (resource is not SkillResource)
				continue;

			CharacterMods.Add(resource as SkillResource);
			GD.Print($"Loaded custom character {file}.");
			break; // Found our character
		}
	}
}

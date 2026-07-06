using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class Jukebox : Menu
{
	[Export] private AnimationPlayer cursorAnimator;
	[Export] private AudioStreamPlayer player;
	[Export] private BGMResource defaultOption;
	[Export] private PackedScene jukeboxOption;
	[Export] private VBoxContainer optionContainer;
	[Export] private VBoxContainer optionContainerSub;
	[Export] private Node2D cursor;
	[Export] private Sprite2D scrollbar;
	[Export] private Array<BGMResource> songList;
	[Export] private Control worldText;
	[Export] private Control parentNavigationButtons;
	private readonly Array<string> registeredMusicPaths = [];
	private readonly Array<BGMResource> customSongList = [];

	public LevelDataResource SelectedLevel { get; set; }

	private int cursorPosition;
	private int cursorPositionSub;
	private Vector2 cursorVelocity;
	private const float CursorSmoothing = .1f;

	private int scrollAmount;
	private float scrollRatio;
	private Vector2 scrollVelocity;
	private Vector2 containerVelocity;
	private const float ScrollSmoothing = .1f;
	/// <summary> How much to scroll per song. </summary>
	private readonly int ScrollInterval = 62;
	/// <summary> Number of songs on a single page. </summary>
	private readonly int PageSize = 8;
	private int MaxScrollAmount => (isCustomMusicMenuActive ? customSongOptionList.Count : songOptionList.Count) - 1;

	private bool isNothingSelected;
	private readonly Array<JukeboxOption> songOptionList = [];
	private readonly Array<JukeboxOption> customSongOptionList = [];
	private bool isCustomMusicMenuActive;
	private readonly string CustomMusicPath = SaveManager.ModDirectory + "music/";

	protected override void SetUp()
	{
		for (int i = 0; i < songList.Count; i++)
		{
			JukeboxOption newSong = jukeboxOption.Instantiate<JukeboxOption>();
			newSong.MouseEntered += () => ReceiveMouseInput(newSong);
			newSong.MouseExited += () => ReceiveMouseInput(null);
			newSong.SetBgmResource(songList[i]);
			songOptionList.Add(newSong);
			optionContainer.AddChild(newSong);
		}

		base.SetUp();
	}

	/// <summary> Returns whether a given extension is supported for custom music playback. </summary>
	private bool IsValidExtension(string extension) => extension.Equals("wav") || extension.Equals("ogg") || extension.Equals("mp3");

	private void SetUpCustomMusic()
	{
		for (int i = 0; i < optionContainerSub.GetChildren().Count; i++)
			optionContainerSub.GetChild(i).QueueFree();

		registeredMusicPaths.Clear();
		customSongList.Clear();
		customSongOptionList.Clear();
		customSongList.Add(defaultOption);

		if (!DirAccess.DirExistsAbsolute(CustomMusicPath))
			DirAccess.MakeDirRecursiveAbsolute(CustomMusicPath);

		LoadCustomMusicRecursively(CustomMusicPath, true); // Load prms
		LoadCustomMusicRecursively(CustomMusicPath, false); // Load audios

		for (int i = 0; i < customSongList.Count; i++) // Creates the menu options for the custom songs
		{
			JukeboxOption newSong = jukeboxOption.Instantiate<JukeboxOption>();
			newSong.MouseEntered += () => ReceiveMouseInput(newSong);
			newSong.MouseExited += () => ReceiveMouseInput(null);
			newSong.SetBgmResource(customSongList[i]);
			customSongOptionList.Add(newSong);
			optionContainerSub.AddChild(newSong);
		}
	}

	private void LoadCustomMusicRecursively(string path, bool prmOnly)
	{
		DirAccess dir = DirAccess.Open(path);
		if (dir == null)
			return;

		if (prmOnly)
		{
			foreach (string file in dir.GetFiles()) // Load PRM files
			{
				if (file.GetExtension().ToLower() != "prm")
					continue;

				string filePath = path.PathJoin(file).SimplifyPath();
				BGMResource bgmRes = SaveManager.Instance.LoadPRM(filePath);
				customSongList.Add(bgmRes);
				registeredMusicPaths.Add(bgmRes.StreamPath.SimplifyPath());
			}
		}
		else
		{
			foreach (string file in dir.GetFiles()) // Iterates again, loading any leftover music files
			{
				// Not a prm file
				if (!IsValidExtension(file.GetExtension()))
					continue;

				string filePath = path.PathJoin(file).SimplifyPath();
				if (registeredMusicPaths.Contains(filePath)) // Already loaded this music track from a prm
					continue;

				// If we can't find a PRM of an unregistered track, create one
				SaveManager.Instance.CreatePRM(file, filePath);
				BGMResource bgmRes = SaveManager.Instance.LoadPRM(filePath); // Load the PRM into a BGMResource again
				customSongList.Add(bgmRes);
				registeredMusicPaths.Add(filePath);
			}
		}

		foreach (string directory in dir.GetDirectories()) // Load subdirectories
			LoadCustomMusicRecursively(path.PathJoin(directory), prmOnly);
	}

	public override void _Process(double _)
	{
		float targetScrollPosition = 360 * scrollRatio;
		scrollbar.Position = scrollbar.Position.SmoothDamp(Vector2.Right * targetScrollPosition, ref scrollVelocity, ScrollSmoothing);

		// Update cursor position
		float targetCursorPosition = cursorPosition * ScrollInterval;
		cursor.Position = cursor.Position.SmoothDamp(Vector2.Down * targetCursorPosition, ref cursorVelocity, CursorSmoothing);

		if (!isCustomMusicMenuActive)
		{
			Vector2 targetContainerPosition = new(optionContainer.Position.X, -scrollAmount * ScrollInterval);
			optionContainer.Position = optionContainer.Position.SmoothDamp(targetContainerPosition, ref containerVelocity, ScrollSmoothing);
		}
		else
		{
			Vector2 targetContainerPosition = new(optionContainerSub.Position.X, -scrollAmount * ScrollInterval);
			optionContainer.Position = optionContainerSub.Position.SmoothDamp(targetContainerPosition, ref containerVelocity, ScrollSmoothing);
		}
	}

	public override void ShowMenu()
	{
		SetUpCustomMusic(); // Refresh custom music list
		worldText.Visible = false;

		if (InitializeBgmResource() != null)
			PlayBgm();
		else
			ScrollSelection(0);

		animator.Play(isCustomMusicMenuActive ? "showsub" : "hidesub");
		animator.Seek(animator.CurrentAnimationLength, true, true);

		UpdateSelectionVisuals();
		base.ShowMenu();
	}

	protected override void ProcessMenu()
	{
		if (Runtime.Instance.MouseScrollInput != 0)
		{
			int targetIndex = VerticalSelection + Runtime.Instance.MouseScrollInput;
			targetIndex = Mathf.Clamp(targetIndex, 0, MaxScrollAmount);

			int sign = targetIndex - VerticalSelection;
			if (sign != 0)
			{
				VerticalSelection = targetIndex;
				UpdateScrollAmount(sign);
				MoveCursor();
				StartSelectionTimer();
			}

			return;
		}

		if (Runtime.Instance.IsActionJustPressed("sys_sort", "ui_focus_next"))
		{
			isCustomMusicMenuActive = !isCustomMusicMenuActive;
			ScrollSelection(Mathf.Min(MaxScrollAmount, VerticalSelection));
			animator.Play(isCustomMusicMenuActive ? "showsub" : "hidesub");
		}

		// Quick scrolling
		if (Input.IsActionJustPressed("button_step_left"))
		{
			int targetSelection = Mathf.Max(VerticalSelection - PageSize, 0);
			ScrollSelection(targetSelection);
			return;
		}

		if (Input.IsActionJustPressed("button_step_right"))
		{
			int targetSelection = Mathf.Min(VerticalSelection + PageSize, MaxScrollAmount);
			ScrollSelection(targetSelection);
			return;
		}

		if (Input.IsActionJustPressed("button_attack"))
		{
			SetUpCustomMusic();
		}

		base.ProcessMenu();
	}

	protected override void Confirm()
	{
		if (VerticalSelection == 0)
		{
			StopBgm();
			if (SaveManager.ActiveGameData.selectedMusic.Remove(SelectedLevel.LevelID))
			{
				animator.Play("equip");
				UpdateSelectionVisuals();
			}
		}
		else
		{
			if (!SaveManager.ActiveGameData.selectedMusic.TryGetValue(SelectedLevel.LevelID, out string selectedBgm))
				selectedBgm = string.Empty;

			string targetBgm = isCustomMusicMenuActive ? customSongOptionList[VerticalSelection].Bgm.StreamPath :
				ResourceUid.IdToText(ResourceLoader.GetResourceUid(songOptionList[VerticalSelection].Bgm.ResourcePath));

			if (targetBgm.Equals(selectedBgm))
				return;

			if (SaveManager.ActiveGameData.selectedMusic.ContainsKey(SelectedLevel.LevelID)) // If our dictionary already contains the ID for the selected level
				SaveManager.ActiveGameData.selectedMusic[SelectedLevel.LevelID] = targetBgm;
			else
				SaveManager.ActiveGameData.selectedMusic.Add(SelectedLevel.LevelID, targetBgm);

			PlayBgm();
			animator.Play("equip");
			UpdateSelectionVisuals();
		}

		SaveManager.SaveGameData();
	}

	private void UpdateSelectionVisuals()
	{
		// Unequip everything, then re-equip the selected song
		UnequipSongs();

		if (VerticalSelection == 0)
		{
			// Default music is selected on both menus
			songOptionList[VerticalSelection].Equip();
			customSongOptionList[VerticalSelection].Equip();
			return;
		}

		if (isCustomMusicMenuActive)
			customSongOptionList[VerticalSelection].Equip();
		else
			songOptionList[VerticalSelection].Equip();
	}

	public override void PlayBgm()
	{
		//if (parentMenu.bgm.GetBgmResource() != null)
		parentMenu.bgm.Stop();
		parentMenu.parentMenu.bgm.Stop();

		BGMResource targetBgmResource = isCustomMusicMenuActive ? customSongOptionList[VerticalSelection].Bgm : songOptionList[VerticalSelection].Bgm;
		bgm.SetBgmResource(targetBgmResource);
		bgm.LoadBgmResource(); // Loads the selected BGM
		bgm.Play();
	}

	public override void StopBgm()
	{
		base.StopBgm();
		bgm.SetBgmResource(null);
		(parentMenu as LevelSelect).UpdateBgm();
	}

	protected override void Cancel()
	{
		worldText.Visible = true;
		isCustomMusicMenuActive = false;
		menuMemory[MemoryKeys.ActiveMenu] = (int)MemoryKeys.LevelSelect;
		StopBgm();
		HideMenu();
		SaveManager.SaveGameData();
	}

	protected override void UpdateSelection()
	{
		int inputSign = Mathf.Sign(Input.GetAxis("ui_up", "ui_down"));

		if (inputSign != 0)
		{
			if (!isCustomMusicMenuActive)
				VerticalSelection = WrapSelection(VerticalSelection + inputSign, songOptionList.Count);
			else
				VerticalSelection = WrapSelection(VerticalSelection + inputSign, customSongOptionList.Count);

			UpdateScrollAmount(inputSign);
			MoveCursor();
		}
	}

	private void UpdateScrollAmount(int amount)
	{
		int listSize = songOptionList.Count;

		if (isCustomMusicMenuActive)
			listSize = customSongOptionList.Count;

		if (listSize <= PageSize)
		{
			// Disable scrolling
			scrollAmount = 0;
			scrollRatio = 0;
			cursorPosition = VerticalSelection;
		}
		else
		{
			// Update scroll
			if (VerticalSelection == 0 || VerticalSelection == listSize - 1)
				cursorPosition = scrollAmount = VerticalSelection;
			else if ((amount < 0 && cursorPosition == 1) || (amount > 0 && cursorPosition == 6))
				scrollAmount += amount;
			else
				cursorPosition += amount;

			scrollAmount = Mathf.Clamp(scrollAmount, 0, listSize - PageSize);
			scrollRatio = (float)VerticalSelection / (listSize - 1);
			cursorPosition = Mathf.Clamp(cursorPosition, 0, PageSize - 1);
		}
	}

	private void SnapCursor()
	{
		cursorVelocity = Vector2.Zero;
		cursor.Position = Vector2.Up * -cursorPosition * ScrollInterval;
	}

	private void MoveCursor()
	{
		animator.Play("select");
		animator.Seek(0, true);
		StartSelectionTimer();
	}

	private BGMResource InitializeBgmResource()
	{
		if (!SaveManager.ActiveGameData.selectedMusic.TryGetValue(SelectedLevel.LevelID, out string bgmPath)) // No custom music selected
			return null;

		if (bgmPath.StartsWith("uid://"))
		{
			// Search built-in song list
			for (int i = 0; i < songOptionList.Count; i++)
			{
				if (songOptionList[i].Bgm == null ||
					string.IsNullOrEmpty(songOptionList[i].Bgm.StreamPath))
					continue;

				string file = ResourceUid.IdToText(ResourceLoader.GetResourceUid(songOptionList[i].Bgm.ResourcePath));
				if (!file.Equals(bgmPath))
					continue;

				ScrollSelection(i);
				isCustomMusicMenuActive = false;
				return songOptionList[i].Bgm;
			}
		}

		// Search custom music song list
		for (int i = 0; i < customSongOptionList.Count; i++)
		{
			if (customSongOptionList[i].Bgm == null ||
				string.IsNullOrEmpty(customSongOptionList[i].Bgm.StreamPath) ||
				!customSongOptionList[i].Bgm.StreamPath.Equals(bgmPath))
				continue;

			ScrollSelection(i);
			isCustomMusicMenuActive = true;
			return customSongOptionList[i].Bgm;
		}

		return null; // Invalid song -- use default
	}

	public void ShowSongs()
	{
		for (int i = 0; i < songOptionList.Count; i++)
			songOptionList[i].Visible = true;
	}

	public void HideSongs()
	{
		for (int i = 0; i < songOptionList.Count; i++)
			songOptionList[i].Visible = false;
	}

	private void UnequipSongs()
	{
		for (int i = 0; i < songOptionList.Count; i++)
			songOptionList[i].Unequip();

		if (customSongOptionList.Count > 0)
		{
			for (int i = 0; i < customSongOptionList.Count; i++)
				customSongOptionList[i].Unequip();
		}
	}

	private void ScrollSelection(int targetSelection)
	{
		int initialSelection = VerticalSelection;
		scrollAmount += targetSelection - VerticalSelection;
		VerticalSelection = targetSelection;
		UpdateScrollAmount(0);

		// Reupdate cursor since clamping is applied in UpdateScrollAmount()
		cursorPosition = VerticalSelection - scrollAmount;

		if (!isCustomMusicMenuActive && VerticalSelection != 0 && VerticalSelection != songOptionList.Count - 1)
		{
			// Ensure cursor doesn't get stuck on the edges of the list
			if (cursorPosition == 0) // Top of the list
			{
				cursorPosition++;
				scrollAmount--;
			}
			else if (cursorPosition == PageSize - 1)
			{
				cursorPosition--;
				scrollAmount++;
			}
		}
		else if (isCustomMusicMenuActive && VerticalSelection != 0 && VerticalSelection != customSongOptionList.Count - 1)
		{
			if (cursorPosition == 0) // Top of the list
			{
				cursorPosition++;
				scrollAmount--;
			}
			else if (cursorPosition == PageSize - 1)
			{
				cursorPosition--;
				scrollAmount++;
			}
		}

		if (isProcessing && VerticalSelection != initialSelection)
			MoveCursor();
	}

	private void ReceiveMouseInput(Node node)
	{
		if (!isProcessing)
			return;

		Runtime.Instance.IsUsingMouse = true;

		if (node == null)
		{
			isNothingSelected = true;
			cursorAnimator.Play("hide");
			return;
		}

		isNothingSelected = false;
		int targetIndex = node.GetIndex();
		int sign = targetIndex - VerticalSelection;
		VerticalSelection = targetIndex;
		UpdateScrollAmount(sign);
		MoveCursor();
	}

	private void HideParentNavigationButtons() => parentNavigationButtons.Visible = false;
	private void ShowParentNavigationButtons()
	{
		parentNavigationButtons.Visible = true;
		parentMenu.EnableProcessing();
	}
}

using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class Jukebox : Menu
{
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
	private readonly Array<BGMResource> customSongList = [];

	public LevelDataResource selectedData;

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

	private readonly Array<JukeboxOption> songOptionList = [];
	private readonly Array<JukeboxOption> customSongOptionList = [];
	private bool isCustomMusicMenuActive;
	private readonly string CustomMusicPath = "user://custom/music/";

	protected override void SetUp()
	{
		for (int i = 0; i < songList.Count; i++)
		{
			JukeboxOption newSong = jukeboxOption.Instantiate<JukeboxOption>();
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

		customSongList.Clear();
		customSongOptionList.Clear();
		customSongList.Add(defaultOption);

		if (!DirAccess.DirExistsAbsolute(CustomMusicPath))
			DirAccess.MakeDirRecursiveAbsolute(CustomMusicPath);

		DirAccess dir = DirAccess.Open(CustomMusicPath);
		if (dir == null)
			return;

		foreach (string file in dir.GetFiles()) //Iterates through all files in the custom music directory
		{
			if (!IsValidExtension(file.GetExtension()))
				continue;

			BGMResource bgm = SaveManager.Instance.LoadPRM(CustomMusicPath + file);
			if (bgm == null) // If we can't find a PRM of the current track, create one
			{
				SaveManager.Instance.CreatePRM(file, CustomMusicPath + file);
				bgm = SaveManager.Instance.LoadPRM(CustomMusicPath + file); // Load the PRM into a BGMResource again
			}

			customSongList.Add(bgm);
		}

		for (int i = 0; i < customSongList.Count; i++) // Creates the menu options for the custom songs
		{
			JukeboxOption newSong = jukeboxOption.Instantiate<JukeboxOption>();
			newSong.SetBgmResource(customSongList[i]);
			customSongOptionList.Add(newSong);
			optionContainerSub.AddChild(newSong);
		}
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

	protected override void ProcessMenu()
	{
		if (Runtime.Instance.IsActionJustPressed("sys_sort", "ui_focus_next"))
		{
			if (isCustomMusicMenuActive)
				ShowMenu();
			else
				ShowCustomMusicMenu();
		}

		base.ProcessMenu();
	}

	protected override void Confirm()
	{
		if (VerticalSelection == 0)
		{
			StopBgm();
			if (SaveManager.ActiveGameData.selectedMusic.Remove(selectedData.LevelID))
			{
				animator.Play("equip");
				UpdateSelectionVisuals();
			}
		}
		else
		{
			if (!SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out string selectedBgm))
				selectedBgm = string.Empty;

			string targetBgm = isCustomMusicMenuActive ? customSongOptionList[VerticalSelection].Bgm.StreamPath :
				ResourceUid.IdToText(ResourceLoader.GetResourceUid(songOptionList[VerticalSelection].Bgm.ResourcePath));

			if (targetBgm.Equals(selectedBgm))
				return;

			if (SaveManager.ActiveGameData.selectedMusic.ContainsKey(selectedData.LevelID)) // If our dictionary already contains the ID for the selected level
				SaveManager.ActiveGameData.selectedMusic[selectedData.LevelID] = targetBgm;
			else
				SaveManager.ActiveGameData.selectedMusic.Add(selectedData.LevelID, targetBgm);

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
		if (isCustomMusicMenuActive)
			customSongOptionList[VerticalSelection].Equip();
		else
			songOptionList[VerticalSelection].Equip();
	}

	public override void PlayBgm()
	{
		if (parentMenu.bgm.GetBgmResource() != null)
			parentMenu.bgm.Stop();
		else
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

	public override void ShowMenu()
	{
		worldText.Visible = false;
		VerticalSelection = 0;
		cursorPosition = 0;
		BGMResource newBGM;

		animator.Play(isCustomMusicMenuActive ? "hidesub" : "show");
		isCustomMusicMenuActive = false;

		UnequipSongs();
		UpdateSelection();

		if (SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out string bgmID))
		{
			if (IsValidExtension(bgmID.GetExtension())) // Exits out of the method if we have a custom song, so we don't get errors
				return;

			for (int i = 0; i < songOptionList.Count; i++)
			{
				newBGM = (BGMResource)ResourceLoader.Load(bgmID);

				if (newBGM == null)
					continue;

				if (!songOptionList[i].Bgm.SongName.Equals(newBGM.SongName))
					continue;

				songOptionList[i].Equip();
				return;
			}
		}
		else
		{
			songOptionList[0].Equip();
		}
	}

	private void ShowCustomMusicMenu()
	{
		SetUpCustomMusic();
		isCustomMusicMenuActive = true;

		VerticalSelection = 0;
		cursorPosition = 0;

		animator.Play("showsub");

		UnequipSongs();
		if (SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out string bgmID))
		{
			for (int i = 0; i < customSongOptionList.Count; i++)
			{

				BGMResource newBGM = SaveManager.Instance.LoadPRM(bgmID);
				if (newBGM == null)
					continue;

				if (!customSongOptionList[i].Bgm.SongName.Equals(newBGM.SongName))
					continue;

				customSongOptionList[i].Equip();
				return;
			}

		}
		else
			customSongOptionList[0].Equip();


		UpdateSelection();
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

		if (VerticalSelection != initialSelection)
			MoveCursor();
	}

	private void HideParentNavigationButtons() => parentNavigationButtons.Visible = false;
	private void ShowParentNavigationButtons()
	{
		parentNavigationButtons.Visible = true;
		parentMenu.EnableProcessing();
	}
}

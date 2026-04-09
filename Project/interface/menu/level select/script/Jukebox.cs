using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;


namespace Project.Interface.Menus;

public partial class Jukebox : Menu
{
	[Export] private ResourcePreloader preloader;
	[Export] private BGMResource defaultOption;
	[Export] private PackedScene jukeboxOption;
	[Export] private VBoxContainer optionContainer;
	[Export] private VBoxContainer optionContainerSub;
	[Export] private Node2D cursor;
	[Export] private Sprite2D scrollbar;
	Array<BGMResource> songList;
	Array<BGMResource> songListSub;

	public LevelDataResource selectedData;

	private JukeboxOption SelectedSong => songOptionList[VerticalSelection];

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
	private bool isSubMenuActive;
	private string customPath = "user://custom/music";

	protected override void SetUp()
	{
		songList = [];
		songList.Add(defaultOption);

		for (int i = 0; i < preloader.GetResourceList().Length; i++)
			songList.Add((BGMResource)preloader.GetResource(preloader.GetResourceList()[i]));


		for (int i = 0; i < songList.Count; i++)
		{
			JukeboxOption newSong = jukeboxOption.Instantiate<JukeboxOption>();
			newSong.bgm = songList[i];
			newSong.SetData();

			songOptionList.Add(newSong);
			optionContainer.AddChild(newSong);
		}

		SetUpSub(customPath);


		base.SetUp();
	}

	private void SetUpSub(string path)
	{
		for (int i = 0; i < optionContainerSub.GetChildren().Count; i++)
			optionContainerSub.GetChild(i).QueueFree();

		songListSub = [];
		songListSub.Add(defaultOption);
		customSongOptionList.Clear();

		if (!DirAccess.DirExistsAbsolute(path))
			DirAccess.MakeDirRecursiveAbsolute(path);

		using var dir = DirAccess.Open(path);

		if (dir != null)
		{
			dir.ListDirBegin();
			string fileName = dir.GetNext();
			while (fileName != "")
			{
				if (fileName.GetExtension() == "wav" ||
				fileName.GetExtension() == "ogg" ||
				fileName.GetExtension() == "mp3")
				{
					GD.Print("File scanned: " + fileName);
					BGMResource bgm = new()
					{
						SongName = fileName
					};
					bgm.SetStreamPath(path + "/" + fileName);
					bgm.LoopStart = 0f;
					bgm.LoopEnd = 0f;
					songListSub.Add(bgm);
				}

				fileName = dir.GetNext();
			}

			dir.ListDirEnd();
		}

		for (int i = 0; i < songListSub.Count; i++)
		{
			JukeboxOption newSong = jukeboxOption.Instantiate<JukeboxOption>();
			newSong.bgm = songListSub[i];
			newSong.SetData();

			customSongOptionList.Add(newSong);
			optionContainerSub.AddChild(newSong);
		}

		base.SetUp();

	}

	public override void _Process(double _)
	{
		float targetScrollPosition = 360 * scrollRatio;
		scrollbar.Position = scrollbar.Position.SmoothDamp(Vector2.Right * targetScrollPosition, ref scrollVelocity, ScrollSmoothing);

		// Update cursor position
		float targetCursorPosition = cursorPosition * ScrollInterval;
		cursor.Position = cursor.Position.SmoothDamp(Vector2.Down * targetCursorPosition, ref cursorVelocity, CursorSmoothing);

		if (!isSubMenuActive)
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
		if (Input.IsActionJustPressed("button_attack"))
		{
			if (isSubMenuActive)
				ShowMenu();
			else
				ShowSubMenu();

		}

		base.ProcessMenu();
	}

	protected override void Confirm()
	{
		if (menuMemory[MemoryKeys.ActiveMenu] == (int)MemoryKeys.Jukebox)
		{


			UnequipSongs();
			if (SaveManager.ActiveGameData.selectedMusic.ContainsKey(selectedData.LevelID)) //If our dictionary already contains the ID for the selected level
				SaveManager.ActiveGameData.selectedMusic.Remove(selectedData.LevelID); //Remove the level ID from the dictionary

			if (VerticalSelection != 0) //If we haven't selected the default option
			{
				if (!isSubMenuActive)
				{
					//Add the level ID to the dictionary with the selected song
					SaveManager.ActiveGameData.selectedMusic.Add(selectedData.LevelID, ResourceUid.IdToText(ResourceLoader.GetResourceUid(songOptionList[VerticalSelection].bgm.ResourcePath)));
					bgm.SetBgmResource(songOptionList[VerticalSelection].bgm);
				}
				else
				{
					SaveManager.ActiveGameData.selectedMusic.Add(selectedData.LevelID, customSongOptionList[VerticalSelection].bgm.SongName);
					bgm.SetBgmResource(customSongOptionList[VerticalSelection].bgm);
				}

				SaveManager.SaveGameData();
				bgm.LoadBgmResource();//Loads the selected BGM

				if (parentMenu.bgm.GetBgmResource() != null)
					parentMenu.bgm.Stop();
				else
					parentMenu.parentMenu.bgm.Stop();//When selecting Lost Prologue, load the World Select theme, since 

				bgm.Play();
			}
			else //Switch to the level select theme when hitting "default"
			{

				if (bgm.Playing)
					bgm.Stop();
				if (parentMenu.bgm.GetBgmResource() != null && !parentMenu.bgm.Playing)
					parentMenu.bgm.Play();
				else if (!parentMenu.parentMenu.bgm.Playing)
					parentMenu.parentMenu.bgm.Play();
			}


			SelectedSong.Equip();
			animator.Play("equip");

		}

	}

	protected override void Cancel()
	{
		if (menuMemory[MemoryKeys.ActiveMenu] == (int)MemoryKeys.Jukebox)
		{
			isSubMenuActive = false;
			menuMemory[MemoryKeys.ActiveMenu] = (int)MemoryKeys.LevelSelect;
			animator.Play("hide");
			SaveManager.SaveGameData();

			if (bgm.Playing)
			{
				bgm.Stop();
				if (parentMenu.bgm.GetBgmResource() != null)
					parentMenu.bgm.Play();
				else
					parentMenu.parentMenu.bgm.Play();
			}

		}
	}

	protected override void UpdateSelection()
	{

		if (menuMemory[MemoryKeys.ActiveMenu] == (int)MemoryKeys.Jukebox)
		{
			int inputSign = Mathf.Sign(Input.GetAxis("ui_up", "ui_down"));

			if (inputSign != 0)
			{
				if (!isSubMenuActive)
					VerticalSelection = WrapSelection(VerticalSelection + inputSign, songOptionList.Count);
				else
					VerticalSelection = WrapSelection(VerticalSelection + inputSign, customSongOptionList.Count);

				UpdateScrollAmount(inputSign);
				MoveCursor();
			}
		}

	}

	private void UpdateScrollAmount(int amount)
	{
		int listSize = songOptionList.Count;

		if (isSubMenuActive)
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
		VerticalSelection = 0;
		cursorPosition = 0;
		string bgmID;
		BGMResource bgm;

		if (!isSubMenuActive)
			animator.Play("show");
		else
			animator.Play("hidesub");

		isSubMenuActive = false;
		UnequipSongs();
		for (int i = 0; i < songOptionList.Count; i++)
		{

			if (SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out bgmID))
			{
				bgm = (BGMResource)ResourceLoader.Load(ResourceUid.GetIdPath(ResourceUid.TextToId(bgmID)));
				if (bgm != null)
				{
					if (songOptionList[i].bgm.SongName == bgm.SongName)
					{
						songOptionList[i].Equip();
						return;
					}
				}


			}
		}

		if (!SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out bgmID)) //If we have selected the default song
			songOptionList[0].Equip();

		UpdateSelection();


	}

	private void ShowSubMenu()
	{
		SetUpSub(customPath);
		isSubMenuActive = true;

		VerticalSelection = 0;
		cursorPosition = 0;
		string bgmID;
		BGMResource bgm;

		animator.Play("showsub");
		UnequipSongs();
		for (int i = 0; i < customSongOptionList.Count; i++)
		{

			if (SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out bgmID))
			{

				bgm = GetCustomSong(bgmID);
				if (bgm == null)
					continue;

				if (customSongOptionList[i].bgm.SongName == bgm.SongName)
				{
					customSongOptionList[i].Equip();
					return;
				}

			}
		}

		if (!SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out bgmID)) //If we have selected the default song
			songOptionList[0].Equip();

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
			GD.Print("Custom Song Count: " + customSongOptionList.Count);
			for (int i = 0; i < customSongOptionList.Count; i++)
				customSongOptionList[i].Unequip();
		}

	}

	private BGMResource GetCustomSong(string songName)
	{
		for (int i = 0; i < customSongOptionList.Count; i++)
		{
			if (songName == customSongOptionList[i].bgm.SongName)
				return customSongOptionList[i].bgm;
		}
		return null;

	}

	private void ScrollSelection(int targetSelection)
	{
		int initialSelection = VerticalSelection;
		scrollAmount += targetSelection - VerticalSelection;
		VerticalSelection = targetSelection;
		UpdateScrollAmount(0);

		// Reupdate cursor since clamping is applied in UpdateScrollAmount()
		cursorPosition = VerticalSelection - scrollAmount;

		if (!isSubMenuActive && VerticalSelection != 0 && VerticalSelection != songOptionList.Count - 1)
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
		else if (isSubMenuActive && VerticalSelection != 0 && VerticalSelection != customSongOptionList.Count - 1)
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

}

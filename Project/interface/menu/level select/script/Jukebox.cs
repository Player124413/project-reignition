using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;


namespace Project.Interface.Menus;

public partial class Jukebox : Menu
{

	[Export] private PackedScene jukeboxOption;
	[Export] private VBoxContainer optionContainer;
	[Export] private Node2D cursor;
	[Export] private Sprite2D scrollbar;
	[Export] private Array<BGMResource> songList;

	public LevelDataResource selectedData;

	private JukeboxOption SelectedSong => songOptionList[VerticalSelection];

	private int cursorPosition;
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

	protected override void SetUp()
	{
		//if (SaveManager.Config.useRetailMenuMusic) // Disable bgm
		//bgm = null;

		for (int i = 0; i < songList.Count; i++)
		{
			JukeboxOption newSong = jukeboxOption.Instantiate<JukeboxOption>();
			newSong.bgm = songList[i];
			newSong.SetData();

			songOptionList.Add(newSong);
			optionContainer.AddChild(newSong);
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

		Vector2 targetContainerPosition = new(optionContainer.Position.X, -scrollAmount * ScrollInterval);
		optionContainer.Position = optionContainer.Position.SmoothDamp(targetContainerPosition, ref containerVelocity, ScrollSmoothing);
	}

	protected override void Confirm()
	{
		if (menuMemory[MemoryKeys.ActiveMenu] == (int)MemoryKeys.Jukebox)
		{
			UnequipSongs();

			if (SaveManager.ActiveGameData.selectedMusic.ContainsKey(selectedData.LevelID)) //If our dictionary already contains the ID for the selected level
				SaveManager.ActiveGameData.selectedMusic.Remove(selectedData.LevelID); //Remove the level ID from the dictionary

			if (cursorPosition != 0) //If we haven't selected the default option
			{
				SaveManager.ActiveGameData.selectedMusic.Add(selectedData.LevelID, ResourceUid.IdToText(ResourceLoader.GetResourceUid(songOptionList[cursorPosition].bgm.ResourcePath)));//Add the level ID to the dictionary with the selected song

				bgm.SetBgmResource(songOptionList[cursorPosition].bgm);
				bgm.LoadBgmResource();

				if (parentMenu.bgm.GetBgmResource() != null)
					parentMenu.bgm.Stop();
				else
					parentMenu.parentMenu.bgm.Stop();//This is for lost prologue, since it doesn't have a level select BGM

				bgm.Play();
			}
			else
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
				VerticalSelection = WrapSelection(VerticalSelection + inputSign, songOptionList.Count);
				UpdateScrollAmount(inputSign);
				MoveCursor();
			}
		}

	}

	private void UpdateScrollAmount(int amount)
	{
		int listSize = songOptionList.Count;


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
		string bgmID;
		BGMResource bgm;

		animator.Play("show");
		UnequipSongs();
		for (int i = 0; i < songOptionList.Count; i++)
		{

			if (SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out bgmID))
			{
				bgm = (BGMResource)ResourceLoader.Load(ResourceUid.GetIdPath(ResourceUid.TextToId(bgmID)));
				if (songOptionList[i].bgm.SongName == bgm.SongName)
				{
					songOptionList[i].Equip();
					return;
				}

			}
		}

		if (!SaveManager.ActiveGameData.selectedMusic.TryGetValue(selectedData.LevelID, out bgmID)) //If we have selected the default song
			songOptionList[0].Equip();


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
	}

	private void ScrollSelection(int targetSelection)
	{
		int initialSelection = VerticalSelection;
		scrollAmount += targetSelection - VerticalSelection;
		VerticalSelection = targetSelection;
		UpdateScrollAmount(0);

		// Reupdate cursor since clamping is applied in UpdateScrollAmount()
		cursorPosition = VerticalSelection - scrollAmount;

		if (VerticalSelection != 0 && VerticalSelection != songOptionList.Count - 1)
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

		if (VerticalSelection != initialSelection)
			MoveCursor();
	}

}

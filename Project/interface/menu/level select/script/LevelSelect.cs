using Godot;
using Project.Core;
using Project.Gameplay;
using System.Collections.Generic;

namespace Project.Interface.Menus;

public partial class LevelSelect : Menu
{
	[Export] private SaveManager.WorldEnum world;
	[Export] private string areaKey;
	[Export] private Description description;
	[Export] private ReadyMenu readyMenu;
	[Export] private StatusMenu statusMenu;

	[Export] private Control cursor;
	[Export] private AnimationPlayer cursorAnimator;
	[Export] private Control navigationButtons;
	private float initialCursorPosition;
	private int cursorPosition;
	private Vector2 cursorWidthVelocity;
	private bool isNothingSelected;

	[Export] private Control options;
	private Vector2 optionVelocity;
	[Export] private Sprite2D scrollbar;

	public bool ContainsNewStage { get; private set; }

	private int scrollAmount;
	private float scrollRatio;
	private Vector2 scrollVelocity;
	private const float ScrollSmoothing = .05f;
	private readonly List<LevelOption> levelOptions = [];
	[Export] private Jukebox jukebox;
	[Export] bool isModWorld = false;
	[Export] PackedScene levelOption;

	public bool HasNewLevel()
	{
		foreach (Node node in options.GetChildren())
		{
			if (node is LevelOption levelOption)
			{
				levelOption.UpdateLevelData();

				if (levelOption.IsUnlocked && levelOption.ClearState == SaveManager.LevelSaveData.LevelStatus.New)
					return true;
			}
		}

		return false;
	}

	public bool IsWorldUnlocked()
	{
		if (DebugManager.Instance.UseDemoSave)
		{
			/// For the demo, assume the world is unlocked if a stage is available to play.
			foreach (Node node in options.GetChildren())
			{
				if (node is LevelOption levelOption)
				{
					if (levelOption.IsUnlocked)
						return true;
				}
			}

			return false;
		}

		// For the full release--use the actual save data
		return SaveManager.ActiveGameData.IsWorldUnlocked(world);
	}

	protected override void SetUp()
	{
		if (isModWorld)
			ModSetUp();

		foreach (Node node in options.GetChildren())
		{
			if (node is LevelOption levelOption)
			{
				levelOption.MouseEntered += () => ReceiveMouseInput(levelOption);
				levelOption.MouseExited += () => ReceiveMouseInput(null);
				levelOptions.Add(levelOption);
			}
		}

		initialCursorPosition = cursor.Position.Y;
		base.SetUp();
	}

	private void ModSetUp()
	{

		GD.Print(ModManager.Instance.ModdedLevels.Count);
		foreach (LevelDataResource mod in ModManager.Instance.ModdedLevels)
		{
			LevelOption newOption = levelOption.Instantiate<LevelOption>();
			newOption.data = mod;
			options.AddChild(newOption);
		}
	}

	protected override void ProcessMenu()
	{
		if (statusMenu != null && statusMenu.IsVisibleInTree())
			return;

		if (Runtime.Instance.MouseScrollInput != 0)
		{
			VerticalSelection = Mathf.Clamp(VerticalSelection + Runtime.Instance.MouseScrollInput, 0, levelOptions.Count - 1);
			isNothingSelected = false;
			cursorAnimator.Play("loop");
			ChangeSelection();
		}

		if (levelOptions[VerticalSelection].IsUnlocked)
		{
			if (Runtime.Instance.IsActionJustPressed("sys_pause", "ui_accept") && menuMemory[MemoryKeys.ActiveMenu] != (int)MemoryKeys.TimeAttack)
			{
				menuMemory[MemoryKeys.ActiveMenu] = (int)MemoryKeys.Jukebox;
				OpenBGMMenu();
				DisableProcessing();
			}
		}

		base.ProcessMenu();
		UpdateListPosition(ScrollSmoothing);
	}

	public override void ShowMenu()
	{
		if (menuMemory[MemoryKeys.ActiveMenu] == (int)MemoryKeys.TimeAttack)
		{
			menuMemory[MemoryKeys.LevelSelect] = 0;
			SetUp();
		}

		VerticalSelection = menuMemory[MemoryKeys.LevelSelect];
		RecalculateListPosition();
		UpdateListPosition(0);

		if (Runtime.Instance.IsUsingMouse)
		{
			isNothingSelected = true;
			cursorAnimator.Play("hide");
		}
		else
		{
			isNothingSelected = false;
			cursorAnimator.Play("loop");
		}
		cursorAnimator.Advance(0.0);

		animator.Play("show");

		UpdateDescription();
		for (int i = 0; i < levelOptions.Count; i++)
			levelOptions[i].ShowOption();

		UpdateBgm();
	}

	public void UpdateBgm()
	{
		bool canPlayBgm = !SaveManager.Config.useRetailMenuMusic && IsWorldUnlocked() && bgm.GetBgmResource() != null && !isModWorld;
		if (canPlayBgm && bgm?.Playing == false)
		{
			// Change to world specific level select music
			parentMenu.FadeBgm(.5f);
			FadeBgm(.5f, true, .5f); // Fade in bgm
			CurrentBgmTime = parentMenu.CurrentBgmTime; // Sync bgm
			readyMenu.SetBgmPlayer(bgm); // Update readymenu's bgm player
		}
		else if (!canPlayBgm)
		{
			// As a fallback, play the parent menu's bgm (won't do anything if parent bgm is already playing)
			parentMenu.PlayBgm();
			readyMenu.SetBgmPlayer(parentMenu.bgm);
		}
	}

	public override void HideMenu()
	{
		for (int i = 0; i < levelOptions.Count; i++)
			levelOptions[i].HideOption();
	}

	protected override void Confirm()
	{
		if (TimeAttackManager.Instance.IsRunActive && TimeAttackManager.Instance.CurrentRunType != TimeAttackManager.RunType.SingleRun)
			return;

		if (isNothingSelected)
			return;

		if (!levelOptions[VerticalSelection].IsUnlocked)
			return;

		base.Confirm();
	}

	protected override void Cancel()
	{
		base.Cancel();

		// Revert bgm music
		if (bgm?.Playing == true)
		{
			FadeBgm(.5f); // Fade out bgm
			parentMenu.FadeBgm(.5f, true, .5f); // Fade in parent bgm
			parentMenu.CurrentBgmTime = CurrentBgmTime; // Sync bgm
		}
	}

	/// <summary> Shows the "Are you ready?" screen. </summary>
	public override void OpenSubmenu()
	{
		if (TimeAttackManager.Instance.IsRunActive && TimeAttackManager.Instance.CurrentRunType == TimeAttackManager.RunType.SingleRun)
			TimeAttackManager.Instance.Level_Single = levelOptions[VerticalSelection].data;

		readyMenu.SetMapText(areaKey);
		readyMenu.SetMissionText(levelOptions[VerticalSelection].data.MissionTypeKey);
		readyMenu.parentMenu = this;
		readyMenu.LevelData = levelOptions[VerticalSelection].data;
		readyMenu.ShowMenu();
	}

	private void OpenBGMMenu()
	{
		jukebox.SelectedLevel = levelOptions[VerticalSelection].data;
		jukebox.ShowMenu();
	}

	protected override void UpdateSelection()
	{
		if (Mathf.IsZeroApprox(Input.GetAxis("ui_up", "ui_down")))
			return;

		if (menuMemory[MemoryKeys.ActiveMenu] == (int)MemoryKeys.Jukebox)
			return;

		if (isNothingSelected)
		{
			isNothingSelected = false;
			cursorAnimator.Play("loop");
			return;
		}

		VerticalSelection = WrapSelection(VerticalSelection + Mathf.Sign(Input.GetAxis("ui_up", "ui_down")), levelOptions.Count);
		ChangeSelection();
	}

	private void ChangeSelection()
	{
		menuMemory[MemoryKeys.LevelSelect] = VerticalSelection;
		animator.Play("select");
		animator.Seek(0, true);

		UpdateDescription();
		StartSelectionTimer();
		RecalculateListPosition();
	}

	private void UpdateDescription()
	{
		description.ShowDescription();
		description.Text = levelOptions[VerticalSelection].GetDescription();
	}

	private void RecalculateListPosition()
	{
		cursorPosition = VerticalSelection;
		if (levelOptions.Count > 5)
		{
			if (VerticalSelection < 3)
			{
				scrollRatio = 0;
				scrollAmount = 0;
			}
			else if (VerticalSelection >= levelOptions.Count - 3)
			{
				scrollRatio = 1;
				scrollAmount = levelOptions.Count - 5;
				cursorPosition = 4 - (levelOptions.Count - 1 - VerticalSelection);
			}
			else
			{
				scrollAmount = VerticalSelection - 2;
				scrollRatio = (VerticalSelection - 2) / (levelOptions.Count - 5.0f);
				cursorPosition = 2;
			}
		}
	}

	private void UpdateListPosition(float smoothing)
	{
		float targetScrollPosition = 360 * (VerticalSelection / (levelOptions.Count - 1f));
		scrollbar.Position = scrollbar.Position.SmoothDamp(Vector2.Right * targetScrollPosition, ref scrollVelocity, smoothing);

		cursor.Position = cursor.Position.SmoothDamp(new(cursor.Position.X, initialCursorPosition + (96 * cursorPosition)), ref cursorWidthVelocity, smoothing);
		options.Position = options.Position.SmoothDamp(Vector2.Up * ((96 * scrollAmount) - 32), ref optionVelocity, smoothing);
	}

	private void ReceiveMouseInput(LevelOption node)
	{
		if (!isProcessing)
			return;

		if (node == null)
		{
			isNothingSelected = true;
			cursorAnimator.Play("hide");
			return;
		}

		Runtime.Instance.IsUsingMouse = true;
		cursorAnimator.Play("loop");
		isNothingSelected = false;
		VerticalSelection = levelOptions.IndexOf(node);
		ChangeSelection();
	}

	public List<LevelOption> GetLevelOptions()
	{
		return levelOptions;
	}
}

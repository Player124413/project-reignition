using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class SaveSelect : Menu
{
	[Export] private LevelDataResource initialLevelData;
	[Export] private Sprite2D scrollbar;
	private Vector2 scrollbarVelocity;
	private float scrollRatio;
	private const int ScrollbarHeight = 625;
	private const float ScrollSmoothing = .05f;

	[Export] private Array<NodePath> saveOptions = [];
	private readonly Array<SaveOption> _saveOptions = [];
	private const int ActiveSaveOptionIndex = 3; // Corresponds to the center save option

	[Export] private AnimationPlayer deleteAnimator;
	private bool isDeleteMenuActive;
	private bool isDeleteSelected;

	[Export] private string descriptionText;
	[Export] private Description description;

	protected override void SetUp()
	{
		if (menuMemory[MemoryKeys.ActiveMenu] != (int)MemoryKeys.TimeAttack)//If the last menu selected was time attack, DON'T set the memory keys
			VerticalSelection = menuMemory[MemoryKeys.SaveSelect];

		scrollRatio = VerticalSelection / (SaveManager.SaveSlotCount - 1.0f);

		for (int i = 0; i < saveOptions.Count; i++)
		{
			SaveOption option = GetNode<SaveOption>(saveOptions[i]);
			_saveOptions.Add(option);
			option.SetUp();
		}
	}

	public override void _PhysicsProcess(double _)
	{
		base._PhysicsProcess(_);
		scrollbar.Position = scrollbar.Position.SmoothDamp(Vector2.Right * ScrollbarHeight * scrollRatio, ref scrollbarVelocity, ScrollSmoothing);
	}

	protected override void ProcessMenu()
	{
		if (Runtime.Instance.IsActionJustPressed("sys_clear", "ui_text_delete"))
		{
			if (isDeleteMenuActive)
				CancelDeleteMenu();
			else
				ShowDeleteMenu();

			return;
		}

		if (Runtime.Instance.MouseScrollInput != 0)
		{
			ScrollSelection(Runtime.Instance.MouseScrollInput);
			return;
		}

		base.ProcessMenu();
	}

	protected override void Confirm()
	{
		if (isDeleteMenuActive)
		{
			if (isDeleteSelected)
			{
				deleteAnimator.Play("confirm");
				DeleteSaveFile();
				isDeleteMenuActive = false;
			}
			else
			{
				CancelDeleteMenu();
			}

			return;
		}

		base.Confirm();
	}

	protected override void Cancel()
	{
		if (isDeleteMenuActive)
		{
			CancelDeleteMenu();
			return;
		}

		if (menuMemory[MemoryKeys.ActiveMenu] != (int)MemoryKeys.TimeAttack)
			base.Cancel();
		else
		{
			parentMenu.PlayReturnAnim();
			animator.Play("cancel-for-time-attack");
		}
	}

	private void ShowDeleteMenu()
	{
		int saveIndex = _saveOptions[ActiveSaveOptionIndex].SaveIndex;
		if (SaveManager.GameSaveSlots[saveIndex].IsNewFile()) // Check if a save file is new
			return;

		deleteAnimator.Play("show");
		isDeleteMenuActive = true;
		isDeleteSelected = false;
	}

	protected override void UpdateSelection()
	{
		if (isDeleteMenuActive)
		{
			int input = Mathf.Sign(Input.GetAxis("ui_left", "ui_right"));
			if ((input > 0 && isDeleteSelected) ||
				(input < 0 && !isDeleteSelected))
			{
				isDeleteSelected = !isDeleteSelected;
				deleteAnimator.Play(isDeleteSelected ? "select-yes" : "select-no");
			}

			return;
		}

		// Only listen for vertical scrolling
		int inputSign = Mathf.Sign(Input.GetAxis("ui_up", "ui_down"));
		if (inputSign == 0) return;
		ScrollSelection(inputSign);
	}

	private void ScrollSelection(int inputSign)
	{
		if (!Mathf.IsZeroApprox(cursorSelectionTimer))
			return;

		VerticalSelection = WrapSelection(VerticalSelection + inputSign, SaveManager.SaveSlotCount);
		animator.Play(inputSign < 0 ? ScrollUpAnimation : ScrollDownAnimation);
		scrollRatio = VerticalSelection / (SaveManager.SaveSlotCount - 1.0f);
		menuMemory[MemoryKeys.SaveSelect] = VerticalSelection;

		if (!isSelectionScrolling)
			StartSelectionTimer();
	}

	public override void OpenSubmenu()
	{
		menuMemory[MemoryKeys.LevelSelect] = 0;
		menuMemory[MemoryKeys.SkillMenuInitialized] = 0;
		SaveManager.ActiveSaveSlotIndex = _saveOptions[ActiveSaveOptionIndex].SaveIndex;
		SaveManager.ActiveGameData.UnlockStagesRecursively(initialLevelData);
		SaveManager.ActiveSkillRing.LoadFromActiveData();
		NotificationManager.Instance.UpdateCounters();

		// Update next story level
		SaveManager.ActiveGameData.LoadCurrentStoryLevelFromSaveData();

		if (SaveManager.ActiveGameData.IsNewFile() || Mathf.IsZeroApprox(SaveManager.ActiveGameData.playTime))
		{
			SaveManager.ResetSaveData(SaveManager.ActiveSaveSlotIndex, false);
			SaveManager.SaveGameData();

			if (menuMemory[MemoryKeys.ActiveMenu] != (int)MemoryKeys.TimeAttack) // Only load a scene if we aren't in Time Attack
			{
				if (!DebugManager.Instance.UseDemoSave) // Don't load into cutscenes in the demo
				{
					// Load directly into the first cutscene
					TransitionManager.QueueSceneChange($"{TransitionManager.EventScenePath}Event1.tscn");
					TransitionManager.StartTransition(new()
					{
						color = Colors.Black,
						inSpeed = 1f,
					});
					return;
				}
			}
		}

		if (DebugManager.Instance.UseDemoSave) // Unlock all worlds in the demo
			SaveManager.ActiveGameData.UnlockAllWorlds();

		menuMemory[MemoryKeys.WorldSelect] = (int)SaveManager.ActiveGameData.lastPlayedWorld; // Set the world selection to the last played world
		_submenus[0].ShowMenu();

		DebugManager.Instance.OnSkillSelected(-1); // Update Debug Menu
	}

	public override void ShowMenu()
	{
		SaveManager.LoadGameData(); // Check for file updates
		base.ShowMenu();
	}

	private void CancelDeleteMenu()
	{
		if (isDeleteSelected)
		{
			deleteAnimator.Play("select-no");
			deleteAnimator.Advance(0.0);
		}

		isDeleteMenuActive = false;
		deleteAnimator.Play("hide");
	}

	/// <summary> Deletes the currently selected save file. </summary>
	private void DeleteSaveFile()
	{
		int saveIndex = _saveOptions[ActiveSaveOptionIndex].SaveIndex; // Get the currently selected save index

		SaveManager.ResetSaveData(saveIndex, true); // Reset SaveManager's loaded GameData
		SaveManager.DeleteSaveData(saveIndex); // Move the save game's file to the system trash

		UpdateSaveOptions();
	}

	/// <summary>  Updates the visual data on all save options. </summary>
	public void UpdateSaveOptions()
	{
		for (int i = 0; i < _saveOptions.Count; i++)
		{
			int saveIndex = VerticalSelection + (i - ActiveSaveOptionIndex);
			saveIndex = WrapSelection(saveIndex, SaveManager.SaveSlotCount);
			_saveOptions[i].SaveIndex = saveIndex;
		}
	}

	public void SetDescriptionText() => description.Text = descriptionText;

	private void ReceiveMouseInput(int direction)
	{
		if (!isProcessing)
			return;

		ScrollSelection(direction);
		Runtime.Instance.IsUsingMouse = true;
	}
}

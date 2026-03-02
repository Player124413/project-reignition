using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class TimeAttack : Menu
{
	[Export] AnimationPlayer timeAttackAnimator;
	[Export] private Description description;
	[Export] private TimeAttackReady readyMenu;
	[Export] private TextureRect buttonImage;
	[Export] private AnimationPlayer buttonImageAnimator;
	[Export] Array<TimeAttackButton> buttonList;
	private bool isActive;
	private int currentSelection;
	private int maxSelection = 4;

	protected override void SetUp()
	{
		currentSelection = 1;
	}

	public override void ShowMenu()
	{
		base.ShowMenu();
		currentSelection = 1;
		description.Text = buttonList[0].description;
		menuMemory[MemoryKeys.ActiveMenu] = (int)MemoryKeys.TimeAttack;

		if (!bgm.Playing)
			bgm.Play();


		DebugManager.Instance.ToggleDemoSave(true);
		SaveManager.ActiveSaveSlotIndex = SaveManager.SaveSlotCount; //Saves skills and presets on a hidden file
		SaveManager.ActiveGameData.UnlockAllWorlds();
		SaveManager.ActiveGameData.level = 99;
		SaveManager.ActiveSkillRing.UpdateTotalSkillPoints();


	}

	public override void OpenParentMenu()
	{
		// Return to main menu
		FadeBgm(.5f);
		menuMemory[MemoryKeys.ActiveMenu] = (int)MemoryKeys.MainMenu;
		TransitionManager.QueueSceneChange(TransitionManager.MenuScenePath);
		TransitionManager.StartTransition(new()
		{
			color = Colors.Black,
			inSpeed = .5f,
		});
	}

	protected override void ProcessMenu()
	{

		base.ProcessMenu();
	}

	protected override void UpdateSelection()
	{
		Vector2I input = new(Mathf.Sign(Input.GetAxis("ui_left", "ui_right")), Mathf.Sign(Input.GetAxis("ui_up", "ui_down")));
		StartSelectionTimer();

		ProcessMenuInput(input);
	}

	private void ProcessMenuInput(Vector2I input)
	{
		if (isActive)
		{
			currentSelection += input.Y;
			if (currentSelection > maxSelection || currentSelection < 1)
				currentSelection = WrapSelection(currentSelection, maxSelection, 1);

			if (input.X == 0)
			{
				description.Text = buttonList[currentSelection - 1].description;
				description.ShowDescription();
			}

			for (int i = 0; i < buttonList.Count; i++)
			{
				buttonList[i].DeselectButton();
			}
			buttonImageAnimator.Play("show");
			buttonList[currentSelection - 1].SelectButton();
		}
		else
			return;
	}

	protected override void Confirm()
	{

		if (isActive)
		{
			TimeAttackManager.Instance.SetRunActive(true);
			switch (currentSelection)
			{
				case 2:
					TimeAttackManager.Instance.SetRunType(TimeAttackManager.RunType.Custom);
					break;
				case 3:
					TimeAttackManager.Instance.SetRunType(TimeAttackManager.RunType.SingleRun);
					GD.Print("Setting to single run");
					break;
			}
			timeAttackAnimator.Play("confirm-" + currentSelection);
			currentSelection = 1;
			TimeAttackManager.Instance.ClearCurrentRun();
			TimeAttackManager.Instance.ClearCurrentSavedRun();

		}

	}

	protected override void Cancel()
	{
		if (isActive)
		{
			DebugManager.Instance.ToggleDemoSave(false);
			SaveManager.SaveTimeAttackData();
			SaveManager.SaveGameData();
			TimeAttackManager.Instance.SetRunActive(false);

			OpenParentMenu();
			currentSelection = 1;
		}

	}

	public override void PlayReturnAnim() => timeAttackAnimator.Play("show");
	public void SetActive() => isActive = true;
	public void SetInactive() => isActive = false;

	public void ChangeButtonImage() => buttonImage.Texture = buttonList[currentSelection - 1].image;

}

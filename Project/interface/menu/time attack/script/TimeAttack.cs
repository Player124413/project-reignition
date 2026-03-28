using System.Linq;
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
	private int maxSelection = 2;
	private bool isRunInProgress = false;

	protected override void SetUp()
	{
		currentSelection = 1;
	}

	public override void ShowMenu()
	{
		if (SaveManager.TimeData.RunInProgress.Count > 0)
		{
			maxSelection = 3;
			isRunInProgress = true;
		}
		else
		{
			maxSelection = 2;
			isRunInProgress = false;
		}

		if (!isRunInProgress)
			animator.Play("show");
		else
			animator.Play("showcontinue");

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

		// Return to main menuSceneChange(TransitionManager.MenuScenePath);
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
		if (isReturnMenuActive)
		{
			int inputReturn = Mathf.Sign(Input.GetAxis("ui_left", "ui_right"));
			if ((inputReturn > 0 && isReturnSelected) || (inputReturn < 0 && !isReturnSelected))
			{
				isReturnSelected = !isReturnSelected;
				returnAnimator.Play(isReturnSelected ? "select-yes" : "select-no");
			}

			return;
		}
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
			if (isRunInProgress)
				buttonList[currentSelection - 1].SelectButton();
			else
			{
				switch (currentSelection)
				{
					case 1:
						buttonList[0].SelectButton();
						break;
					case 2:
						buttonList[2].SelectButton();
						description.Text = buttonList[2].description;
						break;
				}
			}
		}
		else
			return;
	}

	protected override void Confirm()
	{

		if (isActive)
		{
			if (isReturnMenuActive)
			{
				if (isReturnSelected)
				{
					ContinueRun();
				}
				else
				{
					isReturnMenuActive = false;
					returnAnimator.Play("hide");
					timeAttackAnimator.Play("confirm-1no");
				}
			}
			else
			{
				TimeAttackManager.Instance.SetRunActive(true);

				if (!isRunInProgress)
				{
					switch (currentSelection)
					{
						case 2:
							TimeAttackManager.Instance.SetRunType(TimeAttackManager.RunType.SingleRun);
							TimeAttackManager.Instance.ClearCurrentRun();
							TimeAttackManager.Instance.ClearCurrentSavedRun();
							break;
					}
					timeAttackAnimator.Play("confirm-" + currentSelection);
					currentSelection = 1;
				}
				else
				{
					switch (currentSelection)
					{
						case 1:
							timeAttackAnimator.Play("confirm-1continue");
							ShowReturnMenu();
							break;
						case 2:
							timeAttackAnimator.Play("confirm-2continue");
							ContinueRun();
							break;
						case 3:
							timeAttackAnimator.Play("confirm-2");
							currentSelection = 1;
							TimeAttackManager.Instance.ClearCurrentRun();
							TimeAttackManager.Instance.ClearCurrentSavedRun();
							break;
					}
				}
			}


		}

	}

	protected override void Cancel()
	{
		if (isActive)
		{
			if (!isReturnMenuActive)
			{
				DebugManager.Instance.ToggleDemoSave(false);
				SaveManager.SaveTimeAttackData();
				SaveManager.SaveGameData();
				TimeAttackManager.Instance.SetRunActive(false);

				OpenParentMenu();
				currentSelection = 1;
			}
			else
				CancelReturnMenu();

		}

	}

	private void ContinueRun()
	{
		TimeAttackManager.Instance.SetRunActive(true);
		TimeAttackManager.Instance.SetReturnTimes();
		TimeAttackManager.Instance.SetRunType(SaveManager.TimeData.CurrentRunType);
		TimeAttackManager.Instance.LoadLevel(TimeAttackManager.Instance.GetCurrentLevel());

	}

	[Export]
	private AnimationPlayer returnAnimator;
	private bool isReturnMenuActive = false;
	private bool isReturnSelected;

	private void ShowReturnMenu()
	{
		isReturnMenuActive = true;
		isReturnSelected = true;

		returnAnimator.Advance(0.0);

		returnAnimator.Play("select-yes");
		returnAnimator.Advance(0.0);

		returnAnimator.Play("show");
	}
	private void CancelReturnMenu()
	{

		if (isReturnSelected)
		{
			returnAnimator.Play("select-no");
			returnAnimator.Advance(0.0);
		}

		isReturnMenuActive = false;
		returnAnimator.Play("hide");
	}

	public override void PlayReturnAnim() => timeAttackAnimator.Play("show");
	public void SetActive() => isActive = true;
	public void SetInactive() => isActive = false;

	public void ChangeButtonImage() => buttonImage.Texture = buttonList[currentSelection - 1].image;

}

using Godot;
using System;
using Godot.Collections;
using Project.Core;

namespace Project.Interface.Menus;

public partial class TimeAttackStartRun : Menu
{
	[Export] private Description description;
	[Export] TimeAttackReady readyMenu;
	[Export] TimeAttackLevelList levelList;
	[Export] Array<TimeAttackButton> buttonList;

	private bool isActive;
	private int currentSelection;
	private int maxSelection = 2;

	protected override void SetUp()
	{
		currentSelection = 1;
	}

	public override void ShowMenu()
	{
		base.ShowMenu();
		currentSelection = 1;
		description.Text = buttonList[0].description;
	}

	public override void OpenParentMenu()
	{
		base.OpenParentMenu();
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
			buttonList[currentSelection - 1].SelectButton();
		}
		else
			return;
	}

	protected override void Confirm()
	{
		if (isActive)
		{
			if (currentSelection == 1)
				readyMenu.SetupReadyMenu();
			animator.Play("confirm-" + currentSelection);
			currentSelection = 1;
		}
	}

	protected override void Cancel()
	{
		if (isActive)
			animator.Play("hide");
	}

	private void OpenLevelList()
	{
		levelList.Visible = true;
		levelList.parentMenu = this;
		levelList.ShowMenu();
	}
	private void OpenReadyMenu()
	{
		readyMenu.ShowMenu();
	}

	public void SetActive() => isActive = true;
	public void SetInactive() => isActive = false;
}

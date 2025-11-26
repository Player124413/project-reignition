using Godot;
using Godot.Collections;
using Project.Core;

namespace Project.Interface.Menus;

public partial class TimeAttackNewRun : Menu
{
	[Export] AnimationPlayer newRunAnimator;
	[Export] private Description description;
	[Export] TimeAttack thisParent;
	[Export] SaveSelect saveSelect;
	[Export] ReadyMenu readyMenu;
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
				description.ShowDescription();
			newRunAnimator.Play("select-" + currentSelection);
		}
		else
			return;
	}

	protected override void Confirm()
	{
		if (isActive)
			if (currentSelection == 3) //Only goal percent is in this version
			{
				TimeAttackManager.Instance.ResetLevelCount();
				TimeAttackManager.Instance.SetRunType(TimeAttackManager.RunType.GoalPercent);


				readyMenu.SetupReadyMenu(TimeAttackManager.Instance.GetCurrentRunLevels(TimeAttackManager.Instance.CurrentRunType)[0]);
				newRunAnimator.Play("confirm-" + currentSelection);
			}

	}

	protected override void Cancel()
	{
		if (isActive)
			newRunAnimator.Play("hide");
	}

	public void PlayReturnAnimParent(int selection) => thisParent.PlayReturnAnim(selection);
	public override void PlayReturnAnim()
	{
		newRunAnimator.Play("return-" + currentSelection);
	}
	public void SetActive() => isActive = true;
	public void SetInactive() => isActive = false;

	public void OpenSaveSelect()
	{
		saveSelect.Visible = true;
		saveSelect.parentMenu = this;
		saveSelect.ShowMenu();
	}
}

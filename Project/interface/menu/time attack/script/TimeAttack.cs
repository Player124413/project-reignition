using Godot;
using Godot.Collections;
using Project.Core;

namespace Project.Interface.Menus;

public partial class TimeAttack : Menu
{
	[Export] AnimationPlayer timeAttackAnimator;
	[Export] private Description description;
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
		menuMemory[MemoryKeys.ActiveMenu] = (int)MemoryKeys.TimeAttack;
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
		description.ShowDescription();
		ProcessMenuInput(input);
	}

	private void ProcessMenuInput(Vector2I input)
	{
		if (isActive)
		{
			currentSelection += input.Y;
			if (currentSelection > maxSelection || currentSelection < 1)
				currentSelection = WrapSelection(1, maxSelection);

			timeAttackAnimator.Play("select-" + currentSelection);
		}
		else
			return;
	}

	protected override void Confirm()
	{
		if (isActive)
			timeAttackAnimator.Play("confirm-" + currentSelection);
	}

	protected override void Cancel()
	{
		if (isActive)
			OpenParentMenu();
	}

	public void SetActive() => isActive = true;
	public void SetInactive() => isActive = false;
}

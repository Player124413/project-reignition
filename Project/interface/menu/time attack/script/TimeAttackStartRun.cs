using Godot;
using Godot.Collections;
using Project.Core;

namespace Project.Interface.Menus;

public partial class TimeAttackStartRun : Menu
{
	[Export] private Description description;
	[Export] TimeAttackReady readyMenu;
	[Export] TimeAttackLevelList levelList;
	[Export] TimeAttackLeaderboard leaderboard;
	[Export] Array<TimeAttackButton> buttonList;
	[Export] private PackedScene levelOption;

	private bool isLeaderboardActive;
	private int currentSelection = 1;
	private int maxSelection = 2;

	public override void ShowMenu()
	{
		base.ShowMenu();
		SaveManager.LoadTimeAttackData();
		isLeaderboardActive = false;
		leaderboard.SpawnLeaderboardOptionsSub();
		leaderboard.SpawnLeaderboardOptionsMain();
	}

	public override void EnableProcessing()
	{
		base.EnableProcessing();
		RedrawSelection();
	}

	protected override void UpdateSelection()
	{
		Vector2I input = new(Mathf.Sign(Input.GetAxis("ui_left", "ui_right")), Mathf.Sign(Input.GetAxis("ui_up", "ui_down")));
		StartSelectionTimer();
		ProcessMenuInput(input);
	}

	private void ProcessMenuInput(Vector2I input)
	{
		if (isLeaderboardActive)
		{
			if (input.X != 0)
			{
				Runtime.Instance.IsUsingMouse = false;
				ExitLeaderboard();
			}

			return;
		}

		if (!isLeaderboardActive)
		{
			Runtime.Instance.IsUsingMouse = false;

			if (input.X != 0)
			{
				EnterLeaderboard();
				return;
			}

			currentSelection += input.Y;
			if (currentSelection > maxSelection || currentSelection < 1)
				currentSelection = WrapSelection(currentSelection, maxSelection, 1);

			RedrawSelection();
		}
	}

	private void EnterLeaderboard()
	{
		if (isLeaderboardActive)
			return;

		leaderboard.EnableProcessing();
		isLeaderboardActive = true;
		for (int i = 0; i < buttonList.Count; i++)
			buttonList[i].DeselectButton();
		leaderboard.ShowMenu();
	}

	private void ExitLeaderboard()
	{
		if (!isLeaderboardActive)
			return;

		leaderboard.DisableProcessing();
		buttonList[currentSelection - 1].SelectButton();
		leaderboard.DeselectMenu();
		isLeaderboardActive = false;
	}

	private void RedrawSelection()
	{
		for (int i = 0; i < buttonList.Count; i++)
			buttonList[i].DeselectButton();

		buttonList[currentSelection - 1].SelectButton();

		description.Text = buttonList[currentSelection - 1].description;
		description.ShowDescription();
	}

	protected override void Confirm()
	{
		if (isLeaderboardActive)
			return;

		if (currentSelection == 1)
			readyMenu.SetupReadyMenu();
		animator.Play("confirm-" + currentSelection);
	}

	protected override void Cancel()
	{
		if (!isLeaderboardActive)
			animator.Play("hide");
	}

	private void OpenLevelList()
	{
		levelList.Visible = true;
		levelList.parentMenu = this;
		levelList.ShowMenu();
	}

	private void OpenReadyMenu() => readyMenu.ShowMenu();

	private void ReceiveMouseInput(int selection)
	{
		if (currentSelection == selection)
			return;

		Runtime.Instance.IsUsingMouse = true;
		currentSelection = selection;
		if (isProcessing)
			RedrawSelection();
	}
}

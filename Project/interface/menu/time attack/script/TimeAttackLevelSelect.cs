using Godot;
using Project.Core;
using System.Collections.Generic;

namespace Project.Interface.Menus;

public partial class TimeAttackLevelSelect : Menu
{
	[Export] private Description description;
	[Export] private Control clip;

	[Export] private Control cursor;
	private float initialCursorPosition;
	private int cursorPosition;
	private Vector2 cursorWidthVelocity;

	[Export] private Control options;
	private Vector2 optionVelocity;
	[Export] private Sprite2D scrollbar;

	private int scrollAmount;
	private float scrollRatio;
	private Vector2 scrollVelocity;
	private const float ScrollSmoothing = .05f;
	private readonly List<LevelOption> levelOptions = [];


	protected override void SetUp()
	{
		foreach (Node node in options.GetChildren())
		{
			if (node is LevelOption levelOption)
				levelOptions.Add(levelOption);
		}

		initialCursorPosition = cursor.Position.Y;
		base.SetUp();
	}

	protected override void ProcessMenu()
	{
		base.ProcessMenu();
		UpdateListPosition(ScrollSmoothing);
	}

	public override void ShowMenu()
	{
		menuMemory[MemoryKeys.LevelSelect] = 0;
		SetUp();

		VerticalSelection = menuMemory[MemoryKeys.LevelSelect];
		RecalculateListPosition();
		UpdateListPosition(0);

		animator.Play("show");

		for (int i = 0; i < levelOptions.Count; i++)
			levelOptions[i].EnableTAInfo();
	}

	public override void HideMenu()
	{
		for (int i = 0; i < levelOptions.Count; i++)
			levelOptions[i].HideOption();
	}

	protected override void Confirm()
	{
		Cancel();
	}

	protected override void Cancel()
	{
		base.Cancel();

		HideMenu();
		cursorPosition = 0;
		levelOptions.Clear();

		parentMenu.OpenParentMenu();
	}

	protected override void UpdateSelection()
	{
		if (Mathf.IsZeroApprox(Input.GetAxis("ui_up", "ui_down"))) return;

		VerticalSelection = WrapSelection(VerticalSelection + Mathf.Sign(Input.GetAxis("ui_up", "ui_down")), levelOptions.Count);

		//menuMemory[MemoryKeys.LevelSelect] = VerticalSelection;
		animator.Play("select");
		animator.Seek(0, true);

		//if (menuMemory[MemoryKeys.ActiveMenu] != (int)MemoryKeys.TimeAttack)
		//UpdateDescription();
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
}

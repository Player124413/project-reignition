using Godot;
using Project.Core;
using System.Collections.Generic;

namespace Project.Interface.Menus;

public partial class TimeAttackLeaderboard : Menu
{
	[Export] private Description description;
	[Export] private Control clip;

	[Export] private Control cursor;
	[Export] private AnimationPlayer cursorAnimator;
	private float initialCursorPosition;
	private int cursorPosition;
	private Vector2 cursorWidthVelocity;

	[Export] private Control options;
	[Export] private Control optionsSub;
	private Vector2 optionVelocity;
	[Export] private Sprite2D scrollbar;

	private int scrollAmount;
	private float scrollRatio;
	private Vector2 scrollVelocity;
	private const float ScrollSmoothing = .05f;
	private readonly List<TimeAttackLeaderboardOptionMain> leaderboardOptionsMain = [];

	private bool isActive;
	private bool isSubActive;


	protected override void SetUp()
	{
		foreach (Node node in options.GetChildren())
		{
			if (node is TimeAttackLeaderboardOptionMain optionMain)
				leaderboardOptionsMain.Add(optionMain);
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
		//SetUp();
		cursor.Visible = true;
		cursorAnimator.Seek(0);
		VerticalSelection = 0;
		isActive = true;
		RecalculateListPosition();
		UpdateListPosition(0);

	}

	public void DeselectMenu()
	{
		cursor.Visible = false;
		isActive = false;
	}

	protected override void Confirm()
	{

	}

	protected override void Cancel()
	{

	}

	protected override void UpdateSelection()
	{
		if (Mathf.IsZeroApprox(Input.GetAxis("ui_up", "ui_down"))) return;

		VerticalSelection = WrapSelection(VerticalSelection + Mathf.Sign(Input.GetAxis("ui_up", "ui_down")), leaderboardOptionsMain.Count);
		GD.Print("Moved Cursor");

		//animator.Play("select");
		//animator.Seek(0, true);

		StartSelectionTimer();
		RecalculateListPosition();
	}

	private void RecalculateListPosition()
	{
		cursorPosition = VerticalSelection;
		if (leaderboardOptionsMain.Count > 5)
		{
			if (VerticalSelection < 3)
			{
				scrollRatio = 0;
				scrollAmount = 0;
			}
			else if (VerticalSelection >= leaderboardOptionsMain.Count - 3)
			{
				scrollRatio = 1;
				scrollAmount = leaderboardOptionsMain.Count - 5;
				cursorPosition = 4 - (leaderboardOptionsMain.Count - 1 - VerticalSelection);
			}
			else
			{
				scrollAmount = VerticalSelection - 2;
				scrollRatio = (VerticalSelection - 2) / (leaderboardOptionsMain.Count - 5.0f);
				cursorPosition = 2;
			}
		}
	}

	private void UpdateListPosition(float smoothing)
	{
		float targetScrollPosition = 360 * (VerticalSelection / (leaderboardOptionsMain.Count - 1f));
		scrollbar.Position = scrollbar.Position.SmoothDamp(Vector2.Right * targetScrollPosition, ref scrollVelocity, smoothing);

		cursor.Position = cursor.Position.SmoothDamp(new(cursor.Position.X, initialCursorPosition + (119 * cursorPosition)), ref cursorWidthVelocity, smoothing);
		options.Position = options.Position.SmoothDamp(Vector2.Up * ((119 * scrollAmount)), ref optionVelocity, smoothing);
	}
}

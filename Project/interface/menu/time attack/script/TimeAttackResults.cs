using Godot;
using Project.Core;
using System.Collections.Generic;

namespace Project.Interface.Menus;


public partial class TimeAttackResults : Menu
{
	[Export] private Control cursor;
	private float initialCursorPosition;
	private int cursorPosition;
	private Vector2 cursorWidthVelocity;

	[Export] private VBoxContainer options;
	private Vector2 optionVelocity;
	[Export] private Sprite2D scrollbar;

	private int scrollAmount;
	private float scrollRatio;
	private Vector2 scrollVelocity;
	private const float ScrollSmoothing = .05f;
	[Export] private Label totalTimeLabel;
	[Export] private PackedScene resultOptionScene;
	private readonly List<TimeAttackResultsOption> resultsOption = [];

	protected override void SetUp()
	{
		for (int i = 0; i < TimeAttackManager.Instance.GetCurrentRunLevels().Length; i++)
		{
			TimeAttackResultsOption newOption = resultOptionScene.Instantiate() as TimeAttackResultsOption;
			newOption.SetLevelLabel(Tr(TimeAttackManager.Instance.GetCurrentRunLevels()[i].MissionTypeKey));
			newOption.SetWorldLabel(Tr(TimeAttackManager.Instance.GetCurrentRunLevels()[i].AreaKey.ToString()));
			newOption.SetTimeLabel(ExtensionMethods.FormatTime(TimeAttackManager.Instance.GetCurrentRunTimes()[i]));
			options.AddChild(newOption);
		}

		foreach (Node node in options.GetChildren())
		{
			if (node is TimeAttackResultsOption resultOption)
				resultsOption.Add(resultOption);
		}

		initialCursorPosition = cursor.Position.Y;
		totalTimeLabel.Text = ExtensionMethods.FormatTime(TimeAttackManager.Instance.GetTotalRunTime());
		TimeAttackManager.Instance.ClearCurrentRun();
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

		VerticalSelection = 0;
		RecalculateListPosition();
		UpdateListPosition(0);

		animator.Play("show");

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
		resultsOption.Clear();

		TimeAttackManager.Instance.LoadTimeAttack();
	}

	protected override void UpdateSelection()
	{
		if (Mathf.IsZeroApprox(Input.GetAxis("ui_up", "ui_down"))) return;

		VerticalSelection = WrapSelection(VerticalSelection + Mathf.Sign(Input.GetAxis("ui_up", "ui_down")), resultsOption.Count);

		animator.Play("select");
		animator.Seek(0, true);

		StartSelectionTimer();
		RecalculateListPosition();
	}

	private void RecalculateListPosition()
	{
		cursorPosition = VerticalSelection;
		if (resultsOption.Count > 5)
		{
			if (VerticalSelection < 3)
			{
				scrollRatio = 0;
				scrollAmount = 0;
			}
			else if (VerticalSelection >= resultsOption.Count - 3)
			{
				scrollRatio = 1;
				scrollAmount = resultsOption.Count - 5;
				cursorPosition = 4 - (resultsOption.Count - 1 - VerticalSelection);
			}
			else
			{
				scrollAmount = VerticalSelection - 2;
				scrollRatio = (VerticalSelection - 2) / (resultsOption.Count - 5.0f);
				cursorPosition = 2;
			}
		}
	}

	private void UpdateListPosition(float smoothing)
	{
		float targetScrollPosition = 360 * (VerticalSelection / (resultsOption.Count - 1f));
		scrollbar.Position = scrollbar.Position.SmoothDamp(Vector2.Right * targetScrollPosition, ref scrollVelocity, smoothing);

		cursor.Position = cursor.Position.SmoothDamp(new(cursor.Position.X, initialCursorPosition + (72 * cursorPosition)), ref cursorWidthVelocity, smoothing);
		options.Position = options.Position.SmoothDamp(Vector2.Up * (72 * scrollAmount), ref optionVelocity, smoothing);
	}

	public void ShowAllOptions()
	{
		for (int i = 0; i < resultsOption.Count; i++)
		{
			resultsOption[i].ShowOption();
		}
	}
}

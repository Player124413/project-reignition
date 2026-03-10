using Godot;
using Project.Interface.Menus;
using Project.Core;

namespace Project.Party;

/// <summary> Handles the online or offline selection process. </summary>
public partial class OnlineMenu : Menu
{
	private bool isOnlineMenuOpen;
	private int onlineModeSelection;
	[Export] private LinkedLabel selectionLabel;
	[Export] private LinkedLabel transitionLabel;
	[Export] private Control[] connectionNodes;
	[Export] private Control cursor;

	private readonly string[] selectionValues =
	[
		"party_offline",
		"party_host",
		"party_join",
	];

	public override void _PhysicsProcess(double delta)
	{
		base._PhysicsProcess(delta);
		cursor.GlobalPosition = connectionNodes[VerticalSelection + HorizontalSelection].GlobalPosition;
	}

	protected override void UpdateSelection()
	{
		if (isOnlineMenuOpen)
		{
			if (UpdateOnlineSelection())
				StartSelectionTimer();
			return;
		}

		int sign = Mathf.Sign(Input.GetAxis("ui_left", "ui_right"));
		if (sign == 0)
			return;

		StartSelectionTimer();
		onlineModeSelection = WrapSelection(onlineModeSelection + sign, 3);
		transitionLabel.SetText(selectionLabel.Text);
		selectionLabel.SetText(selectionValues[onlineModeSelection]);
		animator.Play(sign < 0 ? "select-left" : "select-right");
		animator.Seek(0.0);
	}

	private bool UpdateOnlineSelection()
	{
		Vector2I previousSelection = new(HorizontalSelection, VerticalSelection);

		int verticalSign = Mathf.Sign(Input.GetAxis("ui_up", "ui_down"));
		VerticalSelection = Mathf.Clamp(VerticalSelection + verticalSign, 0, connectionNodes.Length - 2);

		if (VerticalSelection == connectionNodes.Length - 2)
		{
			int horizontalSign = Mathf.Sign(Input.GetAxis("ui_left", "ui_right"));
			HorizontalSelection = Mathf.Clamp(HorizontalSelection + horizontalSign, 0, 1);
		}
		else
			HorizontalSelection = 0;

		return previousSelection != new Vector2I(HorizontalSelection, VerticalSelection);
	}

	protected override void Confirm()
	{
		if (isOnlineMenuOpen)
		{
			return;
		}

		// Offline player count menu
		if (onlineModeSelection == 0)
		{
			OpenSubmenu();
			return;
		}

		// Open online menu
		animator.Play(onlineModeSelection == 1 ? "host" : "join");
		animator.Advance(0.0);
		animator.Play("show-connect-menu");
		isOnlineMenuOpen = true;
	}

	public override void OpenSubmenu()
	{
		HideMenu();
		_submenus[0].ShowMenu();
	}

	protected override void Cancel()
	{
		if (isOnlineMenuOpen)
		{
			isOnlineMenuOpen = false;
			animator.Play("hide-connect-menu");
			return;
		}

		FadeBgm(0.5f, false);
		TransitionManager.QueueSceneChange(TransitionManager.MenuScenePath);
		TransitionManager.StartTransition(new TransitionData()
		{
			color = Colors.Black,
			inSpeed = 0.5f,
			outSpeed = 0.5f,
			disableAutoTransition = false
		});
	}
}

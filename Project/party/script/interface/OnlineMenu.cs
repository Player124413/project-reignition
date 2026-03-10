using Godot;
using Project.Interface.Menus;
using Project.Core;

namespace Project.Party;

/// <summary> Handles the online or offline selection process. </summary>
public partial class OnlineMenu : Menu
{
	protected override void UpdateSelection()
	{
		int sign = Mathf.Sign(Input.GetAxis("ui_left", "ui_right"));
		HorizontalSelection = WrapSelection(HorizontalSelection + sign, 2);
		animator.Play(HorizontalSelection == 0 ? "offline" : "online");
		animator.Advance(0.0);
		animator.Play(sign < 0 ? "select-left" : "select-right");
	}

	protected override void Confirm()
	{
		if (HorizontalSelection == 1) // TODO Add support for online mode
			return;

		// TODO Open player count menu
		HideMenu();
		OpenSubmenu();
	}

	public override void OpenSubmenu()
	{
		_submenus[0].ShowMenu();
	}

	protected override void Cancel()
	{
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

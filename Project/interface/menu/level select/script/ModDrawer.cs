using Godot;
using Project.Core;

namespace Project.Interface.Menus;

public partial class ModDrawer : Menu
{
	[Export] CharacterModSelect charSelect;
	[Export] private AnimationPlayer drawerAnimator;
	[Export] private AnimationPlayer readyAnimator;

	/// <summary> Is the mod drawer currently open? </summary>
	public bool IsOpen { get; private set; }
	/// <summary> Are character mods enabled? </summary>
	private bool IsActive => SaveManager.Config.areCharaModsEnabled;

	protected override void ProcessMenu()
	{
		if (!IsActive)
			return;

		if (Input.IsActionJustPressed("button_attack"))
		{
			ToggleOpen();
			return;
		}

		base.ProcessMenu();
	}

	protected override void Cancel()
	{
		if (!IsOpen)
			return;

		drawerAnimator.Play("hide");
		readyAnimator.Play("enable-controls");
		IsOpen = false;

		base.Cancel();
	}

	private void ToggleOpen()
	{
		IsOpen = !IsOpen;

		if (IsOpen)
		{
			charSelect.Redraw();
			drawerAnimator.Play("show");
			readyAnimator.Play("disable-controls");
		}
		else
		{
			drawerAnimator.Play("hide");
			readyAnimator.Play("enable-controls");
		}
	}
}

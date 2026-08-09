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
	public bool CanOpen {get; private set;}
	/// <summary> Are character mods enabled? </summary>
	private bool IsActive => SaveManager.Config.areCharaModsEnabled;

	protected override void ProcessMenu()
	{

		if (!CanOpen)
			return;
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
		
		charSelect.StopAllScrolling();

		drawerAnimator.Play("hide");
		readyAnimator.Play("enable-controls");
		IsOpen = false;

		base.Cancel();
	}

	private void ToggleOpen()
	{
		IsOpen = !IsOpen;

		charSelect.StopAllScrolling();

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

	public void SetCanOpen(bool open) {CanOpen = open;}
}

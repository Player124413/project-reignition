using Godot;
using Project.Core;

namespace Project.Interface.Menus;


public partial class ModDrawer : Menu
{

	[Export] CharacterModSelect charSelect;
	[Export] private AnimationPlayer drawerAnimator;
	[Export] private AnimationPlayer readyAnimator;

	///<Summary> Is the mod drawer currently open</Summary>
	public bool IsOpen {get; private set;}
	/// <summary> Are character mods enabeled </summary>
	private bool IsActive => SaveManager.Config.areCharaModsEnabled;

	protected override void ProcessMenu()
	{
		if (!IsActive)
			return;
		if (Input.IsActionJustPressed("button_attack"))
		{
			if (!IsOpen)
			{
				charSelect.Redraw();
				drawerAnimator.Play("show");
				readyAnimator.Play("disable-controls");
				IsOpen = true;
			}
			else
			{
				drawerAnimator.Play("hide");
				readyAnimator.Play("enable-controls");
				IsOpen = false;
			}
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


}

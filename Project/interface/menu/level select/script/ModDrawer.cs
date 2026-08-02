using System.Linq;
using System.Reflection.Metadata.Ecma335;
using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;


public partial class ModDrawer : Menu
{

	[Export] CharacterModSelect charSelect;
	[Export] private AnimationPlayer drawerAnimator;
	[Export] private AnimationPlayer readyAnimator;

	private bool isOpen = false;
	private bool canOpen = false;


	protected override void SetUp()
	{
		base.SetUp();
	}

	protected override void ProcessMenu()
	{
		if (Input.IsActionJustPressed("button_attack") && canOpen)
		{
			if (!isOpen)
			{
				charSelect.Redraw();
				drawerAnimator.Play("show");
				readyAnimator.Play("disable-controls");
				isOpen = true;
			}
			else
			{
				drawerAnimator.Play("hide");
				readyAnimator.Play("enable-controls");
				isOpen = false;
			}
			return;
		}
		base.ProcessMenu();
	}

    protected override void Cancel()
    {
		if (isOpen)
		{
			drawerAnimator.Play("hide");
			readyAnimator.Play("enable-controls");
			isOpen = false;
		}
        base.Cancel();
    }

	public bool IsOpen() {return isOpen;}

	public void Disappear()
	{
		drawerAnimator.Play("disappear");
	}

	public void Appear()
	{
		drawerAnimator.Play("appear");
	}

	public void CanOpen(bool open) => canOpen = open;


}

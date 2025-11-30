using Godot;
using Godot.Collections;
using Project.Core;

namespace Project.Interface.Menus;


public partial class TimeAttackReady : Menu
{
	[Export]
	private ReadyMenu readyMenu;
	[Export]
	private SkillSelect skillMenu;

	public override void ShowMenu()
	{
		if (this.parentMenu != null)
		{
			readyMenu.parentMenu = this.parentMenu;
			readyMenu.SetBgmPlayer(this.bgm);
		}
		else
		{
			this.bgm.Play();
		}

		SetupReadyMenu(TimeAttackManager.Instance.CurrentLevel);
		readyMenu.ShowMenu();
	}

	public void SetupReadyMenu()
	{
		readyMenu.SetupReadyMenu(TimeAttackManager.Instance.GetCurrentRunLevels(TimeAttackManager.Instance.CurrentRunType)[0]);
	}

	public void SetupReadyMenu(int level)
	{
		readyMenu.SetupReadyMenu(TimeAttackManager.Instance.GetCurrentRunLevels(TimeAttackManager.Instance.CurrentRunType)[level]);
	}
}

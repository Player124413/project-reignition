using Godot;
using Project.Core;

namespace Project.Interface.Menus;


public partial class TimeAttackReady : Menu
{
	[Export] private ReadyMenu readyMenu;
	[Export] private SkillSelect skillMenu;

	public override void ShowMenu()
	{
		if (parentMenu != null)
		{
			readyMenu.parentMenu = parentMenu;
			readyMenu.SetBgmPlayer(bgm);
		}
		else
		{
			bgm.Play();
		}

		SetupReadyMenu();
		readyMenu.ShowMenu();
	}

	public void SetupReadyMenu()
	{
		if (TimeAttackManager.Instance.CurrentRunType != TimeAttackManager.RunType.SingleRun)
			readyMenu.SetupReadyMenu(TimeAttackManager.Instance.GetCurrentRunLevels(TimeAttackManager.Instance.CurrentRunType)[0]);
		else
			readyMenu.SetupReadyMenu(TimeAttackManager.Instance.Level_Single);
	}

	public void SetupReadyMenu(int level)
	{
		readyMenu.SetupReadyMenu(TimeAttackManager.Instance.GetCurrentRunLevels(TimeAttackManager.Instance.CurrentRunType)[level]);
	}
}

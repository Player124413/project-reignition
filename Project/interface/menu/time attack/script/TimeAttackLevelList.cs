using Godot;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class TimeAttackLevelList : Menu
{
	[Export]
	private LevelSelect levelSelect;
	[Export]
	private Control optionsContainer;
	[Export]
	private PackedScene levelOption;

	public override void ShowMenu()
	{
		SpawnLevelList();
		levelSelect.ShowMenu();

	}

	public override void OpenSubmenu()
	{
		_submenus[0].ShowMenu();
	}
	public void SpawnLevelList()
	{
		if (optionsContainer.GetChildren().Count != 0)
		{
			foreach (Node n in optionsContainer.GetChildren())
			{
				optionsContainer.RemoveChild(n);
				n.QueueFree();
			}
		}

		for (int i = 0; i < TimeAttackManager.Instance.GetCurrentRun().Length; i++)
		{
			LevelOption option = (LevelOption)levelOption.Instantiate();
			option.data = TimeAttackManager.Instance.GetCurrentRun()[i];
			option.EnableTAInfo();
			optionsContainer.AddChild(option);


		}

	}

}

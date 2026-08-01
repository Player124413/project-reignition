using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class ModOption : Control
{
	public SkillResource Skill { get; set; }
	[Export] private AnimationPlayer animator;
	[Export] private Label nameLabel;

	private SkillRing ActiveSkillRing => SaveManager.ActiveSkillRing;
	/// <summary>Maximum number of characters. Scroll text if there are more than this number</summary>
	private readonly int MaxChars = 10;

	public void Redraw()
	{
		if (Skill == null)
			return;

		// Redraw equip status
		if (SaveManager.ActiveSkillRing.IsSkillEquipped(Skill))
		{
			animator.Play("equipped");
		}
		else
		{
			animator.Play("unequipped");
		}

		animator.Advance(0);
	}

	public void SetName(string name)
	{
		nameLabel.Text = name;
	}
	public void Initialize()
	{

		RedrawStaticData();
		Redraw();
	}

	private void RedrawStaticData()
	{
		nameLabel.Text = Skill.NameKey;
	}

}

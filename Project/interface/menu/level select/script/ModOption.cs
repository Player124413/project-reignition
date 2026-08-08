using Godot;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class ModOption : Control
{
	public SkillResource Skill { get; set; }
	[Export] private AnimationPlayer animator;
	[Export] private Label nameLabel;

	/// <summary> Maximum number of characters. Scroll text if there are more than this number. </summary>
	private readonly int MaxChars = 10;

	public void Initialize()
	{
		RedrawStaticData();
		Redraw();
	}

	public void Redraw()
	{
		if (Skill == null)
			return;

		// Redraw equip status
		animator.Play(SaveManager.ActiveSkillRing.IsSkillEquipped(Skill) ? "equipped" : "unequipped");
		animator.Advance(0);
	}

	private void RedrawStaticData() => nameLabel.Text = Skill.NameKey;
}

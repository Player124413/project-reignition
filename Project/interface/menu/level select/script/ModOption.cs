using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class ModOption : Control
{
	public SkillResource Skill { get; set; }
	[Export]
	private AnimationPlayer animator;
	[Export]
	private Label nameLabel;

	private SkillRing ActiveSkillRing => SaveManager.ActiveSkillRing;
	/// <summary>Maximum number of characters. Scroll text if there are more than this number</summary>
	private readonly int MaxChars = 10;

}

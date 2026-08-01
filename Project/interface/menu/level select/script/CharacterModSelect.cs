using System.Linq;
using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class CharacterModSelect : Menu
{
	[Export] private ModOption defaultOption;
	[Export] private PackedScene skillOption;
	[Export] private VBoxContainer optionContainer;
	[Export] private Node2D cursor;
	[Export] private AnimationPlayer cursorAnimator;

	private ModOption SelectedSkill => skillOptionList[VerticalSelection];
	private bool isNothingSelected;

	private SkillListResource SkillList => Runtime.Instance.SkillList;
	private SkillRing ActiveSkillRing => SaveManager.ActiveSkillRing;

	private int cursorPosition;
	private Vector2 cursorVelocity;
	private const float CursorSmoothing = .1f;

	private int scrollAmount;
	private float scrollRatio;
	private Vector2 scrollVelocity;
	private Vector2 containerVelocity;
	private const float ScrollSmoothing = .1f;
	/// <summary> How much to scroll per skill. </summary>
	private readonly int ScrollInterval = 62;
	/// <summary> Number of skills on a single page. </summary>
	private readonly int PageSize = 12;
	private readonly Array<ModOption> skillOptionList = [];

	protected override void SetUp()
	{
		defaultOption.SetName(Tr("sys_default"));

		
		for (int i = 0; i < (int)SkillKey.Count; i++)
		{
			SkillKey key = (SkillKey)i;
			SkillResource skill = SkillList.GetSkill(key);

			if (skill.Key != SkillKey.Character) //Only instantiate mods in this list
				continue;

			if (skill == null)
			{
				skillOptionList.Add(null);
				continue;
			}

			for (int j = 0; j < skill.Augments.Count; j++)
			{
				ModOption newSkill = skillOption.Instantiate<ModOption>();
				newSkill.Skill = skill.Augments[j];
				newSkill.Initialize();

				skillOptionList.Add(newSkill);
				optionContainer.AddChild(newSkill);
			}

			
			//newSkill.MouseEntered += () => ReceiveMouseInput(newSkill, false);
			//newSkill.MouseExited += () => ReceiveMouseInput(null, false);

			

			// Create base augment skill option
			//ModOption baseAugment = skillOption.Instantiate<ModOption>();
			//baseAugment.Skill = newSkill.Skill;
			//baseAugment.MouseEntered += () => ReceiveMouseInput(baseAugment, true);
			//baseAugment.MouseExited += () => ReceiveMouseInput(null, true);
		}

		base.SetUp();
	}

}

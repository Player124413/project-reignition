using System.Linq;
using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;


public partial class ModDrawer : Menu
{

	[Export] private PackedScene skillOption;
	[Export] private VBoxContainer optionContainer;
	[Export] private Node2D cursor;
	[Export] private AnimationPlayer cursorAnimator;
	[Export] private AnimationPlayer drawerAnimator;
	private SkillOption SelectedSkill => skillOptionList[VerticalSelection];
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
	private readonly int PageSize = 8;
	private readonly Array<SkillOption> skillOptionList = [];

	private bool isOpen = false;


	protected override void SetUp()
	{
		base.SetUp();
	}

	protected override void ProcessMenu()
	{
		if (Input.IsActionJustPressed("button_attack"))
		{
			if (!isOpen)
			{
				drawerAnimator.Play("show");
				isOpen = true;
			}
			else
			{
				drawerAnimator.Play("hide");
				isOpen = false;
			}
			return;
		}
		base.ProcessMenu();
	}


}

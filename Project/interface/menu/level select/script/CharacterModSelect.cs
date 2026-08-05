using System.Linq;
using Godot;
using Godot.Collections;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class CharacterModSelect : Menu
{
	[Export] private ModDrawer modDrawer;
	[Export] private PackedScene skillOption;
	[Export] private VBoxContainer optionContainer;
	[Export] private Node2D cursor;
	[Export] private AnimationPlayer cursorAnimator;

	private ModOption SelectedSkill => skillOptionList[VerticalSelection];
	private bool isNothingSelected;

	private SkillListResource SkillList => Runtime.Instance.SkillList;
	private SkillRing ActiveSkillRing => SaveManager.ActiveSkillRing;

	private int skillCount;

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

			skillCount = skill.Augments.Count;

			for (int j = 0; j < skill.Augments.Count; j++)
			{
				ModOption newSkill = skillOption.Instantiate<ModOption>();
				newSkill.Skill = skill.Augments[j];
				newSkill.Initialize();

				skillOptionList.Add(newSkill);
				optionContainer.AddChild(newSkill);


/*
				for (int k = 0; k < 14; k++)
				{
					ModOption newSkill2 = skillOption.Instantiate<ModOption>();
					newSkill2.Skill = skill.Augments[j];
					newSkill2.Initialize();

					skillOptionList.Add(newSkill2);
					optionContainer.AddChild(newSkill2);

					skillCount += 1;
				}
*/
			}

			

		}

		base.SetUp();
	}

	public override void _Process(double _)
	{
		float targetScrollPosition = 360 * scrollRatio;
		// Update cursor position
		float targetCursorPosition = cursorPosition * ScrollInterval;
		cursor.Position = cursor.Position.SmoothDamp(Vector2.Down * targetCursorPosition, ref cursorVelocity, CursorSmoothing);

		Vector2 targetContainerPosition = new(optionContainer.Position.X, -scrollAmount * ScrollInterval);
		optionContainer.Position = optionContainer.Position.SmoothDamp(targetContainerPosition, ref containerVelocity, ScrollSmoothing);
	}

	protected override void ProcessMenu()
	{

		base.ProcessMenu();
	}

	protected override void UpdateSelection()
	{
		int inputSign = Mathf.Sign(Input.GetAxis("ui_up", "ui_down"));
		if (inputSign == 0)
			return;

		if (isNothingSelected)
		{
			cursorAnimator.Play("show");
			isNothingSelected = false;
			return;
		}

		int changeAmount = inputSign;
		VerticalSelection = WrapSelection(VerticalSelection + inputSign, skillCount);

		UpdateScrollAmount(changeAmount);
		MoveCursor();
	}

	private void UpdateScrollAmount(int amount)
	{
		int listSize = skillCount;

		if (listSize <= PageSize)
		{
			// Disable scrolling
			scrollAmount = 0;
			scrollRatio = 0;
			cursorPosition = VerticalSelection;
		}
		else
		{
			// Update scroll
			int selection = VerticalSelection;

			if (selection == 0 || selection == listSize - 1)
				cursorPosition = scrollAmount = selection;
			else if (amount != 0)
			{
				if ((amount < 0 && cursorPosition == 1) || (amount > 0 && cursorPosition == PageSize - 2))
					scrollAmount += Mathf.Sign(amount);
				else
					cursorPosition += Mathf.Sign(amount);

				amount -= Mathf.Sign(amount);
				UpdateScrollAmount(amount);
			}

			scrollAmount = Mathf.Clamp(scrollAmount, 0, listSize - PageSize);
			scrollRatio = (float)selection / (listSize - 1);
			cursorPosition = Mathf.Clamp(cursorPosition, 0, PageSize - 1);
		}
	}

	private void SnapCursor()
	{
		cursorVelocity = Vector2.Zero;
		cursor.Position = Vector2.Up * -cursorPosition * ScrollInterval;
		ShowCursor();
	}

	private void MoveCursor()
	{
		animator.Play("select");
		animator.Seek(0, true);
		StartSelectionTimer();
	}

	public void ShowCursor()
	{
		if (isNothingSelected)
			return;

		cursorAnimator.Play("show");
		cursorAnimator.Queue("loop");
	}

	protected override void Confirm()
	{
		if (!modDrawer.IsOpen())
			return;

		if (isNothingSelected)
			return;

		if (!ToggleSkill())
			return;

		Redraw();
	}

	public void Redraw()
	{
		
		for (int i = 0; i < skillCount; i++)
		{
			skillOptionList[i].Redraw();
		}


	}

	private bool ToggleSkill()
	{
		SkillKey key = SelectedSkill.Skill.Key;

		int augmentIndex = VerticalSelection;
		if (key == SkillKey.Character)
			augmentIndex++;

		if (ActiveSkillRing.IsSkillEquipped(key))
		{
			SkillKey unequippedKey = ActiveSkillRing.UnequipSkill(key, augmentIndex);
			if (unequippedKey == key)
			{
				animator.Play("unequip");
				return true;
			}
		}

		SkillEquipStatusEnum status = ActiveSkillRing.EquipSkill(key, augmentIndex);
		if (status == SkillEquipStatusEnum.Success)
		{
			animator.Play("equip");
			return true;
		}

		return false; // Something failed
	}

	private void ScrollSelection(int targetSelection)
	{
		//int initialSelection = VerticalSelection + AugmentSelection;
		int initialSelection = VerticalSelection;
		scrollAmount += targetSelection - initialSelection;
		VerticalSelection = targetSelection;
		UpdateScrollAmount(0);

		// Reupdate cursor since clamping is applied in UpdateScrollAmount()
		cursorPosition = VerticalSelection - scrollAmount;

		if (VerticalSelection != 0 && VerticalSelection != skillCount - 1)
		{
			// Ensure cursor doesn't get stuck on the edges of the list
			if (cursorPosition == 0) // Top of the list
			{
				cursorPosition++;
				scrollAmount--;
			}
			else if (cursorPosition == PageSize - 1)
			{
				cursorPosition--;
				scrollAmount++;
			}
		}

		if (VerticalSelection != initialSelection)
			MoveCursor();
	}

}

using Godot;
using System;

namespace Project.Interface.Menus;
public partial class JukeboxOption : Control
{

	///<summary> Reference to the target BGM Resource</summary>
	[Export] public BGMResource bgm;

	[Export] private Label name;
	[Export] private AnimationPlayer animator;

	public bool Equipped { get; private set; }


	public void SetData()
	{
		name.Text = bgm.SongName;
	}

	public void Equip()
	{
		animator.Play("equip");
		Equipped = true;
	}

	public void Unequip()
	{
		animator.Play("unequip");
		Equipped = false;
	}
}

using Godot;
using Project.Core;
using Project.Gameplay;

namespace Project.Interface.Menus;

public partial class ModOption : Control
{
	public SkillResource Skill { get; set; }
	[Export] private AnimationPlayer animator;
	[Export] private Label nameLabel;
	[Export] private Control labelControl;
	const int maxChars = 14;

	private float scrollDuration = 3;
	private float scrollDelay = 2;
	Tween tween;

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
		nameLabel.OffsetLeft = 0;
	}

	public void StartScrolling()
	{
		if (nameLabel.GetTotalCharacterCount() <= maxChars)
			return;

		float final_offset = -(nameLabel.GetCombinedMinimumSize().X - labelControl.Size.X);
		tween = CreateTween().SetLoops();
		tween.TweenProperty(nameLabel, "offset_left", 0, scrollDelay).From(0);
		tween.TweenProperty(nameLabel, "offset_left", final_offset, scrollDuration).From(0);
		tween.TweenProperty(nameLabel, "offset_left", final_offset, scrollDelay).From(final_offset);
	}

	public void StopScrolling()
	{
		nameLabel.OffsetLeft = 0;

		if (tween == null)
			return;
		tween.Stop();
		tween.Kill();
	}

	private void RedrawStaticData() => nameLabel.Text = Skill.NameKey;
}

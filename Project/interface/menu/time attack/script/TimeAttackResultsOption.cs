using Godot;

namespace Project.Interface.Menus;

public partial class TimeAttackResultsOption : Menu
{
	[Export] private Label worldLabel;
	[Export] private Label levelLabel;
	[Export] private Label timeLabel;

	public void SetWorldLabel(string text) => worldLabel.Text = Tr(text);
	public void SetLevelLabel(string text) => levelLabel.Text = Tr(text);
	public void SetTimeLabel(float time) => timeLabel.Text = ExtensionMethods.FormatTime(time);
	public void ShowOption() => animator.Play("show");
}

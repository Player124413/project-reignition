using Godot;
using System;

namespace Project.Interface.Menus;

public partial class TimeAttackResultsOption : Menu
{
	[Export] private Label worldLabel;
	[Export] private Label levelLabel;
	[Export] private Label timeLabel;

	public void SetWorldLabel(string text) => worldLabel.Text = text;
	public void SetLevelLabel(string text) => levelLabel.Text = text;
	public void SetTimeLabel(string text) => timeLabel.Text = text;
	public void ShowOption() => animator.Play("show");
}

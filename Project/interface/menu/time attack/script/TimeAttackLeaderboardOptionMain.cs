using Godot;

namespace Project.Interface.Menus;

public partial class TimeAttackLeaderboardOptionMain : Menu
{
	[Export] private Label placement;
	[Export] private Label time;

	public void SetPlacement(int place) => placement.Text = place.ToString() + ".";
	public void SetTime(float thisTime) => time.Text = ExtensionMethods.FormatTime(thisTime);

	public void TimeVisible(bool isVisible) => time.Visible = isVisible;
}

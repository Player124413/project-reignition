using Godot;
using Godot.Collections;

namespace Project.Party;

/// <summary> Syncs the text of a label and its child labels (used for special label text styling). </summary>
[Tool]
public partial class LinkedLabel : Label
{
	private readonly Array<Label> childLabels = [];

	[ExportToolButton("Update Label Values")]
	public Callable RefreshLabelGroup => Callable.From(RefreshEditorLabels);
	private void RefreshEditorLabels()
	{
		childLabels.Clear();
		AddChildLabels(this);
		SetText(Text);
	}

	public override void _EnterTree()
	{
		if (Engine.IsEditorHint())
			return;

		childLabels.Clear();
		AddChildLabels(this);
	}

	/// <summary> Recursively set the child's labels. </summary>
	private void AddChildLabels(Node parent)
	{
		foreach (Node child in parent.GetChildren())
		{
			if (child is Label)
				childLabels.Add(child as Label);

			AddChildLabels(child);
		}
	}

	/// <summary> Sets the label's text and all of its children. </summary>
	public new void SetText(string text)
	{
		Text = text;
		foreach (Label child in childLabels)
		{
			child.Text = text;
			child.HorizontalAlignment = HorizontalAlignment;
			child.VerticalAlignment = VerticalAlignment;
		}
	}
}

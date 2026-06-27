using Godot;

[GlobalClass]
/// <summary> Represents a localization. </summary>
public partial class LocalizationResource : Resource
{
	[Export(PropertyHint.LocaleId)] public string LocaleId { get; private set; } = "en";
	[Export] public LocalizationType LocaleType { get; private set; }

	/// <summary> Tracks wether this localization was modded in or not. </summary>
	public bool IsMod { get; set; }
	public enum LocalizationType
	{
		Text,
		Voice
	}
}

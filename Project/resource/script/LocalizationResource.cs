using Godot;

[GlobalClass]
/// <summary> Represents a localization. </summary>
public partial class LocalizationResource : Resource
{
	[Export(PropertyHint.LocaleId)] public string LocaleId { get; private set; } = "en";
	[Export] public LocalizationType LocaleType { get; private set; }
	public enum LocalizationType
	{
		Text,
		Voice
	}
}

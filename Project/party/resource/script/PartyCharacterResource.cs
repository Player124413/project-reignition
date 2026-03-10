using Godot;

namespace Project.Party;

/// <summary> Represents a character in the party mode. </summary>
[GlobalClass]
public partial class PartyCharacterResource : Resource
{
	/// <summary> Localization key for the player's character name. </summary>
	[Export] public string characterName;
	/// <summary> Stores a reference to the player's character model scene. </summary>
	[Export(PropertyHint.File)] private string modelScene;
}

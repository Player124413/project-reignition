using Godot;

namespace Project.Party;

/// <summary> Responsible for tracking party game state.  </summary>
public partial class PartyManager : Node
{
	public static PartyManager Instance { get; private set; }

	/// <summary> Tracks the current mode being played. </summary>
	public PartyModeEnum CurrentPartyMode { get; set; }
	public enum PartyModeEnum
	{
		WorldBazaar,
		TournamentPalace,
		GenieLair,
		WorldLibrary,
		TreasureHunt,
		PirateCoast,
		Count
	}

	/// <summary> Tracks the character data. </summary>
	private PlayerData[] playerData;
	/// <summary> Gets the data of a particular player. </summary>
	public PlayerData GetPlayerData(int index) => playerData[index];
	/// <summary> Number of players in party mode. </summary>
	private readonly int PlayerCount = 4;

	public override void _EnterTree()
	{
		Instance = this;

		playerData = new PlayerData[PlayerCount];
		for (int i = 0; i < playerData.Length; i++)
			playerData[i] = new PlayerData(); // Initialize player data
	}

	public class PlayerData
	{
		/// <summary> Tracks whether a player is being controlled by the CPU. </summary>
		public bool IsCpuControlled { get; set; }
		/// <summary> Tracks the character a player is playing. </summary>
		public PartyCharacterResource CharacterData { get; set; }
		/// <summary> Tracks which "slot" the player occupies [0, 3]. </summary>
		public int PlayerIndex { get; set; }
		/// <summary> Tracks the placement in the previous mini-game [0, 3]. Same numbers means a tie occurred. </summary>
		public int MinigamePlacement { get; set; }
	}
}

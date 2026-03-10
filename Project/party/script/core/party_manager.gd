### Responsible for tracking the current general state of party mode.
### General state includes game mode, character selections, and cpu settings.
extends Node

## An enum of all the attactions in the party mode.
enum CURRENT_MODE_ENUM {
	WORLD_BAZAAR,
	TOURNAMENT_PALACE,
	GENIE_LAIR,
	WORLD_LIBRARY,
	TREASURE_HUNT,
	PIRATE_COAST,
	COUNT
}
## Represents the current game mode being played.
var current_mode : CURRENT_MODE_ENUM

## An array containing all the currently active players.
var _player_data : Array[PlayerData]
## Maximum number of players in the party mode.
const MAX_PLAYER_COUNT : int = 4;
## Returns the player data of a specific player.
func get_player_data(index : int) -> PlayerData:
	return _player_data.get(index)

func _enter_tree() -> void:
	# Initialize player data
	for i in MAX_PLAYER_COUNT:
		var new_player : PlayerData = PlayerData.new()
		new_player.player_index = i
		_player_data.append(new_player)

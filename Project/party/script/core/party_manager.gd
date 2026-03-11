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

## Resets player data to the default offline settings.
func initialize_offline_player_data() -> void:
	# Initialize player data
	_player_data.clear()
	for i in MAX_PLAYER_COUNT:
		var new_player : PlayerData = PlayerData.new()
		new_player.player_index = i
		_player_data.append(new_player)

@rpc("authority", "call_local", "reliable")
func initialize_online_player_data() -> void:
	print("Adding online players to " + str(multiplayer.get_unique_id()))
	for i in multiplayer.get_peers():
		print("CLIENT " + str(multiplayer.get_unique_id()) + ": " + str(i))

## "Removes" the player at an index by shifting all players left and placing the old data at the end.
func remove_player_at(index : int) -> void:
	var old_player : PlayerData = _player_data[index]
	_player_data.remove_at(index)
	_player_data.push_back(old_player)

## "Inserts" a player at an index by shifting all players left and placing the old data at the end.
func insert_player_at(index : int) -> void:
	var old_player : PlayerData = _player_data.pop_back()
	_player_data.insert(index, old_player)

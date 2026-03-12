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

signal players_initialized

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
		_player_data.append(PlayerData.new())
		set_player_indexes(i, i, 1, 0)

func initialize_online_player_data() -> void:
	print("Adding online players to " + str(multiplayer.get_unique_id()))
	var peers : PackedInt32Array = multiplayer.get_peers()
	peers.insert(0, 1) # Add the host to the list of peers
	for i in MAX_PLAYER_COUNT:
		if i < peers.size():
			rpc("set_player_indexes", i, i, peers[i], 0)
		else:
			rpc("set_player_indexes", i, i - peers.size(), 0, 0)
	rpc("finish_initializing_players")

@rpc("authority", "call_local", "reliable")
func set_player_indexes(index : int, player_index : int, device : int, local_player_index : int) -> void:
	_player_data[index].player_index = player_index
	_player_data[index].local_player_index = local_player_index
	_player_data[index].device = device
	_player_data[index].update_player_tag()

@rpc("authority", "call_local", "reliable")
func finish_initializing_players() -> void:
	players_initialized.emit()

## Returns the number of players attached to a particular device.
func get_player_count_device(device_id : int) -> int:
	var count : int = 0
	for i in _player_data:
		if i.device == device_id:
			count += 1
	return count

## Returns the first index of a particular device's players.
func get_first_player_index_device(device_id : int) -> int:
	var i : int = 0
	while i < MAX_PLAYER_COUNT:
		if get_player_data(i).device == device_id:
			return i
		i += 1
	return -1

## Returns the last index of a particular device's players.
func get_last_player_index_device(device_id : int) -> int:
	var i : int = MAX_PLAYER_COUNT - 1
	while i >= 0:
		if get_player_data(i).device == device_id:
			return i
		i -= 1
	return -1

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
var current_mode : CURRENT_MODE_ENUM = CURRENT_MODE_ENUM.COUNT

signal players_initialized

## An array containing all possible character datas.
var _character_data : Array[PartyCharacterResource]
const CHARACTER_DATA_FOLDER = "res://party/resource/character/"

func _init() -> void:
	load_characters()
	## TODO Load modded character data here

func load_characters() -> void:
	# Load character data from resource files
	var char_files : PackedStringArray = ResourceLoader.list_directory(CHARACTER_DATA_FOLDER)
	for char_file in char_files:
		if !char_file.ends_with(".tres"):
			# Only load .tres files
			continue
		var character = ResourceLoader.load(CHARACTER_DATA_FOLDER + char_file)
		if character is not PartyCharacterResource:
			continue
		# Insert the character into the character list at the correct index
		if _character_data.size() <= character.character_select_index:
			_character_data.resize(character.character_select_index + 1)
		if _character_data[character.character_select_index] == null:
			_character_data[character.character_select_index] = character
		else:
			_character_data.insert(character.character_select_index, character)
			printerr("DUPLICATE CHARACTER INDEX FOUND")
		print("Loaded party character %s from %s into index %s" % [character.character_name, CHARACTER_DATA_FOLDER + char_file, character.character_select_index])
	# Trim any extra entries
	for i in range(_character_data.size(), 0):
		if _character_data[i] == null:
			_character_data.remove_at(i)

## Identifies a character data's index based on its name.
func find_character_index_by_name(character_name : String) -> int:
	for i in _character_data.size():
		if _character_data[i].character_name == character_name:
			return i
	return -1

## Set's a player's character data to a given name.
@rpc("authority", "call_local", "reliable")
func set_character_data(index : int, character_name : String) -> void:
	if character_name.is_empty():
		# Set character data to null
		_player_data[index].character_data = null
		print("set character data to null at port " + str(index))
		return
	
	var character_index : int = find_character_index_by_name(character_name)
	if character_index == -1:
		printerr("Couldn't find character " + character_name + " on client " + str(multiplayer.get_unique_id()))
		return
	
	_player_data[index].character_data = _character_data[character_index]
	print("set character data to %s at port %s" % [_character_data[character_index].character_name, index])

## Returns whether a character is available for selection.
func is_character_available(character_data : PartyCharacterResource) -> bool:
	for player_data in _player_data:
		if player_data.character_data == character_data:
			return false
	return true

## An array containing all the currently active players.
var _player_data : Array[PlayerData]
## Maximum number of players in the party mode.
const MAX_PLAYER_COUNT : int = 4;
## Returns the player data of a specific player.
func get_player_data(index : int) -> PlayerData:
	return _player_data.get(index)

func is_player_data_initialized() -> bool:
	return _player_data.size() != 0

## Resets player data to the default offline settings.
func initialize_offline_player_data() -> void:
	# Initialize player data
	_player_data.clear()
	for i in MAX_PLAYER_COUNT:
		_player_data.append(PlayerData.new())
		set_player_indexes(i, i, 1, i + 1)

func initialize_online_player_data() -> void:
	print("Adding online players to " + str(multiplayer.get_unique_id()))
	var peers : PackedInt32Array = multiplayer.get_peers()
	peers.insert(0, 1) # Add the host to the list of peers
	for i in MAX_PLAYER_COUNT:
		if i < peers.size():
			# Add peer player
			rpc("set_player_indexes", i, i, peers[i], 1)
		else:
			# Add CPU player
			rpc("set_player_indexes", i, i - peers.size(), 0, 1)
	rpc("finish_initializing_players")

@rpc("authority", "call_local", "reliable")
func set_player_indexes(index : int, player_index : int, device : int, local_player_index : int) -> void:
	_player_data[index].player_index = player_index
	_player_data[index].local_player_index = local_player_index
	_player_data[index].device = device
	_player_data[index].update_player_tag()

@rpc("authority", "call_local", "reliable")
func set_difficulty(index : int, difficulty : int) -> void:
	_player_data[index].cpu_difficulty = difficulty as PlayerData.CPU_DIFFICULTY_ENUM

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

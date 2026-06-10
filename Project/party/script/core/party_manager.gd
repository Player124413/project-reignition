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
@rpc("any_peer", "call_local", "reliable")
func set_current_mode(mode : CURRENT_MODE_ENUM) -> void:
	current_mode = mode

## The minigame resource currently queued to play.
var queued_minigame : MinigameResource
signal players_initialized

## An array containing all possible character datas.
var character_data : Array[PartyCharacterResource]
## The complete list of loaded minigames.
var minigame_list : Array[MinigameResource]
## The list of unlocked minigames, based on save data. Use this for attractions.
var unlocked_minigame_list : Array[MinigameResource]

## Tracks who's playing the minigame. Used for tournament palace.
var minigame_players : PackedInt32Array = DEFAULT_MINIGAME_PLAYERS
const DEFAULT_MINIGAME_PLAYERS : PackedInt32Array = [0, 1, 2, 3]

func get_character_count() -> int:
	return character_data.size()

const CHARACTER_DATA_FOLDER = "res://party/resource/character/"
## Path to all standard minigame resources.
const MINIGAME_DATA_PATH : String = "res://party/resource/minigame/"

func _init() -> void:
	load_characters()
	load_minigames()
	## TODO Load modded character and minigame data here

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
		if character_data.size() <= character.character_select_index:
			character_data.resize(character.character_select_index + 1)
		if character_data[character.character_select_index] == null:
			character_data[character.character_select_index] = character
		else:
			character_data.insert(character.character_select_index, character)
			printerr("DUPLICATE CHARACTER INDEX FOUND")
		print("Loaded party character %s from %s into index %s" % [character.character_name, CHARACTER_DATA_FOLDER + char_file, character.character_select_index])
	# Trim any extra entries
	for i in range(character_data.size(), 0):
		if character_data[i] == null:
			character_data.remove_at(i)

func load_minigames() -> void:
	var dirAccess : DirAccess = DirAccess.open(MINIGAME_DATA_PATH)
	for file in dirAccess.get_files():
		if file.ends_with(".remap"):
			file = file.replace(".remap", "")
		var resource : Resource = ResourceLoader.load(MINIGAME_DATA_PATH + file)
		if resource is MinigameResource:
			minigame_list.append(resource)
	# TODO Determine this from save data.
	unlocked_minigame_list = minigame_list.duplicate()

## Identifies a character data's index based on its name.
func find_character_index_by_name(character_name : String) -> int:
	for i in character_data.size():
		if character_data[i].character_name == character_name:
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
	
	_player_data[index].character_data = character_data[character_index]
	print("set character data to %s at port %s" % [character_data[character_index].character_name, index])

## Gets the player_index of a particular character. Returns -1 if not selected.
func get_character_index(data : PartyCharacterResource) -> int:
	var index : int = 0;
	for player_data in _player_data:
		if player_data.character_data == data:
			return index
		index += 1
	return -1

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
		# Set every except P1 to a cpu
		_player_data.append(PlayerData.new())
		set_player_indexes(i, i, 0 if i != 0 else 1, i + 1)

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

## Called when running a mini-game from the editor. Loads 4 default characters.
func initialize_debug_characters() -> void:
	print("Initializing default characters for debug mode.")
	for i in PartyManager.MAX_PLAYER_COUNT:
		# Simply add characters based on their index order
		var data : PartyCharacterResource = PartyManager.character_data.get(i)
		PartyManager.set_character_data(i, data.character_name)
		PartyManager.set_player_indexes(i, i, 1 if i == 0 else 0, 1) # Set everyone to a cpu except for p1
		if i > 0:
			PartyManager.set_difficulty(i, i) # Set this to i - 1 if you need to test easy cpus

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

func set_minigame_players(players : PackedInt32Array) -> void:
	minigame_players = players

@rpc("authority", "call_local", "reliable")
func set_minigame_placement(index : int, placement : int) -> void:
	_player_data[index].minigame_placement = placement

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

## Manages the race ui in the canoe race minigame.
extends Node

@export var players : Array[Node3D]
var _player_laps : PackedInt32Array
var _player_signs : PackedInt32Array

var lap_length : float
const MAX_LAP_COUNT : int = 2

func _ready() -> void:
	lap_length = players[0].path.curve.get_baked_length()
	for i in range(players.size() - 1, 0, -1):
		if !PartyManager.minigame_players.has(players[i].player_index):
			players.remove_at(i)
	
	_player_laps.resize(PartyManager.minigame_players.size())
	_player_signs.resize(PartyManager.minigame_players.size())
	for i in _player_signs.size():
		players[i].sync_path_follower()
		_player_signs[i] = calculate_sign(players[i])

func _physics_process(_delta: float) -> void:
	for i in players.size():
		var player : Node3D = players[i]
		if player.is_multiplayer_authority():
			process_sign(i)
		player.race_tracker.set_progress_raw(get_progress(player))

func process_sign(player_index : int) -> void:
	var player : Node3D = players[player_index]
	var curr_sign : int = calculate_sign(player)
	if curr_sign == _player_signs[player_index]:
		return
	if player.path_follower.progress_ratio < 0.1 || player.path_follower.progress_ratio > 0.9:
		if curr_sign == -1:
			rpc("increment_lap", player_index, NetworkTimeSynchronizer.get_time())
		else:
			rpc("decrement_lap", player_index)
	_player_signs[player_index] = curr_sign

func calculate_sign(player : Node3D) -> int:
	if player.path_follower.progress_ratio > 0.5:
		return 1
	else:
		return -1

func get_progress(player : Node3D) -> float:
	var player_index : int = player.player_index
	var progress : float = lap_length * player.race_tracker.player_laps[player_index]
	if player.race_tracker.player_laps[player_index] < 0:
		progress -= (lap_length - player.path_follower.progress)
	else:
		progress += player.path_follower.progress
	return progress

@rpc("any_peer", "call_local", "reliable")
func increment_lap(player_index : int, tick : float) -> void:
	_player_laps[player_index] += 1
	get_player(player_index).race_tracker.set_progress_lap(_player_laps[player_index], MAX_LAP_COUNT)
	if _player_laps[player_index] == MAX_LAP_COUNT + 1:
		MinigameManager.instance.request_time_change(player_index, tick)
		MinigameManager.instance.request_minigame_finish()

@rpc("any_peer", "call_local", "reliable")
func decrement_lap(player_index : int) -> void:
	_player_laps[player_index] -= 1
	get_player(player_index).race_tracker.set_progress_lap(_player_laps[player_index], MAX_LAP_COUNT)

func get_player(player_index : int) -> Node3D:
	for player in players:
		if player.player_index == player_index:
			return player
	return null

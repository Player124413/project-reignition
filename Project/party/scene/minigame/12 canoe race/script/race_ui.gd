## Manages the race ui in the canoe race minigame.
extends Node

@export var players : Array[Node3D]
var _player_laps : PackedInt32Array
var _player_checkpoints : PackedInt32Array
const LAP_COUNT : int = 2

func _ready() -> void:
	_player_laps.resize(PartyManager.minigame_players.size())
	_player_checkpoints.resize(PartyManager.minigame_players.size())

func on_checkpoint_entered(player : Area3D, checkpoint_index : int) -> void:
	var player_controller : Node3D = player.get_parent().get_parent()
	var player_index : int = player_controller.player_index
	if !player_controller.is_multiplayer_authority():
		return
	
	if checkpoint_index == 0:
		if _player_checkpoints[player_index] == 2: # Finished a lap
			rpc("increment_lap", player_index, NetworkTimeSynchronizer.get_time())
	_player_checkpoints[player_index] = checkpoint_index
	print("player checkpoint %s set to %s" % [player_index, checkpoint_index])

@rpc("any_peer", "call_local", "reliable")
func increment_lap(player_index : int, tick : float) -> void:
	_player_laps[player_index] += 1
	if _player_laps[player_index] == LAP_COUNT:
		print("incremented lap for player %s" % player_index)
		MinigameManager.instance.request_time_change(player_index, tick)
		MinigameManager.instance.request_minigame_finish()

extends Attraction

## Positions of players when choosing the rules.
@export var rule_positions : Array[Node3D]
@export var balcony_parents : Array[Node]
var balcony_data : Array[BalconyData]

func initialize_attraction() -> void:
	# TODO Store balcony data
	pass

func on_game_started() -> void:
	for i in _players.size():
		_players[i].request_movement(rule_positions[i].global_position, false)

class BalconyData:
	var balcony : Node3D
	var door : Node3D
	var player_position : Node3D

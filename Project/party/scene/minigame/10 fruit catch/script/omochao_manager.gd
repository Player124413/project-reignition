## Manages the omochaos and fruit throws in the fruit catch minigame.
extends Node

@export var omochaos : Array[CharacterAnimator]
@export var fruits : Array[Node3D]
@export var player_origin : Node3D

const OFFSET_BOUNDS : float = 10.0

var is_demo : bool
var _fruit_index : int

func _ready() -> void:
	for i in omochaos.size():
		omochaos[i].play_animation("select")

## TODO Calculate a fruit position
func request_fruit_spawn() -> void:
	if _fruit_index >= fruits.size():
		return # Spawned all fruits
	
	var omochao_index : int = 0
	omochaos[omochao_index].play_minigame_animation("pull", 0.0, 1.0, NetworkTimeSynchronizer.get_time())
	if !is_demo:
		omochao_index = randi_range(0, omochaos.size() - 1)
	await get_tree().create_timer(0.3, false, true).timeout
	var offset : float = (1.0 - 2.0 * randf()) * OFFSET_BOUNDS
	var end_position : Vector3 = player_origin.global_position + Vector3.RIGHT * offset
	var throw_position : Vector3 = omochaos[omochao_index].global_position + Vector3.UP * 7
	throw_position += omochaos[omochao_index].global_basis.z * 10
	fruits[_fruit_index].rpc("spawn", throw_position, end_position, randf() > 0.5, NetworkTimeSynchronizer.get_time())
	_fruit_index += 1

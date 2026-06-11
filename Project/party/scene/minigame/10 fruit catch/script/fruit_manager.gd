## Manages the omochaos and fruit throws in the fruit catch minigame.
extends Node

signal fruit_spawned(fruit : Node3D)

@export var omochaos : Array[CharacterAnimator]
@export var fruits : Array[Node3D]
@export var player_origin : Node3D
var _camera : Camera3D

# List of all fruit that has been caught. When it becomes larger than 5, the first fruit is removed from the stick.
var _caught_fruits : Array[Node3D]

var _fruit_index : int
var _player_index : int
var _spawn_timer : float
var _is_gameplay_started : bool

const SPAWN_INTERVAL : float = 2.5
const MIN_SPAWN_INTERVAL : float = 1.0
const OFFSET_BOUNDS : float = 10.0
const MAX_COLLECTED_FRUIT_COUNT : int = 6

func _ready() -> void:
	for i in omochaos.size():
		omochaos[i].play_animation("select")
	_camera = get_viewport().get_camera_3d()
	MinigameManager.instance.gameplay_started.connect(Callable(self, "on_gameplay_started"))

func on_gameplay_started() -> void:
	_is_gameplay_started = true

func _physics_process(_delta : float) -> void:
	if !is_multiplayer_authority() || _player_index == -1:
		return
	
	if !_is_gameplay_started:
		return
	
	_spawn_timer -= get_physics_process_delta_time()
	if _spawn_timer <= 0:
		request_fruit_spawn()
		_spawn_timer = lerp(SPAWN_INTERVAL, MIN_SPAWN_INTERVAL, (_fruit_index as float) / fruits.size())

func set_player_index(index : int) -> void:
	_player_index = index

func request_fruit_spawn() -> void:
	if _fruit_index >= fruits.size():
		return # Spawned all fruits
	
	var omochao_index : int = 0
	if _player_index != -1:
		omochao_index = randi_range(0, omochaos.size() - 1)
	omochaos[omochao_index].play_minigame_animation("pull", 0.0, 1.0, NetworkTimeSynchronizer.get_time())
	omochaos[omochao_index].queue_minigame_animation("select", 0.2)
	var offset : float = 0
	if _player_index != -1:
		offset = (1.0 - 2.0 * randf()) * OFFSET_BOUNDS
	var end_position : Vector3 = player_origin.global_position + Vector3.RIGHT * offset
	var throw_position : Vector3 = omochaos[omochao_index].global_position + Vector3.UP * 7
	throw_position += omochaos[omochao_index].global_basis.z * 10
	fruits[_fruit_index].rpc("spawn", throw_position, end_position, randf() > 0.5, NetworkTimeSynchronizer.get_time())
	fruits[_fruit_index].collected.connect(Callable(self, "register_caught_fruit").bind(fruits[_fruit_index]))
	fruit_spawned.emit(fruits[_fruit_index])
	if _player_index == -1:
		fruits[_fruit_index].collection_finished.connect(Callable(self, "on_fruit_collection_finished"))
	_fruit_index += 1

func register_caught_fruit(node : Node3D) -> void:
	if is_multiplayer_authority():
		MinigameManager.instance.request_score_change(_player_index)
		MinigameManager.instance.request_score_popup(_player_index, 1, _camera.unproject_position(node.global_position))
	
	_caught_fruits.append(node)
	for i in _caught_fruits.size():
		_caught_fruits[i]._fruit_index = i

func on_fruit_collection_finished() -> void:
	MinigameManager.instance.request_minigame_start()

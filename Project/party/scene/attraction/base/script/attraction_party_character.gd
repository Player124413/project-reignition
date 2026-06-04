### Represents a character in a party attraction.
class_name AttractionPartyCharacter extends Node3D

## Emitted when the player has finished moving to a point.
signal movement_finished()

@export_range(0, 3) var player_index : int
@export var common_library : AnimationLibrary
@export var party_library : AnimationLibrary

var character_animator : CharacterAnimator
var _move_speed : float
var _end_rotation : float
var _end_position : Vector3
## Tracks whether this character is moving to _end_position.
var _is_travelling : bool
## Tracks whether this character is rotating or not.
var _is_rotating : bool

const ROTATION_SPEED : float = 5.0
const WALK_SPEED : float = 30.0
const RUN_SPEED : float = 50.0

const COMMON_LIBRARY_ANIMATION : String = "COMMON"
const PARTY_LIBRARY_ANIMATION : String = "PARTY"

func _ready() -> void:
	initialize_character_animator()
	_end_rotation = global_rotation.y
	Attraction.instance.register_player(self)

func initialize_character_animator() -> void:
	var scene : PackedScene = load(PartyManager.get_player_data(player_index).character_data.model_file) as PackedScene
	character_animator = scene.instantiate() as CharacterAnimator
	character_animator.load_animation_library(COMMON_LIBRARY_ANIMATION, common_library)
	character_animator.load_animation_library(PARTY_LIBRARY_ANIMATION, party_library)
	character_animator.play_animation("%s/wait" % COMMON_LIBRARY_ANIMATION)
	add_child(character_animator)

func _physics_process(_delta: float) -> void:
	process_rotation_tick()
	if _is_travelling:
		process_travel_tick()

func process_travel_tick() -> void:
	if _is_rotating:
		return
	
	global_position = global_position.move_toward(_end_position, _move_speed * get_physics_process_delta_time())
	if global_position.is_equal_approx(_end_position):
		_is_travelling = false
		character_animator.play_animation("%s/wait" % COMMON_LIBRARY_ANIMATION, true, 0.2)
		movement_finished.emit()

func process_rotation_tick() -> void:
	var target_rotation : float = _end_rotation
	var current_rotation : float = global_rotation.y
	if _is_travelling:
		var offset : Vector3 = _end_position - global_position
		target_rotation = offset.signed_angle_to(Vector3.MODEL_FRONT, Vector3.UP)
	
	_is_rotating = !is_zero_approx(angle_difference(target_rotation, current_rotation))
	if !_is_rotating:
		return
	
	current_rotation = rotate_toward(current_rotation, target_rotation, ROTATION_SPEED * get_physics_process_delta_time())
	global_rotation = Vector3.UP * current_rotation

func request_movement(to_pos : Vector3, is_running : bool, start_pos : Vector3 = Vector3.INF) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	if start_pos.is_equal_approx(Vector3.INF):
		start_pos = global_position
	
	rpc("start_movement", start_pos, to_pos, is_running, NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func start_movement(from_pos : Vector3, to_pos : Vector3, is_running : bool, tick : float) -> void:
	global_position = from_pos
	_end_position = to_pos
	_is_travelling = true
	if is_running:
		_move_speed = RUN_SPEED
		character_animator.play_animation("%s/run" % COMMON_LIBRARY_ANIMATION, true, 0.2)
	else:
		_move_speed = WALK_SPEED
		character_animator.play_animation("%s/walk" % COMMON_LIBRARY_ANIMATION, true, 0.2)
	for i in get_rollback_tick_count(tick):
		process_rotation_tick()
		process_travel_tick()

func request_rotation(rot : float) -> void:
	rpc("start_rotation", rot, NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func start_rotation(rot : float, tick : float):
	_end_rotation = rot
	for i in get_rollback_tick_count(tick):
		process_rotation_tick()

func get_rollback_tick_count(tick : float) -> int:
	return floor((NetworkTimeSynchronizer.get_time() - tick) / get_physics_process_delta_time())

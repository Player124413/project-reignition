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
var _movement_queue : Array[MovementData]
## Tracks whether this character is moving.
func is_travelling() -> bool:
	return _movement_queue.size() != 0
## Tracks whether this character is rotating or not.
var _is_rotating : bool

const ROTATION_SPEED : float = 10.0
const WALK_SPEED : float = 30.0
const RUN_SPEED : float = 60.0

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
	process_travel_tick()

func process_travel_tick() -> void:
	if !is_travelling() || _is_rotating:
		return
	
	var move_data : MovementData = _movement_queue[0]
	if !global_position.is_equal_approx(move_data.end_pos):
		global_position = global_position.move_toward(move_data.end_pos, _move_speed * get_physics_process_delta_time())
		return
	
	# Start the next queued movement
	_movement_queue.remove_at(0)
	if is_travelling():
		start_movement(false)
	else:
		character_animator.play_animation("%s/wait" % COMMON_LIBRARY_ANIMATION, true, 0.2)
		movement_finished.emit()

func process_rotation_tick() -> void:
	var target_rotation : float = _end_rotation
	var current_rotation : float = global_rotation.y
	if is_travelling():
		var offset : Vector3 = _movement_queue[0].end_pos - global_position
		if offset.is_zero_approx():
			return
		target_rotation = Vector3.MODEL_FRONT.signed_angle_to(offset, Vector3.UP)
	
	_is_rotating = !is_zero_approx(angle_difference(target_rotation, current_rotation))
	if !_is_rotating:
		return
	
	current_rotation = rotate_toward(current_rotation, target_rotation, ROTATION_SPEED * get_physics_process_delta_time())
	global_rotation = Vector3.UP * current_rotation

## Call this to add a new move to the queue.
func request_movement(end_pos : Vector3, is_running : bool, start_pos : Vector3 = Vector3.INF) -> void:
	if !NetworkManager.is_hosting_game:
		return
	if start_pos.is_equal_approx(Vector3.INF):
		start_pos = global_position
	rpc("queue_movement", start_pos, end_pos, is_running, NetworkTimeSynchronizer.get_time())

func request_cancel_movement() -> void:
	if !NetworkManager.is_hosting_game:
		return
	rpc("cancel_movement")

## Cancels all movements for this character.
@rpc("any_peer", "call_local", "reliable")
func cancel_movement() -> void:
	_movement_queue.clear()

@rpc("any_peer", "call_local", "reliable")
func queue_movement(start_pos : Vector3, end_pos : Vector3, is_running : bool, tick : float) -> void:
	var is_movement_active : bool = is_travelling()
	var new_move_data : MovementData = MovementData.new()
	new_move_data.start_pos = start_pos
	new_move_data.end_pos = end_pos
	new_move_data.is_running = is_running
	new_move_data.tick = tick
	_movement_queue.append(new_move_data)
	if !is_movement_active:
		start_movement(true)

func start_movement(use_tick : bool) -> void:
	global_position = _movement_queue[0].start_pos
	if _movement_queue[0].is_running:
		_move_speed = RUN_SPEED
		character_animator.play_animation("run", true, 0.2)
	else:
		_move_speed = WALK_SPEED
		character_animator.play_animation("%s/walk" % COMMON_LIBRARY_ANIMATION, true, 0.2)
	if !use_tick:
		return
	for i in get_rollback_tick_count(_movement_queue[0].tick):
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


class MovementData:
	var start_pos : Vector3
	var end_pos : Vector3
	var is_running : bool
	var tick : float

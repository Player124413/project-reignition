## Represents a fruit in the fruit catching minigame.
extends Node3D

signal collected
signal travel_finished

@export var animator : AnimationPlayer
@export var height_curve : Curve

var start_pos : Vector3
var end_pos : Vector3
var _is_collected : bool
var _start_time : float

# The index of the fruit's position on the pole.
var _fruit_index : int = -1
var _pusher : Node3D
var _previous_pusher_position : Vector3

const TRAVEL_HEIGHT : float = 20.0
const TRAVEL_LENGTH : float = 3.0
const RAPIER_SLIDE_SPEED : float = 20.0
const FRUIT_SIZE : float = 2.5
 
func _ready() -> void:
	top_level = true
	deactivate()

func _physics_process(_delta: float) -> void:
	process_movement_tick()

func deactivate() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false

func activate() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true

@rpc("any_peer", "call_local", "reliable")
func spawn(start : Vector3, end : Vector3, is_apple : bool, tick : float) -> void:
	start_pos = start
	end_pos = end
	global_position = start
	reset_physics_interpolation()
	_start_time = tick
	animator.play("apple" if is_apple else "orange")
	animator.advance(0.0)
	animator.play("spawn")
	animator.seek(NetworkTimeSynchronizer.get_time() - tick)
	activate()

func process_movement_tick() -> void:
	if _is_collected:
		if _fruit_index != -1:
			var target_pos : Vector3 = position
			target_pos.y = 0
			target_pos = target_pos.limit_length(FRUIT_SIZE * 0.3)
			target_pos.y = (_fruit_index + 1) * FRUIT_SIZE
			position = position.move_toward(target_pos, RAPIER_SLIDE_SPEED * get_physics_process_delta_time())
			if position.is_equal_approx(target_pos):
				_fruit_index = -1
				travel_finished.emit()
		return
	
	if is_instance_valid(_pusher):
		process_pusher()
	
	var time_ratio : float = (NetworkTimeSynchronizer.get_time() - _start_time) / TRAVEL_LENGTH
	var current_pos : Vector3 = start_pos.lerp(end_pos, time_ratio)
	current_pos.y += height_curve.sample(time_ratio) * TRAVEL_HEIGHT
	global_position = current_pos
	if time_ratio >= 1.0:
		deactivate()
		travel_finished.emit()

@rpc("any_peer", "call_local", "reliable")
func collect() -> void:
	top_level = false
	_is_collected = true
	# TODO Play FX
	animator.pause()
	collected.emit()

func process_pusher() -> void:
	var delta_pos : Vector3 = _pusher.global_position - _previous_pusher_position
	_previous_pusher_position = _pusher.global_position
	start_pos.x += delta_pos.x * 2
	end_pos.x += delta_pos.x * 2

func on_entered(area : Area3D) -> void:
	if _is_collected:
		return
	
	if area.is_in_group("player"):
		if is_multiplayer_authority():
			if !area.get_parent().is_invincible():
				print("Dealing Damage to player!")
				area.get_parent().rpc("take_damage", NetworkTimeSynchronizer.get_time())
		return
	
	if area.is_in_group("crusher"): # Start getting pushed by rapier
		_pusher = area
		_previous_pusher_position = area.global_position
		return
	
	if is_multiplayer_authority():
		_is_collected = true
		rpc("collect")

func _on_exited(area: Area3D) -> void:
	if area.is_in_group("crusher"):
		_pusher = null

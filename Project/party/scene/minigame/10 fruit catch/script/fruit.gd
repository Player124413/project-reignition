## Represents a fruit in the fruit catching minigame.
extends Node3D

signal collected
signal collection_finished

@export var animator : AnimationPlayer
@export var height_curve : Curve

var start_pos : Vector3
var end_pos : Vector3
var _is_collected : bool
var _start_time : float

# The index of the fruit's position on the pole.
var _fruit_index : int = -1

const TRAVEL_HEIGHT : float = 20.0
const TRAVEL_LENGTH : float = 3.0
const RAPIER_SLIDE_SPEED : float = 20.0
const FRUIT_SIZE : float = 2.5
 
func _ready() -> void:
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
				collection_finished.emit()
		return
	
	var time_ratio : float = (NetworkTimeSynchronizer.get_time() - _start_time) / TRAVEL_LENGTH
	var current_pos : Vector3 = start_pos.lerp(end_pos, time_ratio)
	current_pos.y += height_curve.sample(time_ratio) * TRAVEL_HEIGHT
	global_position = current_pos
	if time_ratio >= 1.0:
		deactivate()

func on_entered(area : Area3D) -> void:
	if area.is_in_group("player"):
		return # TODO Deal damage
	
	if _is_collected:
		return
	
	# Stick to the rapier
	call_deferred("reparent", area) # TODO Make this work online
	rpc("collect")

@rpc("any_peer", "call_local", "reliable")
func collect() -> void:
	_is_collected = true
	# TODO Play FX
	animator.pause()
	collected.emit()

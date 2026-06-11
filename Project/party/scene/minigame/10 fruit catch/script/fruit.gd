## Represents a fruit in the fruit catching minigame.
extends Node3D

@export var animator : AnimationPlayer
@export var height_curve : Curve

var start_pos : Vector3
var end_pos : Vector3
var _is_collected : bool
var _start_time : float

const TRAVEL_HEIGHT : float = 20.0
const TRAVEL_LENGTH : float = 4.0
 
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
	
	# Stick to the rapier
	if is_multiplayer_authority():
		# TODO Add score
		pass
	call_deferred("reparent", area)
	_is_collected = true

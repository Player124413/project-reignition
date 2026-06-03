## Represents a fruit in the fruit catching minigame.
extends Node3D

@export var animator : AnimationPlayer
@export var raycast : RayCast3D
var _is_collected : bool

const TRAVEL_HEIGHT : float = 10.0

func spawn(start : Vector3, end : Vector3, is_apple : bool, tick : float) -> void:
	global_position = start
	reset_physics_interpolation()
	animator.play("apple" if is_apple else "orange")
	animator.advance(0.0)
	animator.play("spawn")
	animator.seek(NetworkTimeSynchronizer.get_time() - tick)

func on_entered(area : Area3D) -> void:
	if area.is_in_group("player"):
		return # TODO Deal damage
	
	# Stick to the rapier
	if is_multiplayer_authority():
		# TODO Add score
		pass
	reparent(area)
	_is_collected = true

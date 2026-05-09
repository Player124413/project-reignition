extends Area3D

@export var animator : AnimationPlayer
var is_exploded : bool

func spawn(pos : Vector3) -> void:
	visible = true
	is_exploded = false
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = pos
	reset_physics_interpolation()
	animator.play("spawn")

@rpc("any_peer", "call_local", "reliable")
func explode() -> void:
	is_exploded = true
	animator.play("explode")

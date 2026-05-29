extends Area3D

@export var animator : AnimationPlayer
@export var catch_sfx : AudioStreamPlayer
@export var explode_sfx : AudioStreamPlayer
var is_exploded : bool

func spawn(pos : Vector3) -> void:
	visible = true
	is_exploded = false
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = pos
	reset_physics_interpolation()
	animator.play("spawn")

func catch() -> void:
	catch_sfx.play()

@rpc("any_peer", "call_local", "reliable")
func explode() -> void:
	is_exploded = true
	explode_sfx.play()
	animator.play("explode")

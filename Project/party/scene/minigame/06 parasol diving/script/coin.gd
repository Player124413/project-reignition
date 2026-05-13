extends Area3D

@export var collect_sfx : GroupSfxPlayer
@export var mesh : MeshInstance3D
@export var animator : AnimationPlayer
@export var materials : Array[Material]
var _is_bonus : bool
var _collect_time : float
var _collect_index : int = -1

func spawn(pos : Vector3, is_bonus : bool) -> void:
	_is_bonus = is_bonus
	_collect_time = 0
	_collect_index = -1
	global_position = pos
	reset_physics_interpolation()
	mesh.material_override = materials[0 if _is_bonus else 1]
	animator.play("spawn")
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true

@rpc("any_peer", "call_local", "reliable")
func request_collect(time : float, index : int) -> void:
	if _collect_time > 0 && time > _collect_time: # Already collected
		return
	
	animator.play("collect")
	if !NetworkManager.is_hosting_game:
		return
	
	var score : int = 3 if _is_bonus else 1
	if time < _collect_time: # Collision resolution
		MinigameManager.instance.request_score_popup_abort(_collect_index, _collect_time)
		MinigameManager.instance.request_score_change(_collect_index, -score)
	
	_collect_time = time
	_collect_index = index
	
	collect_sfx.play_in_group()
	var projected_position : Vector3 = global_position + Vector3.UP * 2
	var screen_pos : Vector2 = get_viewport().get_camera_3d().unproject_position(projected_position)
	MinigameManager.instance.request_score_popup(_collect_index, score, screen_pos)
	MinigameManager.instance.request_score_change(_collect_index, score)

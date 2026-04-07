### Responsible for syncing the player's blinking blend shape.
@tool
extends MeshInstance3D

@export var influence : float = 10.0
@export var bone_name : StringName
var _skeleton : Skeleton3D
var _bone_index : int = -1

func update_bone_index() -> void:
	_bone_index = -1
	if _skeleton == null:
		return
	
	for i in _skeleton.get_bone_count():
		if _skeleton.get_bone_name(i) == bone_name:
			_bone_index = i
			return

func _enter_tree() -> void:
	if get_parent() is not Skeleton3D:
		printerr("Blink Animator only works on a mesh instance parented to a Skeleton3D.")
	_skeleton = get_parent() as Skeleton3D
	_skeleton.connect("pose_updated", Callable.create(self, "update_blend_shape"))
	update_bone_index()

func update_blend_shape() -> void:
	var bone_position : Vector3 = calculate_local_bone_position()
	set_blend_shape_value(0, clamp(bone_position.x * influence, 0.0, 1.0))

func calculate_local_bone_position() -> Vector3:
	var pose_transform : Transform3D = _skeleton.get_bone_pose(_bone_index)
	var rest_transform : Transform3D = _skeleton.get_bone_rest(_bone_index)
	var pose_position : Vector3 = pose_transform.origin * pose_transform.inverse()
	var rest_position : Vector3 = rest_transform.origin * rest_transform.inverse()
	var local_position : Vector3 = pose_position - rest_position
	return local_position

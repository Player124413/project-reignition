### Responsible for updating visibility of hands and face.
@tool
extends Skeleton3D

@export_tool_button("Update Meshes") var update_mesh_callable = Callable.create(self, "update_meshes")

enum FACE_ENUM {
	DEFAULT,
	HAPPY,
	SAD,
	SHOCK
}

enum HAND_ENUM {
	CURL,
	FIST,
	FLAT,
	OPEN,
	POINT,
	RELAX,
	THUMB,
	PEACE,
}

@export var face : FACE_ENUM:
	get:
		return _face
	set(value):
		toggle_visibilty(face_meshes.get(_face), face_meshes.get(value))
		_face = value
var _face : FACE_ENUM = FACE_ENUM.DEFAULT

@export var left_hand : HAND_ENUM = HAND_ENUM.FIST:
	get:
		return _left_hand
	set(value):
		toggle_visibilty(left_hand_meshes.get(_left_hand), left_hand_meshes.get(value))
		_left_hand = value
var _left_hand : HAND_ENUM = HAND_ENUM.FIST
@export var right_hand : HAND_ENUM = HAND_ENUM.FIST:
	get:
		return _right_hand
	set(value):
		toggle_visibilty(right_hand_meshes.get(_right_hand), right_hand_meshes.get(value))
		_right_hand = value
var _right_hand : HAND_ENUM = HAND_ENUM.FIST

@export_group("References")
@export var face_meshes : Array[Node3D]
@export var left_hand_meshes : Array[Node3D]
@export var right_hand_meshes : Array[Node3D]

func update_meshes() -> void:
	face_meshes.clear()
	for key in FACE_ENUM.keys().size():
		var target_path : String = "face_" + str(FACE_ENUM.keys()[key]).to_lower()
		var mesh : Node3D = get_node_or_null(target_path) as Node3D
		face_meshes.append(mesh)
		if mesh != null:
			mesh.visible = key == _face
	
	left_hand_meshes.clear()
	right_hand_meshes.clear()
	for key in HAND_ENUM.keys().size():
		var target_path : String = "hand_" + str(HAND_ENUM.keys()[key]).to_lower()
		var left_mesh : Node3D = get_node_or_null(target_path + "_l") as Node3D
		var right_mesh : Node3D = get_node_or_null(target_path + "_r") as Node3D
		left_hand_meshes.append(left_mesh)
		right_hand_meshes.append(right_mesh)
		if left_mesh != null:
			left_mesh.visible = key == _left_hand
		if right_mesh != null:
			right_mesh.visible = key == _right_hand

## Toggles the visibility of two given meshes.
func toggle_visibilty(old_mesh : Node3D, new_mesh : Node3D) -> void:
	if old_mesh != null:
		old_mesh.visible = false
	if new_mesh != null:
		new_mesh.visible = true

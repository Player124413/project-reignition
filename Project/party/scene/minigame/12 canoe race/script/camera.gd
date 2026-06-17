extends Node3D

const MIN_ZOOM : Vector3 = Vector3(0, -15, 150)
const MAX_ZOOM : Vector3 = Vector3(0, 0, 500)
const MAX_ZOOM_DISTANCE : float = 400.0
const RIVER_HEIGHT_OFFSET : int = 15

@export var players : Array[Node3D]
@export var camera : Camera3D

func _physics_process(_delta : float) -> void:
	var center : Vector3 = get_center_position() + Vector3.UP * RIVER_HEIGHT_OFFSET
	global_position = center
	var bounds : AABB = get_bounds()
	var zoom_level : float = clamp(bounds.size.length() / MAX_ZOOM_DISTANCE, 0.0, 1.0)
	var target_camera_pos : Vector3 = MIN_ZOOM.lerp(MAX_ZOOM, zoom_level)
	camera.position = camera.position.lerp(target_camera_pos, 0.2)

func get_center_position() -> Vector3:
	var pos : Vector3 = Vector3.ZERO
	for i in players.size():
		pos += players[i].character_body.global_position
	return pos / players.size()

func get_bounds() -> AABB:
	var bounds : AABB = AABB(global_position, Vector3.ZERO)
	for i in players.size():
		bounds = bounds.expand(players[i].character_body.global_position)
	return bounds

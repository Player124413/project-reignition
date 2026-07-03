extends Node3D

const MIN_ZOOM : Vector3 = Vector3(0, -15, 150)
const MAX_ZOOM : Vector3 = Vector3(0, 0, 500)
const MAX_ZOOM_DISTANCE : float = 400.0
const RIVER_HEIGHT_OFFSET : int = 15

@export var players : Array[Node3D]
@export var camera : Camera3D
@export var distance_curve : Curve

func _ready() -> void:
	for i in range(players.size() - 1, 0, -1):
		if !PartyManager.minigame_players.has(players[i].player_index):
			players.remove_at(i)

func _physics_process(_delta : float) -> void:
	var bounds : AABB = get_bounds()
	global_position = bounds.get_center()
	var zoom_level : float = clamp(bounds.size.length() / MAX_ZOOM_DISTANCE, 0.0, 1.0)
	zoom_level = distance_curve.sample(zoom_level)
	var target_camera_pos : Vector3 = MIN_ZOOM.lerp(MAX_ZOOM, zoom_level)
	camera.position = camera.position.lerp(target_camera_pos, 0.2)

func get_bounds() -> AABB:
	var bounds : AABB = AABB(players[0].global_position, Vector3.ZERO)
	for i in players.size():
		bounds = bounds.expand(players[i].character_body.global_position)
	return bounds

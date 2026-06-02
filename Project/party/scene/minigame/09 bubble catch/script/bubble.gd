extends Node3D

signal despawned

@export var animator : AnimationPlayer
@export var particles : GPUParticles3D
@export var rise_speed : float = 10.0
@export var captured_rise_speed : float = 20.0

@export var mesh : MeshInstance3D
@export var bubble_materials : Array[Material]
var player_index : int
var bubble_size : int
var current_butterfly : Node3D
var collection_tick : float

var _lifetime : float
const BUBBLE_LIFETIME : float = 5.0

func update_material(index : int) -> void:
	player_index = index
	mesh.material_override = bubble_materials[index]

@rpc("any_peer", "call_local", "reliable")
func spawn(pos : Vector3, size : int, tick : float) -> void:
	var tick_offset : float = NetworkTimeSynchronizer.get_time() - tick
	top_level = true
	visible = true
	bubble_size = size
	process_mode = Node.PROCESS_MODE_INHERIT
	global_position = pos + Vector3.UP * tick_offset * rise_speed
	reset_physics_interpolation()
	animator.play("size%s" % size)
	animator.advance(0.0)
	animator.play("move")
	_lifetime = BUBBLE_LIFETIME - tick_offset

func despawn() -> void:
	top_level = false
	visible = false
	if is_instance_valid(current_butterfly):
		current_butterfly.request_spawn()
	current_butterfly = null
	process_mode = Node.PROCESS_MODE_DISABLED
	despawned.emit()

@rpc("any_peer", "call_local", "reliable")
func collect_butterfly(butterfly_index : int, tick : float, popup_pos : Vector2) -> void:
	if is_instance_valid(current_butterfly):
		if tick >= collection_tick:
			return
		# Collision resolution
		current_butterfly.is_in_bubble = false
		
		if is_multiplayer_authority():
			MinigameManager.instance.request_score_change(player_index, -3 if current_butterfly.is_bonus else -1)
			MinigameManager.instance._score_popup_abort(player_index, collection_tick)
	
	var target_butterfly : Node3D = ButterflyManager.instance.butterflies[butterfly_index]
	if target_butterfly.is_in_bubble: # This butterfly has already been collected. ABORT!!!
		return
	
	if current_butterfly == null:
		animator.play("capture")
		particles.RestartGroup()
	
	current_butterfly = target_butterfly
	var score : int = 3 if current_butterfly.is_bonus else 1
	current_butterfly.is_in_bubble = true
	collection_tick = tick
	if is_multiplayer_authority():
		MinigameManager.instance.request_score_change(player_index, score)
		MinigameManager.instance.request_score_popup(player_index, score, popup_pos)

func _physics_process(_delta: float) -> void:
	process_movement_tick()

func process_movement_tick() -> void:
	if is_instance_valid(current_butterfly):
		global_position += captured_rise_speed * Vector3.UP * get_physics_process_delta_time()
		current_butterfly.global_position = global_position
	else:
		global_position += rise_speed * Vector3.UP * get_physics_process_delta_time()
	_lifetime -= get_physics_process_delta_time()
	if _lifetime <= 0:
		despawn()

class_name ParasolBall extends Area3D

## Emitted after this ball is hit
signal hit
## Emitted after this ball is deactivated.
signal deactivated()

@export var animator : AnimationPlayer
@export var mesh : MeshInstance3D
@export var materials : Array[Material]
@export var fall_curve : Curve
@export var hit_curve : Curve
@export var is_demo_ball : bool
@export var left_raycast : RayCast3D
@export var right_raycast : RayCast3D
const COLLISION_RADIUS : float = 3.0

var is_bonus_ball : bool
var start_position : Vector3
var end_position : Vector3
var travel_timer : float
const HIT_TIME : float = 0.4
const FALL_TIME : float = 4.0
const ANIMATION_HEIGHT : int = 30

var is_active : bool
## Tracks whether this ball is falling or hit.
var is_hit : bool
## The tick when this ball was hit.
var hit_time : float
## The player who hit this ball.
var hit_index : int = -1

## Tracks the number of cpus chasing this ball (local variable because cpus are simulated on a single device).
var cpu_count : int

func _ready() -> void:
	if NetworkManager.is_hosting_game && is_demo_ball:
		initialize(false)

## Kick off the demo by spawning a ball.
func start_demo() -> void:
	is_active = true
	spawn(NetworkTimeSynchronizer.get_time(), global_position)

@rpc("any_peer", "call_local", "reliable")
func initialize(is_bonus : bool) -> void:
	is_bonus_ball = is_bonus
	mesh.material_override = materials[0 if is_bonus else 1]
	visible = false
	set_physics_process(false)

@rpc("any_peer", "call_local", "reliable")
func hit_ball(time : float, player_index : int, start_pos : Vector3, end_pos : Vector3) -> void:
	if !is_zero_approx(hit_time) && hit_time < time: # Conflict resolution
		return
	
	if player_index != -1:
		var data : PlayerData = PartyManager.get_player_data(player_index)
		if !data.is_cpu_player():
			set_multiplayer_authority(data.device)
	travel_timer = NetworkTimeSynchronizer.get_time() - time
	start_position = start_pos
	end_position = end_pos
	is_hit = true
	hit_index = player_index
	hit_time = time
	monitorable = false
	animator.play("RESET")
	hit.emit()
	set_physics_process(true)
	process_movement_tick()

@rpc("any_peer", "call_local", "reliable")
func spawn(time : float, spawn_pos : Vector3) -> void:
	start_falling(spawn_pos)
	reset_physics_interpolation()
	
	is_active = true
	visible = true
	animator.play("RESET")
	set_physics_process(true)
	monitorable = true
	monitoring = true
	left_raycast.enabled = true
	right_raycast.enabled = true
	travel_timer = NetworkTimeSynchronizer.get_time() - time
	process_movement_tick()

func start_falling(pos : Vector3) -> void:
	is_hit = false
	travel_timer = 0
	global_position = pos
	start_position = pos
	end_position = pos
	end_position.y = 0

func _physics_process(delta: float) -> void:
	if !is_active:
		return
	
	travel_timer += delta
	process_movement_tick()
	process_collision()

func process_collision() -> void:
	if is_hit:
		return
	
	if left_raycast.is_colliding():
		start_position.x = left_raycast.get_collision_point().x + COLLISION_RADIUS
		end_position.x = start_position.x
	elif right_raycast.is_colliding():
		start_position.x = right_raycast.get_collision_point().x - COLLISION_RADIUS
		end_position.x = start_position.x

func process_movement_tick() -> void:
	if !is_active:
		return
	
	var denominator : float = HIT_TIME if is_hit else FALL_TIME
	var ratio : float = clamp(travel_timer / denominator, 0, 1)
	if is_hit:
		ratio = hit_curve.sample(ratio)
	else:
		ratio = fall_curve.sample(ratio)
	global_position = start_position.lerp(end_position, ratio)
	
	if is_equal_approx(ratio, 1.0):
		if is_hit:
			start_falling(end_position)
		else:
			deactivate()
	elif global_position.y < ANIMATION_HEIGHT:
		animator.play("fall")

func deactivate() -> void:
	monitoring = false
	monitorable = false
	left_raycast.enabled = false
	right_raycast.enabled = false
	is_active = false
	set_physics_process(false) 
	animator.play("destroy")
	deactivated.emit()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		return
	
	call_deferred("deactivate")
	
	if !is_multiplayer_authority():
		return
	if hit_index == -1:
		MinigameManager.instance.request_minigame_start()
	else:
		var score : int = 3 if is_bonus_ball else 1
		var projected_position : Vector3 = global_position + Vector3.UP * 2
		var screen_pos : Vector2 = get_viewport().get_camera_3d().unproject_position(projected_position)
		rpc("request_score_popup", hit_index, score, screen_pos)

@rpc("any_peer", "call_local", "reliable")
func request_score_popup(player_index : int, score : int, screen_pos : Vector2) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	MinigameManager.instance.request_score_popup(player_index, score, screen_pos)
	MinigameManager.instance.request_score_change(player_index, score)

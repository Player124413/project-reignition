extends Area3D

@export var animator : AnimationPlayer
@export var mesh : MeshInstance3D
@export var materials : Array[Material]
@export var fall_curve : Curve
@export var hit_curve : Curve

var start_position : Vector3
var end_position : Vector3
var travel_timer : float
const HIT_TIME : float = 0.4
const FALL_TIME : float = 4.0
const ANIMATION_HEIGHT : int = 30

## Tracks whether this ball is falling or hit.
var is_hit : bool
## The tick when this ball was hit.
var hit_time : float
## The player who hit this ball.
var hit_index : int = -1

func initialize(is_bonus : bool) -> void:
	mesh.material_override = materials[0 if is_bonus else 1]
	visible = false
	set_physics_process(false)

@rpc("any_peer", "call_local", "reliable")
func hit_ball(time : float, player_index : int, start_pos : Vector3, end_pos : Vector3) -> void:
	if !is_zero_approx(hit_time) && hit_time < time: # Conflict resolution
		return
	
	travel_timer = NetworkTimeSynchronizer.get_time() - time
	start_position = start_pos
	end_position = end_pos
	is_hit = true
	hit_index = player_index
	hit_time = time
	monitorable = false
	animator.play("RESET")
	set_physics_process(true)
	process_movement_tick()

@rpc("any_peer", "call_local", "reliable")
func request_spawn(time : float, spawn_pos : Vector3) -> void:
	start_falling(spawn_pos)
	reset_physics_interpolation()
	var callable : Callable = Callable(self, "spawn").bind()
	get_tree().create_timer(NetworkTimeSynchronizer.get_time() - time).timeout.connect(callable)

func spawn() -> void:
	visible = true
	animator.play("RESET")
	set_physics_process(true)
	monitorable = true

func start_falling(pos : Vector3) -> void:
	is_hit = false
	travel_timer = 0
	global_position = pos
	start_position = pos
	end_position = pos
	end_position.y = 0

func _physics_process(delta: float) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	travel_timer += delta
	process_movement_tick()

func process_movement_tick() -> void:
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
	monitorable = false
	set_physics_process(false) 
	animator.play("destroy")

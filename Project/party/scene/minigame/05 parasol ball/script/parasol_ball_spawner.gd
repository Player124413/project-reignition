extends Node3D

@export var spawn_bounds : Vector2
@export var total_spawn_length : float = 30
@export var total_bonus_ball_count : int = 12

var ball_pool : Array[Area3D]
var current_ball_index : int
var deactivated_ball_count : int
var spawn_timer : float
var _spawn_interval : float

func _ready() -> void:
	initialize_ball_pool()
	set_physics_process(false)
	
	if !NetworkManager.is_hosting_game:
		return
	
	_spawn_interval = total_spawn_length / ball_pool.size()
	MinigameManager.instance.gameplay_started.connect(Callable(self,"start_spawning"))

func on_ball_deactivated() -> void:
	if !NetworkManager.is_hosting_game:
		return
	deactivated_ball_count += 1
	if deactivated_ball_count >= ball_pool.size():
		MinigameManager.instance.request_autoplay_results()

func start_spawning() -> void:
	set_physics_process(true)

func initialize_ball_pool() -> void:
	for i in get_child_count():
		ball_pool.append(get_child(i))
	
	for ball in ball_pool:
		ball.deactivated.connect(Callable(self, "on_ball_deactivated"), CONNECT_ONE_SHOT)
		ball.call_deferred("initialize", false)

func _physics_process(delta: float) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	spawn_timer -= delta
	if spawn_timer < 0:
		spawn_timer = _spawn_interval
		request_ball_spawn()

func request_ball_spawn() -> void:
	var spawn_position : Vector3 = global_position
	spawn_position.x += (1.0 - randf() * 2.0) * spawn_bounds.x
	spawn_position.z += (1.0 - randf() * 2.0) * spawn_bounds.y
	var spawn_time : float = NetworkTimeSynchronizer.get_time() + 0.5
	ball_pool[current_ball_index].rpc("request_spawn", spawn_time, spawn_position)
	current_ball_index += 1
	if current_ball_index >= ball_pool.size(): # Done spawning
		set_physics_process(false)

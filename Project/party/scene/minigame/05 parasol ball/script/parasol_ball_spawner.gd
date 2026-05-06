extends Node3D

@export var parasol_ball_scene : PackedScene
@export var spawn_bounds : Vector2
@export var total_ball_count : int = 45
@export var total_spawn_length : float = 30
@export var total_bonus_ball_count : int = 12

var ball_pool : Array
var current_ball_index : int
var spawn_timer : float
var _spawn_interval : float

func _ready() -> void:
	initialize_ball_pool()
	set_physics_process(false)
	
	if !NetworkManager.is_hosting_game:
		return
	
	_spawn_interval = 1.5
	MinigameManager.instance.gameplay_started.connect(Callable(self,"start_spawning"))

func start_spawning() -> void:
	set_physics_process(true)

func initialize_ball_pool() -> void:
	ball_pool.resize(total_ball_count)
	for i in total_ball_count:
		var new_ball : Node3D = parasol_ball_scene.instantiate() as Node3D
		new_ball.initialize(false)
		add_child(new_ball)
		ball_pool[i] = new_ball

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
	print("Spawning ball %s" % current_ball_index)
	if current_ball_index >= ball_pool.size(): # Done spawning
		set_physics_process(false)

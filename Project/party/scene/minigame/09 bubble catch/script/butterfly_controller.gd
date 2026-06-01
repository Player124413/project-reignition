extends Node3D

@export var root : Node3D
@export var move_speed : float = 10.0
@export var rotation_speed : float = 10.0
@export var is_bonus : bool
@export var rollback_timer : RollbackTimer

var current_bubble : Node3D
var target_move_angle : float
var is_gameplay_started : bool

const NORMAL_HEIGHT : float = 15.0
const BONUS_HEIGHT : float = 20.0

const SPAWN_BOUNDS : int = 45
const SPAWN_DEPTH_BOUNDS : int = 40
const SPAWN_POSITION : int = 60

func _ready() -> void:
	rollback_timer.register_target(self)

func on_gameplay_started() -> void:
	is_gameplay_started = true

func _physics_process(_delta: float) -> void:
	process_movement_tick()
	if NetworkManager.is_hosting_game:
		process_rollback()


#######################
### ROLLBACK CODE #####
#######################
const RB_POS : int = 0
const RB_ANGLE : int = 1
func on_rollback_applied(rb_params : Array) -> void:
	global_position = rb_params[RB_POS]
	target_move_angle = rb_params[RB_ANGLE]

func process_rollback() -> void:
	rollback_timer.set_param(RB_POS, global_position)
	rollback_timer.set_param(RB_ANGLE, target_move_angle)
	rollback_timer.process_rollback()

func process_movement_tick() -> void:
	if is_zero_approx(angle_difference(target_move_angle, root.rotation.y)):
		global_position -= root.basis.z * move_speed * get_physics_process_delta_time()
	else:
		var current_rotation : float = root.rotation.y
		current_rotation = rotate_toward(current_rotation, target_move_angle, rotation_speed * get_physics_process_delta_time())
		root.rotation = Vector3.UP * current_rotation
	
	if !NetworkManager.is_hosting_game:
		return
	
	if abs(position.x) >= SPAWN_BOUNDS && sign(position.x) != sign(target_move_angle):
		rpc("turnaround")

@rpc("any_peer", "call_local" , "reliable")
func spawn(pos : Vector3) -> void:
	pos.y = BONUS_HEIGHT if is_bonus else NORMAL_HEIGHT
	global_position = pos
	target_move_angle = PI * 0.5
	if sign(pos.x) < 0:
		target_move_angle -= PI

@rpc("any_peer", "call_local", "reliable")
func turnaround() -> void:
	target_move_angle *= -1

func request_spawn() -> void:
	if !NetworkManager.is_hosting_game:
		return
	rpc("spawn", generate_random_position())

func generate_random_position() -> Vector3:
	var pos : Vector3 = Vector3.ZERO
	pos.z = (1.0 - randf() * 2.0) * SPAWN_DEPTH_BOUNDS
	if is_gameplay_started:
		pos.x = SPAWN_BOUNDS if randf() > 0.5 else -SPAWN_BOUNDS
	else:
		pos.x = (1.0 - randf() * 2.0) * SPAWN_BOUNDS
	return pos

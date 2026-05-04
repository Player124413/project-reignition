extends Node3D

### The cogwheel this is on
var cogwheel : Node3D

@export var root : Node3D
@export var mesh : MeshInstance3D
@export var materials : Array[Material]
@export var raycast : RayCast3D

var current_speed : float
const MAX_MOVE_SPEED : float = 3.0
const ACCELERATION : float = 30.0
const GRAVITY : float = 30.0

var is_bonus_majin : bool
var is_collected : bool

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	if is_collected:
		return
	
	var speed : float = 0
	if raycast.is_colliding():
		if is_colliding_with_ground():
			on_majin_collected()
			return
		
		global_position = raycast.get_collision_point()
		var target_speed : float = MAX_MOVE_SPEED * sign(cogwheel.current_rotation_speed)
		current_speed = move_toward(current_speed, target_speed, ACCELERATION * delta)
		speed = cogwheel.current_rotation_speed - current_speed
	else:
		current_speed = move_toward(current_speed, 0, ACCELERATION * delta)
		global_position += Vector3.DOWN * GRAVITY * delta
	
	# Update the inputs of the demo based on this majin's state
	if !cogwheel.is_demo_complete:
		cogwheel.apply_demo_input(raycast.is_colliding(), delta)
	
	global_position += Vector3.RIGHT * speed * delta
	process_animation()

func process_animation() -> void:
	root.rotation = Vector3.DOWN * PI * 0.5 * (current_speed / MAX_MOVE_SPEED)

func is_colliding_with_ground() -> bool:
	var collider : Node3D = raycast.get_collider() as Node3D
	return collider.is_in_group("floor")

func request_spawn(spawn_position : Vector3, is_bonus : bool) -> void:
	rpc("spawn", spawn_position, is_bonus)

func on_majin_collected() -> void:
	is_collected = true
	var score : int = 3 if is_bonus_majin else 1
	var projected_position : Vector3 = cogwheel.global_position + Vector3.UP * 8
	var screen_pos : Vector2 = get_tree().root.get_camera_3d().unproject_position(projected_position)
	MinigameManager.instance.request_score_popup(cogwheel.player_index, score, screen_pos)
	if cogwheel.is_demo_complete:
		MinigameManager.instance.request_score_change(cogwheel.player_index, score)
	else:
		cogwheel.complete_demo()

@rpc("any_peer", "call_local", "reliable")
func spawn(spawn_position : Vector3, is_bonus : bool) -> void:
	is_bonus_majin = is_bonus
	mesh.material_override = materials[0 if is_bonus_majin else 1]
	global_position = spawn_position
	visible = true
	set_process(true)
	set_physics_process(true)

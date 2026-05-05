extends Area3D

### The cogwheel this is on
var cogwheel : Node3D

@export var root : Node3D
@export var collider : CollisionShape3D
@export var mesh : MeshInstance3D
@export var materials : Array[Material]
@export var raycast : RayCast3D

var current_speed : float
const MAX_MOVE_SPEED : float = 3.0
const ACCELERATION : float = 30.0
const GRAVITY : float = 30.0
const COLLECTED_MOVE_SPEED : float = 12.0
const COLLECTED_ROTATION_SPEED : float = 8.0

var is_bonus_majin : bool
var is_collected : bool
var collected_position : Vector3

func initialize() -> void:
	visible = false
	set_process(false)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	if is_collected:
		process_collected_position(delta)
		return
	
	var speed : float = 0
	if raycast.is_colliding():
		global_position = raycast.get_collision_point()
		
		if is_colliding_with_ground():
			on_majin_collected()
			return
		
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
	if !raycast.is_colliding(): # Don't update directions in the air
		return
	
	root.rotation = Vector3.DOWN * PI * 0.5 * (current_speed / MAX_MOVE_SPEED)

func process_collected_position(delta : float) -> void:
	if position.is_equal_approx(collected_position): # Finished; disable majin
		raycast.enabled = false
		root.rotation = root.rotation.move_toward(Vector3.ZERO, COLLECTED_ROTATION_SPEED * delta)
		if root.rotation.is_zero_approx():
			set_physics_process(false)
		return
	
	position = position.move_toward(collected_position, MAX_MOVE_SPEED * delta)
	var movement_direction : Vector3 = collected_position - position
	var angle : float = movement_direction.signed_angle_to(Vector3.FORWARD, Vector3.UP)
	var target_rotation : Vector3 = Vector3.UP * angle
	root.rotation = root.rotation.move_toward(target_rotation, COLLECTED_ROTATION_SPEED * delta)

func is_colliding_with_ground() -> bool:
	var col : Node3D = raycast.get_collider() as Node3D
	return col.is_in_group("floor")

func request_spawn(spawn_position : Vector3, is_bonus : bool) -> void:
	rpc("spawn", spawn_position, is_bonus)

func on_majin_collected() -> void:
	is_collected = true
	collider.disabled = true
	
	if is_multiplayer_authority():
		var score : int = 3 if is_bonus_majin else 1
		var projected_position : Vector3 = cogwheel.global_position + Vector3.UP * 8
		var screen_pos : Vector2 = get_tree().root.get_camera_3d().unproject_position(projected_position)
		MinigameManager.instance.request_score_popup(cogwheel.player_index, score, screen_pos)
		if cogwheel.is_demo_complete:
			MinigameManager.instance.request_score_change(cogwheel.player_index, score)
		else:
			cogwheel.complete_demo()
		rpc("set_collected_position", calculate_collected_position())

@rpc("any_peer", "call_local", "reliable")
func set_collected_position(pos : Vector3) -> void:
	collected_position = pos

const BASKET_WIDTH : float = 5
const BASKET_DEPTH : float = 1.4
func calculate_collected_position() -> Vector3:
	var pos : Vector3 = Vector3.ZERO
	pos.x = (1 - randf() * 2) * BASKET_WIDTH
	pos.z = (1 - randf() * 2) * BASKET_DEPTH
	return pos

@rpc("any_peer", "call_local", "reliable")
func spawn(spawn_position : Vector3, is_bonus : bool) -> void:
	is_bonus_majin = is_bonus
	mesh.material_override = materials[0 if is_bonus_majin else 1]
	global_position = spawn_position
	reset_physics_interpolation()
	visible = true
	raycast.enabled = true
	collider.disabled = false
	set_physics_process(true)

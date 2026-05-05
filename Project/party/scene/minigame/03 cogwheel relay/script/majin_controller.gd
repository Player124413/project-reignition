extends Area3D

### The cogwheel this is on
var cogwheel : Node3D

@export var collider : CollisionShape3D
@export var mesh : MeshInstance3D
@export var materials : Array[Material]
@export var ceiling_raycast : RayCast3D
@export var animator : AnimationPlayer
@export var ground_raycast : RayCast3D

var current_speed : float
const MOVE_SPEED : float = 3.0
const ACCELERATION : float = 10.0
const GRAVITY : float = 30.0
const GROUNDED_MOVEMENT_SPEED : float = 6.0
const GROUNDED_ROTATION_SPEED : float = 8.0
const JUMP_HEIGHT : float = 3.0
const JUMP_LENGTH : float = 0.4

var is_bonus_majin : bool
var is_jump_queued : bool
var is_jumping : bool
var jump_timer : float
var jump_start : Vector3
var jump_end : Vector3
var is_grounded : bool
var grounded_position : Vector3

func initialize() -> void:
	visible = false
	set_process(false)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	if is_jumping:
		process_jump(delta)
		return
	
	if is_jump_queued && attempt_jump():
		return
	
	if is_grounded:
		process_grounded_position(delta)
		return
	
	var speed : float = 0
	if ground_raycast.is_colliding():
		if is_colliding_with_ground():
			on_majin_grounded()
			return
		
		if is_colliding_with_object():
			global_position = ground_raycast.get_collision_point()
		
		var desired_direction : int = sign(position.x)
		var target_speed : float = 0
		if is_zero_approx(cogwheel.current_rotation_speed):
			target_speed = -desired_direction * MOVE_SPEED
		elif sign(cogwheel.current_rotation_speed) != desired_direction:
			target_speed = MOVE_SPEED * sign(cogwheel.current_rotation_speed)
			
		current_speed = move_toward(current_speed, target_speed, ACCELERATION * delta)
		speed = cogwheel.current_rotation_speed - current_speed
	else:
		current_speed = move_toward(current_speed, 0, ACCELERATION * delta)
		global_position += Vector3.DOWN * GRAVITY * delta
	
	# Update the inputs of the demo based on this majin's state
	if !cogwheel.is_demo_complete:
		cogwheel.apply_demo_input(ground_raycast.is_colliding(), delta)
	
	global_position += Vector3.RIGHT * speed * delta
	if ground_raycast.is_colliding(): # Don't update directions in the air
		rotation = Vector3.DOWN * PI * 0.5 * (current_speed / MOVE_SPEED)

func process_grounded_position(delta : float) -> void:
	if global_position.is_equal_approx(grounded_position): # Finished; disable majin
		rotation = rotation.move_toward(Vector3.ZERO, GROUNDED_ROTATION_SPEED * delta)
		if rotation.is_zero_approx():
			set_physics_process(false)
		return
	
	global_position = global_position.move_toward(grounded_position, GROUNDED_MOVEMENT_SPEED * delta)
	var movement_direction : Vector3 = grounded_position - global_position
	var target_angle : float = movement_direction.signed_angle_to(Vector3.BACK, Vector3.DOWN)
	var current_rotation : float = rotation.y
	current_rotation = rotate_toward(current_rotation, target_angle, GROUNDED_ROTATION_SPEED * delta)
	rotation = Vector3.UP * current_rotation

func is_colliding_with_ground() -> bool:
	var col : Node3D = ground_raycast.get_collider() as Node3D
	return col.is_in_group("floor")

func is_colliding_with_object() -> bool:
	var col : Node3D = ground_raycast.get_collider() as Node3D
	return col.is_in_group("player") || col.is_in_group("enemy")

func request_spawn(spawn_position : Vector3, is_bonus : bool) -> void:
	rpc("spawn", spawn_position, is_bonus)

func on_majin_grounded() -> void:
	is_jumping = false
	is_grounded = true
	collider.disabled = true
	ground_raycast.enabled = false
	ceiling_raycast.enabled = false
	global_position = ground_raycast.get_collision_point()
	if !is_multiplayer_authority():
		return
	
	var col : Node3D = ground_raycast.get_collider() as Node3D
	if col.is_in_group("player"): # Collected
		var score : int = 3 if is_bonus_majin else 1
		var projected_position : Vector3 = cogwheel.global_position + Vector3.UP * 8
		var screen_pos : Vector2 = get_tree().root.get_camera_3d().unproject_position(projected_position)
		MinigameManager.instance.request_score_popup(cogwheel.player_index, score, screen_pos)
		if cogwheel.is_demo_complete:
			MinigameManager.instance.request_score_change(cogwheel.player_index, score)
		else:
			cogwheel.complete_demo()
		rpc("play_animation", "stun")
		rpc("set_grounded_position", calculate_grounded_position())
	else: # Exiting
		rpc("play_animation", "land")
		rpc("set_grounded_position", calculate_exit_position(col.global_position))

@rpc("any_peer", "call_local", "reliable")
func play_animation(anim : String) -> void:
	animator.play(anim)

@rpc("any_peer", "call_local", "reliable")
func set_grounded_position(pos : Vector3) -> void:
	grounded_position = pos

const BASKET_WIDTH : float = 4
const BASKET_DEPTH : float = 1.2
func calculate_grounded_position() -> Vector3:
	var pos : Vector3 = Vector3.ZERO
	pos.x = (1 - randf() * 2) * BASKET_WIDTH
	pos.z = (1 - randf() * 2) * BASKET_DEPTH
	return cogwheel.global_position + pos

func calculate_exit_position(exit_pos : Vector3) -> Vector3:
	return exit_pos + Vector3.FORWARD * 8.0

@rpc("any_peer", "call_local", "reliable")
func spawn(spawn_position : Vector3, is_bonus : bool) -> void:
	is_bonus_majin = is_bonus
	mesh.material_override = materials[0 if is_bonus_majin else 1]
	global_position = spawn_position
	reset_physics_interpolation()
	visible = true
	ground_raycast.enabled = true
	ceiling_raycast.enabled = true
	collider.disabled = false
	set_physics_process(true)

func attempt_jump() -> bool:
	if is_grounded:
		return false
	
	if ceiling_raycast.is_colliding():
		var col : Node3D = ceiling_raycast.get_collider() as Node3D
		if col.is_in_group("enemy"): # Stuck under another slime
			return false
	
	if ground_raycast.is_colliding():
		var col : Node3D = ground_raycast.get_collider() as Node3D
		if col.is_in_group("enemy"): # Stuck on another slime
			return false
	rpc("start_jump", global_position, jump_end, NetworkTimeSynchronizer.get_time())
	return true

@rpc("any_peer", "call_local", "reliable")
func start_jump(initial_pos : Vector3, target_pos : Vector3, time : float) -> void:
	collider.disabled = true
	is_jumping = true
	jump_timer = NetworkTimeSynchronizer.get_time() - time
	jump_start = initial_pos
	jump_end = target_pos
	ground_raycast.collide_with_areas = false
	process_jump(0)
	play_animation("jump")

func process_jump(delta : float) -> void:
	jump_timer += delta
	var jump_ratio : float = clamp(jump_timer / JUMP_LENGTH, 0, 1)
	var current_pos : Vector3 = jump_start.lerp(jump_end, jump_ratio)
	current_pos.y += JUMP_HEIGHT * sin(jump_ratio * PI)
	global_position = current_pos
	
	if is_equal_approx(jump_ratio, 1) && ground_raycast.is_colliding():
		global_position = ground_raycast.get_collision_point()
		on_majin_grounded()

func _on_area_entered(area: Area3D) -> void:
	if !is_multiplayer_authority():
		return
	
	if area.is_in_group("wall"):
		is_jump_queued = true
		jump_end = area.global_position

func _on_area_exited(area: Area3D) -> void:
	if !is_multiplayer_authority():
		return
	
	if area.is_in_group("wall"):
		is_jump_queued = false

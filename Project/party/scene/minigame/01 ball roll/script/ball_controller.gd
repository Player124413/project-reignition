### The ball controller for the Ball Rolling minigame.
extends PartyGameCharacterSpawner

@export var max_speed : float = 20.0
@export var turn_speed : float = 20.0
@export var acceleration : float = 20.0
@export var decceleration : float = 20.0

@export var character_body : CharacterBody3D
@export var character_rotation : Node3D
@export var character_raycast : RayCast3D
@export var ball_mesh : MeshInstance3D
@export var ball_materials : Array[Material]
var is_minigame_complete : bool

## The last input recorded by this player.
@export var movement_input : Vector2
## The player's move speed.
@export var move_speed : float
## The angle this player is moving/facing.
@export var movement_angle : float
var velocity : Vector3
var floor_angle : float
## Amount of gravity to apply to the ball.
const GRAVITY : float = 30.0
## Used to offset the player's model from the ball.
const BALL_RADIUS : float = 12.0
## Time that updates cpu player's inputs.
var cpu_timer : float
## Base amount to update the cpu's inputs.
const CPU_BASE_INPUT_INTERVAL : float = 3.0 / 2.0

func on_spawn_finished() -> void:
	ball_mesh.material_override = ball_materials[player_index]
	character_animator.play_animation(get_anim_prefix() + "wait")
	character_animator.animator.set_blend_time(get_anim_prefix() + "wait", get_anim_prefix() + "push", 0.5)
	character_animator.animator.set_blend_time(get_anim_prefix() + "push", get_anim_prefix() + "wait", 0.5)
	movement_angle = global_rotation.y
	
	MinigameManager.instance.gameplay_finished.connect(Callable.create(self, "on_gameplay_finished"))

func on_gameplay_finished() -> void:
	ball_mesh.visible = false
	is_minigame_complete = true

func _physics_process(_delta: float) -> void:
	if is_minigame_complete:
		return
	
	if is_multiplayer_authority(): # Update inputs
		movement_input = calculate_cpu_input() if is_cpu() else get_input_axis()
	
	process_move_speed()
	process_turning()
	apply_movement()
	process_animation()

func apply_movement() -> void:
	velocity = Vector3.BACK.rotated(Vector3.UP, movement_angle) * move_speed
	if !velocity.is_zero_approx():
		velocity += Vector3.DOWN * GRAVITY
	character_body.velocity = velocity
	character_body.move_and_slide()
	move_speed = character_body.velocity.length()

func process_move_speed() -> void:
	var target : float = 0
	var delta : float = decceleration
	if !movement_input.is_equal_approx(Vector2.ZERO):
		target = max_speed
		delta = acceleration
	move_speed = move_toward(move_speed, target, delta * get_physics_process_delta_time())

func process_animation() -> void:
	character_rotation.global_rotation = Vector3.UP * movement_angle
	if character_raycast.is_colliding():
		# Snap to ground
		var target_position : Vector3 = character_raycast.get_collision_point()
		var distance_vector : Vector3 = target_position - character_rotation.global_position
		distance_vector.y = 0
		distance_vector = distance_vector.normalized()
		var amount : float = (target_position.y + BALL_RADIUS) - character_body.global_position.y
		amount = min(amount, 0)
		var target_angle : float = character_raycast.get_collision_normal().signed_angle_to(Vector3.UP, character_rotation.global_basis.x)
		target_angle = max(target_angle, 0)
		floor_angle = lerp(floor_angle, target_angle, 0.1)
		if floor_angle < 0:
			target_position.y += sin(floor_angle) * BALL_RADIUS
		target_position += distance_vector * amount
		character_animator.global_position = target_position
	
	if is_zero_approx(move_speed):
		character_animator.play_animation(get_anim_prefix() + "wait")
	else:
		character_animator.play_animation(get_anim_prefix() + "push")
	
	if !character_body.velocity.is_zero_approx():
		var rotation_speed : float = move_speed * 0.1 * get_physics_process_delta_time()
		ball_mesh.global_rotate(character_body.velocity.rotated(Vector3.UP, PI * 0.5).normalized(), rotation_speed)

func process_turning() -> void:
	if movement_input.is_zero_approx():
		return
	
	var target_angle : float = Vector2.UP.angle_to(movement_input);
	movement_angle = rotate_toward(movement_angle, target_angle, turn_speed * get_physics_process_delta_time())

const HARD_CPU_RING_RADIUS : int = 15
func calculate_cpu_input() -> Vector2:
	if !is_zero_approx(cpu_timer):
		cpu_timer = move_toward(cpu_timer, 0, get_physics_process_delta_time())
		return movement_input # No change
	
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	cpu_timer = CPU_BASE_INPUT_INTERVAL / difficulty
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		# Stay in the central area, but avoid the exact center so we don't get stuck on other players
		var input : Vector2 = Vector2(character_body.global_position.x, -character_body.global_position.z)
		var target_position = input.normalized().rotated(randf() * PI * 0.2) * randf() * HARD_CPU_RING_RADIUS
		return (target_position - input).normalized()
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EXTREME:
		# Stay in the center at all costs, even if it means bullying other players
		var input : Vector2 = Vector2(character_body.global_position.x, -character_body.global_position.z)
		input = input.rotated(PI * 0.5 * (0.5 - randf())) # Prevent CPU from being too robotic
		return -input.normalized()
	
	return Vector2.UP.rotated(randf() * TAU) # Just choose a random direction

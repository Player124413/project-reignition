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

## The player's move speed.
var move_speed : float
## The angle this player is moving/facing.
var movement_angle : float
var velocity : Vector3
var floor_angle : float
const BALL_RADIUS : float = 12.0

func on_spawn_finished() -> void:
	ball_mesh.material_override = ball_materials[player_index]
	character_animator.play_animation(get_anim_prefix() + "wait")
	character_animator.animator.set_blend_time(get_anim_prefix() + "wait", get_anim_prefix() + "push", 0.5)
	character_animator.animator.set_blend_time(get_anim_prefix() + "push", get_anim_prefix() + "wait", 0.5)
	movement_angle = global_rotation.y

func _physics_process(_delta: float) -> void:
	if !is_multiplayer_authority():
		return
	
	if is_cpu():
		# TODO Calculate CPU Inputs
		return
	
	var input : Vector2 = get_input_axis()
	process_move_speed(input)
	process_turning(input)
	apply_movement()
	process_animation()

func apply_movement() -> void:
	velocity = Vector3.BACK.rotated(Vector3.UP, movement_angle) * move_speed
	character_body.velocity = velocity
	character_body.move_and_slide()
	move_speed = character_body.velocity.length()

func process_move_speed(input : Vector2) -> void:
	var target : float = 0
	var delta : float = decceleration
	if !input.is_equal_approx(Vector2.ZERO):
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
	
	if !velocity.is_zero_approx():
		var rotation_speed : float = move_speed * 0.1 * get_physics_process_delta_time()
		ball_mesh.global_rotate(velocity.rotated(Vector3.UP, PI * 0.5).normalized(), rotation_speed)

func process_turning(input : Vector2) -> void:
	if input.is_zero_approx():
		return
	
	var target_angle : float = Vector2.UP.angle_to(input);
	movement_angle = rotate_toward(movement_angle, target_angle, turn_speed * get_physics_process_delta_time())

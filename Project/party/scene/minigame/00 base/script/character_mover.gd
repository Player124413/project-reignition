### Base implemention for characters that need to run around in a top-down perspective.
class_name PartyGameCharacterMover extends PartyGameCharacterSpawner

@export_group("Components")
@export var rollback_timer : RollbackTimer
@export var character_body : CharacterBody3D

@export_group("Movement Settings")
@export var allow_braking : bool = true
@export var allow_instant_turn : bool = true
@export var enable_gravity : bool
@export var run_speed : float = 50.0
@export var walk_speed : float = 30.0
@export var turn_speed : float = 15.0
@export var in_place_turn_speed : float = 15.0
@export var friction : float = 120.0
@export var traction : float = 100.0
@export var brake_friction : float = 200.0
## How far the controller needs to be pressed to perform a run.
const RUN_LENGTH : float = 0.5
const GRAVITY : float = 40.0
const MAX_GRAVITY : float = -50.0

## The current speed we're moving at.
var _move_speed : float
## The current angle we're moving at.
var _move_angle : float
## The current speed we're falling at.
var _vertical_speed : float
## The current input being processed.
var _input : Vector2
## What input angle should be counted as "braking."
const BRAKE_ANGLE : float = PI * 0.8

## Tracks whether the player is braking or not.
var _is_braking : bool = false
## Tracks whether the player is walking or not.
var _is_walking : bool = false
## Tracks whether the player is turning from a stop.
var _is_start_turning : bool = false

func on_spawn_finished() -> void:
	_move_angle = rotation.y
	global_rotation = Vector3.ZERO
	process_animation()
	rollback_timer.register_target(self)

func deactivate() -> void:
	super()
	_input = Vector2.ZERO
	_move_speed = 0
	process_animation()

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		process_inputs()
	
	process_movement_tick()
	if is_multiplayer_authority():
		process_rollback()

#####################
### ROLLBACK CODE ###
#####################
const RB_POS : int = 0
const RB_SPD : int = 1
const RB_ANGLE : int = 2
const RB_INPUT : int = 3
func on_rollback_applied(rb_params : Array) -> void:
	character_body.global_position = rb_params[RB_POS]
	_move_speed = rb_params[RB_SPD].x
	_vertical_speed = rb_params[RB_SPD].y
	_move_angle = rb_params[RB_ANGLE]
	_input = rb_params[RB_INPUT]

func process_rollback() -> void:
	rollback_timer.set_param(RB_POS, character_body.global_position)
	rollback_timer.set_param(RB_SPD, Vector2(_move_speed, _vertical_speed))
	rollback_timer.set_param(RB_ANGLE, _move_angle)
	rollback_timer.set_param(RB_INPUT, _input)
	rollback_timer.process_rollback()

func process_inputs() -> void:
	if _is_gameplay_finished:
		_input = Vector2.ZERO
		return
	
	if !is_cpu():
		_input = get_input_axis()
	elif player_index != -1:
		_input = get_cpu_input()

func process_movement_tick() -> void:
	if !character_body.get_world_3d().space.is_valid():
		return
	
	var target_angle : float = _move_angle if _input.is_zero_approx() else Vector2.UP.angle_to(_input)
	_is_walking = _input.length() < RUN_LENGTH
	if allow_braking:
		_is_braking = !is_zero_approx(_move_speed) && abs(angle_difference(_move_angle, target_angle)) > BRAKE_ANGLE
	
	process_rotation(target_angle)
	process_speed()
	process_animation()
	apply_movement()

## Updates the character's position based on movespeed and moveangle.
func apply_movement() -> void:
	var velocity : Vector3 = Vector3.MODEL_FRONT.rotated(Vector3.UP, _move_angle) * _move_speed
	velocity += Vector3.UP * _vertical_speed
	character_body.velocity = velocity
	character_body.move_and_slide()
	push_other_characters(velocity)

## Handle pushing other characters.
func push_other_characters(velocity : Vector3) -> void:
	var characters : Array[CharacterBody3D]
	for i in character_body.get_slide_collision_count():
		var collision : KinematicCollision3D = character_body.get_slide_collision(i)
		var collider : Object = collision.get_collider()
		if collider is CharacterBody3D:
			characters.append(collider as CharacterBody3D)
	
	if characters.size() == 0:
		return
	
	var push_strength : float = 1.0 / (characters.size() + 1)
	for character in characters:
		character.velocity = velocity * push_strength
		character.move_and_slide()

## Updates the characters rotation.
func process_rotation(target_angle : float) -> void:
	if _is_braking:
		return
	
	if is_zero_approx(_move_speed) && allow_instant_turn:
		_move_angle = target_angle
	else:
		var turn_spd : float = in_place_turn_speed if is_zero_approx(_move_speed) else turn_speed
		_move_angle = rotate_toward(_move_angle, target_angle, turn_spd * get_physics_process_delta_time())
		var angle_dif : float = angle_difference(_move_angle, target_angle)
		_is_start_turning = !allow_instant_turn && is_zero_approx(_move_speed) && !is_zero_approx(angle_dif)

## Updates the character's movement speed.
func process_speed() -> void:
	var target_speed : float = 0
	var target_delta : float
	if _is_braking:
		target_delta = brake_friction
	elif _input.is_zero_approx() || _is_start_turning:
		target_delta = friction
	else:
		target_speed = walk_speed if _is_walking else run_speed 
		target_delta = traction if target_speed > _move_speed else friction
	_move_speed = move_toward(_move_speed, target_speed, target_delta * get_physics_process_delta_time())
	
	if enable_gravity:
		apply_gravity()

func apply_gravity() -> void:
	if character_body.is_on_floor():
		_vertical_speed = 0 # Reset (don't accumulate on the ground)
	_vertical_speed = move_toward(_vertical_speed, MAX_GRAVITY, GRAVITY * get_physics_process_delta_time())

## Updates the characters animations.
func process_animation() -> void:
	var target_animation : String = get_target_animation()
	if target_animation.is_empty():
		return
	
	var target_speed : float = get_target_animation_speed()
	
	if character_animator.has_animation(get_anim_prefix() + target_animation):
		target_animation = get_anim_prefix() + target_animation
	else:
		target_animation = "%s/%s" % [MinigameManager.COMMON_ANIMATION_LIBRARY_PREFIX, target_animation]
	
	character_animator.set_speed(target_speed)
	character_animator.play_animation(target_animation, false, 0.1)
	apply_movement_rotation()

var cpu_interval_timer : float
func get_cpu_input() -> Vector2:
	cpu_interval_timer = move_toward(cpu_interval_timer, 0.0, get_physics_process_delta_time())
	if is_zero_approx(cpu_interval_timer):
		cpu_interval_timer = get_cpu_interval()
		return calculate_cpu_input()
	return _input

const CPU_VARIANCE : float = 0.1
## Override this function to change how often the cpu updates their inputs.
func get_cpu_interval() -> float:
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EXTREME:
		return 0.0
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		return 0.1 - randf() * CPU_VARIANCE
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		return 0.2 - randf() * CPU_VARIANCE
	
	return 0.4 - randf() * CPU_VARIANCE

## Override this function to calculate the cpu inputs.
func calculate_cpu_input() -> Vector2:
	return Vector2.ZERO

## Calculates the input needed to reach a particular position.
func cpu_chase_position(pos : Vector3) -> Vector2:
	var difference : Vector3 = pos - character_body.global_position
	var input : Vector2 = Vector2(difference.x, -difference.z)
	return input.limit_length()

func apply_movement_rotation() -> void:
	character_body.rotation = Vector3.UP * _move_angle

## Returns the target animation that should be playing at this time.
func get_target_animation() -> StringName:
	if _is_braking:
		return "brake"
	
	if is_zero_approx(_move_speed):
		return "wait"
	
	if _input.is_zero_approx(): # Don't update animation when slowing down
		return ""
	
	return "walk" if _is_walking else "run"

func get_target_animation_speed() -> float:
	return 1.0

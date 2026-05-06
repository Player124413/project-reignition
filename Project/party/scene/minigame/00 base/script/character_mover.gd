### Base implemention for characters that need to run around in a top-down perspective.
class_name PartyGameCharacterMover extends PartyGameCharacterSpawner

@export_group("Components")
@export var rollback_timer : RollbackTimer
@export var character_body : CharacterBody3D

@export_group("Movement Settings")
@export var allow_braking : bool = true
@export var run_speed : float = 50.0
@export var walk_speed : float = 20.0
@export var turn_speed : float = 15.0
@export var friction : float = 120.0
@export var traction : float = 100.0
@export var brake_friction : float = 200.0
## How far the controller needs to be pressed to perform a run.
const RUN_LENGTH : float = 0.5

## The current speed we're moving at.
var _move_speed : float
## The current angle we're moving at.
var _move_angle : float
## The current input being processed.
var _input : Vector2
## What input angle should be counted as "braking."
const BRAKE_ANGLE : float = PI * 0.8

## Tracks whether the player is braking or not.
var _is_braking : bool = false
## Tracks whether the player is walking or not.
var _is_walking : bool = false

func on_spawn_finished() -> void:
	_move_angle = rotation.y
	global_rotation = Vector3.ZERO
	process_animation()
	rollback_timer.register_target(self)

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
	_move_speed = rb_params[RB_SPD]
	_move_angle = rb_params[RB_ANGLE]
	_input = rb_params[RB_INPUT]

func process_rollback() -> void:
	rollback_timer.set_param(RB_POS, character_body.global_position)
	rollback_timer.set_param(RB_SPD, _move_speed)
	rollback_timer.set_param(RB_ANGLE, _move_angle)
	rollback_timer.set_param(RB_INPUT, _input)
	rollback_timer.process_rollback()

func process_inputs() -> void:
	if !is_cpu():
		_input = get_input_axis() # TODO Allow CPU inputs

func process_movement_tick() -> void:
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
	character_body.velocity = velocity
	character_body.move_and_slide()

## Updates the characters rotation.
func process_rotation(target_angle : float) -> void:
	if _is_braking:
		return
	
	if is_zero_approx(_move_speed):
		_move_angle = target_angle
	else:
		_move_angle = rotate_toward(_move_angle, target_angle, turn_speed * get_physics_process_delta_time())

## Updates the character's movement speed.
func process_speed() -> void:
	var target_speed : float = 0
	var target_delta : float
	if _is_braking:
		target_delta = brake_friction
	elif _input.is_zero_approx():
		target_delta = friction
	else:
		target_speed = walk_speed if _is_walking else run_speed 
		target_delta = traction if target_speed > _move_speed else friction
	_move_speed = move_toward(_move_speed, target_speed, target_delta * get_physics_process_delta_time())

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

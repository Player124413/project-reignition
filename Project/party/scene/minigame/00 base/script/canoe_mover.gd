### Base implemention for character controllers that are based on canoeing.
class_name PartyGameCanoeMover extends PartyGameCharacterSpawner

@export_group("Components")
@export var rollback_timer : RollbackTimer
@export var character_body : CharacterBody3D
@export var oar_attachment : BoneAttachment3D

@export_group("Movement Settings")
## Should turning be disabled? If so, the canoe will simply strafe side-to-side.
@export var disable_turning : bool
@export var top_speed : float = 60.0
@export var paddle_speed : float = 30.0
@export var friction : float = 10.0
@export var turn_speed : float = 1.5
@export var turn_friction : float = 1.4
const GRAVITY : float = 40.0
const MAX_GRAVITY : float = -50.0

## The current speed we're moving at.
var _move_speed : float
## The current speed we're rotating.
var _rot_speed : float
## The current angle we're moving at.
var _move_angle : float
## The current speed we're falling at.
var _vertical_speed : float
## Tracks whether the player is in the middle of a paddle.
var _is_paddle_active : bool
## The last direction that was paddled.
var _paddle_dir : float = -1
const TURNING_DISABLED_CLAMP_AMOUNT : float = PI * 0.2

func on_spawn_finished() -> void:
	super()
	oar_attachment.reparent(character_animator.skeleton)
	_move_angle = global_rotation.y
	global_rotation = Vector3.ZERO
	apply_movement_rotation()
	character_animator.play_animation("%s/wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX)
	if character_animator.data.model_size == PartyCharacterResource.MODEL_SIZES.SMALL:
		character_animator.position = Vector3.UP * 1
	elif character_animator.data.model_size == PartyCharacterResource.MODEL_SIZES.EXTRA_SMALL:
		character_animator.position = Vector3.UP * 1.5
	rollback_timer.register_target(self)

func deactivate() -> void:
	super()
	character_animator.play_animation("%s/wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, false, 0.2)
	_move_speed = 0

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
func on_rollback_applied(rb_params : Array) -> void:
	character_body.global_position = rb_params[RB_POS]
	_move_speed = rb_params[RB_SPD]
	_move_angle = rb_params[RB_ANGLE]

func process_rollback() -> void:
	rollback_timer.set_param(RB_POS, character_body.global_position)
	rollback_timer.set_param(RB_SPD, _move_speed)
	rollback_timer.set_param(RB_ANGLE, _move_angle)
	rollback_timer.process_rollback()

func process_inputs() -> void:
	if _is_gameplay_finished:
		return
	
	if !is_cpu():
		if !_is_paddle_active && Input.is_action_pressed("button_primary%s" % get_input_suffix()):
			request_paddle()
	elif player_index != -1:
		pass # TODO Check for CPU paddles.
		#_input = get_cpu_input()

func process_movement_tick() -> void:
	process_rotation()
	process_speed()
	apply_movement_rotation()
	apply_movement()

const PADDLE_EVENT : int = 1
const PADDLE_FINISHED_EVENT : int = 0
func process_animation_event(info : int) -> void:
	if info == PADDLE_EVENT:
		apply_paddle()
	elif info == PADDLE_FINISHED_EVENT:
		_is_paddle_active = false
		character_animator.play_animation("%s/wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, false, 0.1)

func request_paddle() -> void:
	var input : float = get_horizontal_input()
	if is_zero_approx(input):
		_paddle_dir *= -1 # Alternate paddle direction (i.e. move forward)
	else:
		_paddle_dir = sign(input)
	rpc("start_paddle", _paddle_dir, NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func start_paddle(dir : int, tick : float) -> void:
	_paddle_dir = dir
	_is_paddle_active = true
	var target_animation : String = "left" if dir > 0 else "right"
	character_animator.play_minigame_animation("%s/%s" % [MinigameManager.ANIMATION_LIBRARY_PREFIX, target_animation], 0.1, 1.0, 0.0, tick)

func apply_paddle() -> void:
	_move_speed = min(_move_speed + paddle_speed, top_speed)
	_rot_speed = turn_speed * -_paddle_dir

## Updates the character's position based on movespeed and moveangle.
func apply_movement() -> void:
	if !is_inside_tree() || get_world_3d().direct_space_state == null:
		return
	
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
func process_rotation() -> void:
	var target_angle : float = _move_angle + _rot_speed * get_physics_process_delta_time()
	if disable_turning:
		target_angle = clamp(target_angle, -TURNING_DISABLED_CLAMP_AMOUNT, TURNING_DISABLED_CLAMP_AMOUNT)
	_rot_speed = move_toward(_rot_speed, 0, turn_friction * get_physics_process_delta_time())
	_move_angle = fmod(target_angle, TAU)

## Updates the character's movement speed.
func process_speed() -> void:
	_move_speed = move_toward(_move_speed, 0, friction * get_physics_process_delta_time())
	apply_gravity()

func apply_gravity() -> void:
	if character_body.is_on_floor():
		_vertical_speed = 0 # Reset (don't accumulate on the ground)
	_vertical_speed = move_toward(_vertical_speed, MAX_GRAVITY, GRAVITY * get_physics_process_delta_time())

var cpu_interval_timer : float
func get_cpu_input() -> float:
	cpu_interval_timer = move_toward(cpu_interval_timer, 0.0, get_physics_process_delta_time())
	if is_zero_approx(cpu_interval_timer):
		cpu_interval_timer = get_cpu_interval()
		return calculate_cpu_input()
	return 0.0

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
func calculate_cpu_input() -> float:
	return 0

func apply_movement_rotation() -> void:
	if disable_turning:
		return
	character_body.rotation = Vector3.UP * _move_angle

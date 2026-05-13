extends PartyGameCharacterSpawner

@export var rollback_timer : RollbackTimer
@export var hand_attachment : BoneAttachment3D
@export var character_body : CharacterBody3D
@export var ascend_speed : float = 30.0
@export var descend_speed : float = 15.0
@export var drop_speed : float = 20.0
@export var drop_friction : float = 10.0
@export var move_speed : float = 40.0
@export var acceleration : float = 100.0
var _current_speed : Vector2
var _input : float
var is_dropping : bool

var current_cloud : Area3D
var cloud_position_offset : Vector3

const ROTATION_AMOUNT : float = PI * 0.1
const MAX_HORIZONTAL : float = 40.0
const MAX_VERTICAL : float = 20.0

## List of animations to use.
const ANIM_LIST : PackedStringArray = [
	"fall",
	"left",
	"right",
	"stuck",
	"shake",
]

var shake_strength : float
var shake_anim_timer : float
const SHAKE_ANIM_INPUT_LENGTH : float = 0.4
const SHAKE_STRENGTH_INTERVAL : float = 0.1
const DIRECTION_BLEND : StringName = "parameters/direction-blend/blend_amount"
const SHAKE_TRANSITION : StringName = "parameters/shake-transition/transition_request"
const STUCK_TRANSITION : StringName = "parameters/stuck-transition/transition_request"

func on_spawn_finished() -> void:
	rollback_timer.register_target(self)
	initialize_animation_tree(get_anim_prefix(), ANIM_LIST)
	hand_attachment.reparent(character_animator.skeleton)
	MinigameManager.instance.minigame_finished.connect(Callable(self, "on_minigame_finished"))

func on_minigame_finished() -> void:
	hand_attachment.visible = false

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority() && !_is_gameplay_finished:
		if is_cpu():
			_input = get_cpu_input()
		else:
			_input = get_input_axis().x
	
	process_cloud()
	process_movement_tick()
	process_animation()
	process_sfx_timer()
	
	if is_multiplayer_authority():
		process_rollback()

#####################
### ROLLBACK CODE ###
#####################
const RB_POS : int = 0
const RB_SPD : int = 1
const RB_INPUT : int = 2
const RB_SHAKE : int = 3
func on_rollback_applied(rb_params : Array) -> void:
	character_body.global_position = rb_params[RB_POS]
	_current_speed = rb_params[RB_SPD]
	_input = rb_params[RB_INPUT]
	shake_anim_timer = rb_params[RB_SHAKE]

func process_rollback() -> void:
	rollback_timer.set_param(RB_POS, character_body.global_position)
	rollback_timer.set_param(RB_SPD, _current_speed)
	rollback_timer.set_param(RB_INPUT, _input)
	rollback_timer.set_param(RB_SHAKE, shake_anim_timer)
	rollback_timer.process_rollback()

################
### CPU CODE ###
################
var _cpu_preferred_side : int = -1
## The position coins are spawned in.
const IDEAL_COIN_DISTANCE : float = 20
var _cpu_input_timer : float
const CPU_INPUT_INTERVAL : float = 0.8
const CPU_SHORT_INPUT_INTERVAL : float = 0.4
const CPU_INPUT_INTERVAL_VARIANCE : float = 0.4

var _cpu_shake_timer : float
## How often the cpu should shake.
const CPU_SHAKE_INTERVAL : float = 0.2
const NORMAL_SHAKE_CHANCE : float = 0.5
const HARD_SHAKE_CHANCE : float = 0.75
func get_cpu_input() -> float:
	_cpu_input_timer = move_toward(_cpu_input_timer, 0, get_physics_process_delta_time())
	if !is_zero_approx(_cpu_input_timer): # Holding
		return _input
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY: # Choose a random direction
		_cpu_input_timer = CPU_INPUT_INTERVAL - randf() * CPU_INPUT_INTERVAL_VARIANCE
		if randf() < 0.25:
			return 0
		return 1.0 - randf() * 2.0
	
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL: # Choose a random direction
		_cpu_input_timer = CPU_INPUT_INTERVAL - randf() * CPU_INPUT_INTERVAL_VARIANCE
		return 1.0 - randf() * 2.0
	
	_cpu_input_timer = CPU_SHORT_INPUT_INTERVAL - randf() * CPU_INPUT_INTERVAL_VARIANCE
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD: # Choose a random direction
		return sign(_cpu_preferred_side * IDEAL_COIN_DISTANCE - character_body.global_position.x)
	
	_cpu_input_timer *= 0.5
	if randf() < 0.2: # Try to avoid getting stuck against other players
		return 0
	return sign(_cpu_preferred_side * IDEAL_COIN_DISTANCE - character_body.global_position.x)

func is_cpu_shaking() -> bool:
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY: # Easy CPUs don't know how to shake
		return false
	
	_cpu_shake_timer = move_toward(_cpu_shake_timer, 0, get_physics_process_delta_time())
	if !is_zero_approx(_cpu_shake_timer):
		return false
	_cpu_shake_timer = CPU_SHAKE_INTERVAL
	
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EXTREME: # Extreme cpu mashes out
		return true
	
	var is_shaking : bool
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		is_shaking = randf() < NORMAL_SHAKE_CHANCE
	else:
		is_shaking = randf() < HARD_SHAKE_CHANCE
	return is_shaking

func _on_cpu_trigger_area_exited(area: Area3D) -> void:
	_cpu_preferred_side = -sign(area.global_position.x)

func process_cloud() -> void:
	if current_cloud == null:
		return
	
	shake_anim_timer = move_toward(shake_anim_timer, 0, get_physics_process_delta_time())
	animation_tree.set(SHAKE_TRANSITION, "disabled" if is_zero_approx(shake_anim_timer) else "enabled")
	
	if is_cloud_exploded():
		explode_cloud()
		return
	
	if !is_multiplayer_authority():
		return
	
	if is_cpu():
		if is_cpu_shaking():
			perform_shake()
	elif Input.is_action_just_pressed("button_primary" + get_input_suffix()):
		perform_shake()

func perform_shake() -> void:
		shake_anim_timer = SHAKE_ANIM_INPUT_LENGTH
		shake_strength += SHAKE_STRENGTH_INTERVAL
		if shake_strength > 1.0:
			explode_cloud()

func explode_cloud() -> void:
	shake_strength = 0
	shake_anim_timer = 0
	current_cloud.rpc("explode")
	current_cloud = null
	animation_tree.set(SHAKE_TRANSITION, "disabled")
	animation_tree.set(STUCK_TRANSITION, "disabled")

func process_movement_tick() -> void:
	if current_cloud != null:
		_current_speed = Vector2.ZERO
		character_body.global_position = current_cloud.global_position + cloud_position_offset
		clamp_position()
		return
	
	var target_speed : float = _input * move_speed
	_current_speed.x = move_toward(_current_speed.x, target_speed, acceleration * get_physics_process_delta_time())
	if !is_zero_approx(target_speed):
		is_dropping = false
	
	if is_equal_approx(character_body.global_position.y, MAX_VERTICAL):
		_current_speed.y = -drop_speed
		is_dropping = true
	elif is_zero_approx(target_speed):
		if is_dropping:
			_current_speed.y = move_toward(_current_speed.y, ascend_speed, drop_friction * get_physics_process_delta_time())
		else:
			_current_speed.y = move_toward(_current_speed.y, ascend_speed, acceleration * get_physics_process_delta_time())
	elif is_equal_approx(character_body.global_position.y, -MAX_VERTICAL):
		_current_speed.y = move_toward(_current_speed.y, 0, acceleration * get_physics_process_delta_time())
	else:
		_current_speed.y = move_toward(_current_speed.y, -descend_speed, acceleration * get_physics_process_delta_time())
	
	character_body.velocity = Vector3.RIGHT * _current_speed.x + Vector3.UP * _current_speed.y
	character_body.move_and_slide()
	clamp_position()

func process_animation() -> void:
	var movement_ratio : float = _current_speed.x / move_speed
	var anim_factor : float = movement_ratio
	if abs(anim_factor) > 0.5:
		anim_factor = smoothstep(0, 1, abs(movement_ratio)) * sign(movement_ratio)
	character_animator.global_rotation = Vector3.FORWARD * anim_factor * ROTATION_AMOUNT
	animation_tree.set(DIRECTION_BLEND, movement_ratio)

func is_cloud_exploded() -> bool:
	return current_cloud.is_exploded || is_equal_approx(character_body.global_position.y, MAX_VERTICAL)

func clamp_position() -> void:
	character_body.global_position.x = clamp(character_body.global_position.x, -MAX_HORIZONTAL, MAX_HORIZONTAL)
	character_body.global_position.y = clamp(character_body.global_position.y, -MAX_VERTICAL, MAX_VERTICAL)
	character_body.global_position.z = 0

func _on_trigger_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		# Hit a cloud
		current_cloud = area
		current_cloud.catch()
		cloud_position_offset = character_body.global_position - current_cloud.global_position
		animation_tree.set(STUCK_TRANSITION, "enabled")
		return
	
	# Grabbed a coin
	area.rpc("request_collect", NetworkTimeSynchronizer.get_time(), player_index)

@export var drift_sfx : AudioStreamPlayer
var _sfx_timer : float
const SFX_TIMER_INTERVAL = 0.5
func process_sfx_timer() -> void:
	_sfx_timer = move_toward(_sfx_timer, 0, get_physics_process_delta_time())
	if !is_zero_approx(_sfx_timer) && !_is_gameplay_finished:
		return
	
	if !is_zero_approx(_current_speed.x):
		drift_sfx.play()
		_sfx_timer = SFX_TIMER_INTERVAL

extends PartyGameCharacterSpawner

@export var hand_attachment : BoneAttachment3D
@export var character_body : CharacterBody3D
@export var ascend_speed : float = 30.0
@export var descend_speed : float = 15.0
@export var drop_speed : float = 20.0
@export var drop_friction : float = 10.0
@export var move_speed : float = 40.0
@export var acceleration : float = 100.0
var _current_speed : Vector2
var _input : Vector2
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
	super()
	initialize_animation_tree(get_anim_prefix(), ANIM_LIST)
	hand_attachment.reparent(character_animator.skeleton)
	MinigameManager.instance.minigame_finished.connect(Callable(self, "on_minigame_finished"))

func on_minigame_finished() -> void:
	hand_attachment.visible = false

func _physics_process(_delta: float) -> void:
	if is_cpu():
		pass
	else:
		_input = get_input_axis()
	
	process_cloud()
	process_movement_tick()
	process_animation()

func process_cloud() -> void:
	if current_cloud == null:
		return
	
	shake_anim_timer = move_toward(shake_anim_timer, 0, get_physics_process_delta_time())
	if is_zero_approx(shake_anim_timer):
		animation_tree.set(SHAKE_TRANSITION, "disabled")
	
	if is_cloud_exploded():
		explode_cloud()
	elif !is_cpu() && Input.is_action_just_pressed("button_primary" + get_input_suffix()):
		shake_anim_timer = SHAKE_ANIM_INPUT_LENGTH
		animation_tree.set(SHAKE_TRANSITION, "enabled")
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
	
	var target_speed : float = _input.x * move_speed
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
		cloud_position_offset = character_body.global_position - current_cloud.global_position
		animation_tree.set(STUCK_TRANSITION, "enabled")
		print("STUCK TRIGGER ACTIVATED")
		return
	
	# Grabbed a coin
	area.rpc("request_collect", NetworkTimeSynchronizer.get_time(), player_index)

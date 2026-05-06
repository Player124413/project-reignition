### The player controller for the parasol ball minigame.
extends PartyGameCharacterMover

@export var hand_attachment : BoneAttachment3D
@export var aim_speed : float = 8.0
@export var basket : Node3D
const HIT_HEIGHT : int = 30
const HIT_DIRECTION_INFLUENCE : float = PI * 0.2
var ball_targets : Array[Area3D]

func on_spawn_finished() -> void:
	super()
	hand_attachment.reparent(character_animator.skeleton)
	MinigameManager.instance.minigame_finished.connect(Callable(self, "on_minigame_finished"))

func on_minigame_finished() -> void:
	hand_attachment.visible = false

## The swing direction. -1 for left, 1 for right, 0 for not swinging.
var swing_state : SWING_STATE
enum SWING_STATE {
	IDLE,
	AIMING,
	RECOVERY
}

func process_rotation(target_angle : float) -> void:
	if swing_state == SWING_STATE.IDLE:
		super(target_angle)
	elif swing_state == SWING_STATE.AIMING:
		_move_angle = rotate_toward(_move_angle, target_angle, aim_speed * get_physics_process_delta_time())

func process_speed() -> void:
	if swing_state == SWING_STATE.IDLE:
		super()
		return
	
	_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())

const ANIM_SHOT_FINISH : int = 0
const ANIM_SHOT_LEFT : int = 1
const ANIM_SHOT_RIGHT : int = 2
const ANIM_STEP_LEFT : int = 10
const ANIM_STEP_RIGHT : int = 11
func process_animation() -> void:
	if swing_state == SWING_STATE.IDLE:
		super()
	elif swing_state == SWING_STATE.AIMING:
		apply_movement_rotation()

func process_animation_event(event : int) -> void:
	if event == ANIM_SHOT_FINISH: # Finished swinging
		swing_state = SWING_STATE.IDLE
	elif event == ANIM_SHOT_LEFT || event == ANIM_SHOT_RIGHT: # Hit balls
		hit_balls(-1 if event == ANIM_SHOT_LEFT else 1)

func hit_balls(dir : int) -> void:
	# TODO Launch all balls in range
	swing_state = SWING_STATE.RECOVERY
	for ball in ball_targets:
		var target_position : Vector3 = calculate_hit_position(dir, ball.global_position)
		ball.rpc("hit_ball", NetworkTimeSynchronizer.get_time(), player_index, ball.global_position, target_position)

func calculate_hit_position(dir : int, pos : Vector3) -> Vector3:
	pos.y = HIT_HEIGHT
	pos.z = basket.global_position.z
	var offset_length : float = global_position.z - pos.z
	if abs(_move_angle) < PI * 0.25: # Allow trolls to hit balls into the sea
		pos.z += offset_length * 2
	var aim_angle : float = _move_angle
	aim_angle += dir * HIT_DIRECTION_INFLUENCE
	pos.x += sin(aim_angle) * offset_length # Rotate by movement angle
	return pos

func process_inputs() -> void:
	if !is_cpu():
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			start_swing(1)
		elif Input.is_action_just_pressed("button_secondary%s" % get_input_suffix()):
			start_swing(-1)
	if swing_state != SWING_STATE.RECOVERY:
		super()

func start_swing(dir : int) -> void:
	swing_state = SWING_STATE.AIMING
	if dir == 1:
		character_animator.rpc("play_minigame_animation", get_anim_prefix() + "shot-right")
	else:
		character_animator.rpc("play_minigame_animation", get_anim_prefix() + "shot-left")

func _on_hit_trigger_area_entered(area: Area3D) -> void:
	if !area.is_in_group("enemy"):
		return
	
	ball_targets.append(area)
	if player_index == -1:
		start_swing(-1)

func _on_hit_trigger_area_exited(area: Area3D) -> void:
	if !area.is_in_group("enemy"):
		return
	var index : int = ball_targets.find(area)
	if index != -1:
		ball_targets.remove_at(index)

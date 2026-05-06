### The player controller for the parasol ball minigame.
extends PartyGameCharacterMover

@export var hand_attachment : BoneAttachment3D
@export var aim_speed : float = 5.0

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

func hit_balls(_direction : int) -> void:
	# TODO Launch all balls in range
	swing_state = SWING_STATE.RECOVERY

func process_inputs() -> void:
	if !is_cpu():
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			swing_state = SWING_STATE.AIMING
			character_animator.rpc("play_minigame_animation", get_anim_prefix() + "shot-right")
		elif Input.is_action_just_pressed("button_secondary%s" % get_input_suffix()):
			swing_state = SWING_STATE.AIMING
			character_animator.rpc("play_minigame_animation", get_anim_prefix() + "shot-left")
	
	if swing_state != SWING_STATE.RECOVERY:
		super()

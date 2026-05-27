### The player controller for the Giant Stakes party game.
extends PartyGameCharacterMover

@export var hand_attachment: BoneAttachment3D

func on_spawn_finished() -> void:
	super ()
	hand_attachment.reparent(character_animator.skeleton)
	swing_state = SWING_STATE.IDLE

func on_minigame_finished() -> void:
	super ()
	hand_attachment.visible = false

var swing_state: SWING_STATE
enum SWING_STATE {
	IDLE,
	SWING
}

func process_rotation(target_angle: float) -> void:
	if swing_state == SWING_STATE.IDLE:
		super (target_angle)

func process_speed() -> void:
	if swing_state == SWING_STATE.IDLE:
		super ()
		return
	
	_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())

func process_animation() -> void:
	if swing_state == SWING_STATE.IDLE:
		super ()

const ANIM_SWING_FINISH: int = 0
const ANIM_SWING_START: int = 1

func process_animation_event(event: int) -> void:
	if event == ANIM_SWING_FINISH: # Finished swinging
		swing_state = SWING_STATE.IDLE
	elif event == ANIM_SWING_START:
		swing_state = SWING_STATE.SWING
	

func process_inputs() -> void:
	if !is_cpu() && swing_state == SWING_STATE.IDLE:
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			rpc("start_swing", NetworkTimeSynchronizer.get_time())
		super ()

@rpc("any_peer", "call_local", "reliable")
func start_swing(tick: float) -> void:
	swing_state = SWING_STATE.SWING
	var target_anim: StringName
	target_anim = get_anim_prefix() + "hammer-up"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 2, 0, tick)

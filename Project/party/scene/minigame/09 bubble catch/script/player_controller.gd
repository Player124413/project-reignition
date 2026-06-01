### The player controller for the butterfly catching minigame.
extends PartyGameCharacterMover

@export var hand_attachment : BoneAttachment3D
@export var bubble_maker_mesh : MeshInstance3D
@export var fill_mesh : MeshInstance3D
@export var trail_mesh : GPUParticles3D
@export var bubble_maker_materials : Array[Material]
@export var bubble_fill_materials : Array[Material]
@export var bubble_trail_materials : Array[ParticleProcessMaterial]

func on_spawn_finished() -> void:
	super()
	hand_attachment.reparent(character_animator.skeleton)
	bubble_maker_mesh.material_override = bubble_maker_materials[player_index]
	fill_mesh.material_override = bubble_fill_materials[player_index]
	trail_mesh.process_material = bubble_trail_materials[player_index]

func on_minigame_finished() -> void:
	super()
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

func process_speed() -> void:
	if swing_state == SWING_STATE.IDLE:
		super()
		return
	
	_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())

const ANIM_SHOT_FINISH : int = 0
const ANIM_BUBBLE_SIZE_SMALL : int = 1
const ANIM_BUBBLE_SIZE_MEDIUM : int = 2
const ANIM_BUBBLE_SIZE_LARGE : int = 3
const ANIM_BUBBLE_SPAWN : int = 4
const ANIM_TRAIL_START : int = 8
const ANIM_TRAIL_STOP : int = 9
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
	elif event == ANIM_BUBBLE_SPAWN:
		# TODO Spawn bubble
		pass
	elif event == ANIM_TRAIL_START:
		trail_mesh.emitting = true
	elif event == ANIM_TRAIL_STOP:
		trail_mesh.emitting = false

func process_inputs() -> void:
	if !is_cpu() && swing_state == SWING_STATE.IDLE:
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			rpc("start_swing", NetworkTimeSynchronizer.get_time(), 1)
		elif Input.is_action_just_pressed("button_secondary%s" % get_input_suffix()):
			rpc("start_swing", NetworkTimeSynchronizer.get_time(), -1)
	if swing_state != SWING_STATE.RECOVERY:
		super()

@rpc("any_peer", "call_local", "reliable")
func start_swing(tick : float, dir : int) -> void:
	swing_state = SWING_STATE.AIMING
	var target_anim : StringName
	if dir == 1:
		target_anim = get_anim_prefix() + "swing-r"
	else:
		target_anim = get_anim_prefix() + "swing-l"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1, 0, tick)

const RB_SWING : int = 4
func on_rollback_applied(rb_params : Array) -> void:
	swing_state = rb_params[RB_SWING]
	super(rb_params)

func process_rollback() -> void:
	rollback_timer.set_param(RB_SWING, swing_state)
	super()

func get_target_animation() -> StringName:
	var base : StringName = super()
	if base == "run":
		return "walk"
	return base

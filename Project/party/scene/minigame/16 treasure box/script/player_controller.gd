### The player controller for the Treasure Box party game.
extends PartyGameCharacterMover
@export var hand_attachment: BoneAttachment3D

var _state: STATE
enum STATE {
	IDLE,
	THROW,
	SHAKE,
	DAMAGE,
	INVINCIBLE
}

func on_spawn_finished() -> void:
	super ()
	_state = STATE.IDLE

func on_minigame_finished() -> void:
	super ()

func process_rotation(target_angle: float) -> void:
	if _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		super (target_angle)

func process_speed() -> void:
	if _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		super ()
		return
	
	_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())

func process_animation() -> void:
	if _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		super ()

func process_movement_tick() -> void:
	process_invincibility()
	
	if _state == STATE.INVINCIBLE && !is_invincible():
		_state = STATE.IDLE
	super ()

func process_inputs() -> void:
	if !is_cpu() && _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		return
	super ()

@rpc("any_peer", "call_local", "reliable")
func request_damage() -> void:
	if !is_multiplayer_authority():
		return
	if _state == STATE.DAMAGE || is_invincible():
		return
	take_damage(NetworkTimeSynchronizer.get_time())

func take_damage(tick: float) -> void:
	var target_anim: StringName = get_anim_prefix() + "damage"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1, 0, tick)
	_state = STATE.DAMAGE
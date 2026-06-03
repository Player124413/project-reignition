### The player controller for the Giant Stakes party game.
extends PartyGameCharacterMover

@export var hand_attachment: BoneAttachment3D
@export var stake_spawner: StakeSpawner
@export var hammer_collision: CollisionShape3D
@export var player_hitbox: CollisionShape3D

func on_spawn_finished() -> void:
	super ()
	hand_attachment.reparent(character_animator.skeleton)
	_state = STATE.IDLE

func on_minigame_finished() -> void:
	super ()
	hand_attachment.visible = false

var _state: STATE
enum STATE {
	IDLE,
	SWING,
	DAMAGE
}


func process_rotation(target_angle: float) -> void:
	if _state == STATE.IDLE:
		super (target_angle)

func process_speed() -> void:
	if _state == STATE.IDLE || _state == STATE.DAMAGE:
		super ()
		return
	
	_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())

func process_animation() -> void:
	if _state == STATE.IDLE:
		super ()

func process_movement_tick() -> void:
	process_invincibility()
	super ()

const ANIM_SWING_FINISH: int = 0
const ANIM_SWING_START: int = 1
const ANIM_DAMAGE_START: int = 2
const ANIM_DAMAGE_FINISH: int = 3
const ANIM_INVINCIBILITY_START: int = 4

func process_animation_event(event: int) -> void:
	if event == ANIM_SWING_FINISH: # Finished swinging
		_state = STATE.IDLE
	elif event == ANIM_SWING_START:
		_state = STATE.SWING
	elif event == ANIM_DAMAGE_START:
		_state = STATE.DAMAGE
	elif event == ANIM_DAMAGE_FINISH:
		_state = STATE.IDLE
	elif event == ANIM_INVINCIBILITY_START:
		request_invincibility(1)
	

func process_inputs() -> void:
	if !is_cpu() && _state == STATE.IDLE:
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			rpc("start_swing", NetworkTimeSynchronizer.get_time())
		if Input.is_action_just_pressed("button_secondary%s" % get_input_suffix()):
			stake_spawner.request_spawn()
		super ()

@rpc("any_peer", "call_local", "reliable")
func start_swing(tick: float) -> void:
	hammer_collision.disabled = false
	_state = STATE.SWING
	var target_anim: StringName
	target_anim = get_anim_prefix() + "hammer-down"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1, 0, tick)

@rpc("any_peer", "call_local", "reliable")
func take_damage() -> void:
	if _state == STATE.DAMAGE:
		return
	character_animator.play_minigame_animation(get_anim_prefix() + "hurt")
	_state = STATE.DAMAGE

##The hitbox for the hammer
func _on_area_3d_area_entered(area: Area3D) -> void:
	if _state != STATE.SWING:
		return
	
	if !is_multiplayer_authority():
		return
	
	if area == player_hitbox:
		return

	if area.is_in_group("enemy") || area.is_in_group("player"):
		hammer_collision.disabled = true

	if area.is_in_group("player"):
		area.get_parent().rpc("take_damage")

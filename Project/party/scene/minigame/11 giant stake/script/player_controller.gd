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
	DAMAGE,
	INVINCIBLE
}

func process_rotation(target_angle: float) -> void:
	if _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		super (target_angle)

func process_speed() -> void:
	if _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		super ()
		return
	
	_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())

func process_animation() -> void:
	if _state == STATE.IDLE:
		super ()

func process_movement_tick() -> void:
	process_invincibility()
	
	if _state == STATE.INVINCIBLE && !is_invincible():
		print("Invincibility finished")
		_state = STATE.IDLE
		#player_hitbox.set_deferred("disabled", false)
	super ()


const ANIM_SWING_FINISH: int = 0
const ANIM_SWING_START: int = 1
const ANIM_DAMAGE_START: int = 2
const ANIM_INVINCIBILITY_START: int = 4

func process_animation_event(event: int) -> void:
	if event == ANIM_SWING_FINISH: # Finished swinging
		_state = STATE.IDLE
		hammer_collision.set_deferred("disabled", true)
	elif event == ANIM_SWING_START:
		_state = STATE.SWING
	elif event == ANIM_DAMAGE_START:
		_state = STATE.DAMAGE
	elif event == ANIM_INVINCIBILITY_START:
		_state = STATE.INVINCIBLE
		request_invincibility(1)
	

func process_inputs() -> void:
	if !is_cpu() && _state == STATE.IDLE || _state == STATE.INVINCIBLE:
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			start_swing(NetworkTimeSynchronizer.get_time())
	super ()

func start_swing(tick: float) -> void:
	hammer_collision.set_deferred("disabled", false)
	_state = STATE.SWING
	var target_anim: StringName
	target_anim = get_anim_prefix() + "hammer-down"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1, 0, tick)

func take_damage(tick: float) -> void:
	var target_anim: StringName = get_anim_prefix() + "hurt"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1, 0, tick)

	_state = STATE.DAMAGE

@rpc("any_peer", "call_local", "reliable")
func request_damage() -> void:
	if !is_multiplayer_authority():
		return
	if _state == STATE.DAMAGE || is_invincible():
		return
	take_damage(NetworkTimeSynchronizer.get_time())

##The hitbox for the hammer
func _on_area_3d_area_entered(area: Area3D) -> void:
	if _state != STATE.SWING:
		return
	
	if !is_multiplayer_authority():
		return
	
	if area == player_hitbox:
		return

	if area.is_in_group("enemy") || area.is_in_group("player"):
		hammer_collision.set_deferred("disabled", true)

	if area.is_in_group("player"):
		area.get_parent().get_parent().rpc("request_damage")


#####################
### ROLLBACK CODE ###
#####################
const RB_STATE: int = 4
func on_rollback_applied(rb_params: Array) -> void:
	_state = rb_params[RB_STATE]
	super (rb_params)

func process_rollback() -> void:
	rollback_timer.set_param(RB_STATE, _state)
	super ()

################
### CPU CODE ###
################

var target_stake: GiantStake
var cpu_swing_timer: float
const CPU_SWING_INTERVAL: float = 0.4
const CPU_SWING_INTERVAL_VARIANCE: float = 0.2
const CPU_SWING_RANGE: int = 6

func update_target_stake() -> void:
	if is_instance_valid(target_stake) && target_stake.is_enabled: # Already locked onto something
		return
	target_stake = stake_spawner.get_closest_stake(global_position)

func calculate_cpu_input() -> Vector2:
	#if player_index != 1: # DEBUG: Only programming a single cpu (player 2)
		#return Vector2.ZERO
	#cpu_interval_timer = 0
	if NetworkManager.is_hosting_game:
		update_target_stake()
	
	if target_stake == null: # No target
		return Vector2.ZERO

	var target_position: Vector3 = target_stake.global_position

	if is_multiplayer_authority():
		cpu_swing_timer = move_toward(cpu_swing_timer, 0, get_physics_process_delta_time())
		var remaining_distance: Vector3 = target_position - character_body.global_position
		var diff: PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
		remaining_distance.y = 0

		if is_zero_approx(cpu_swing_timer) && remaining_distance.length() < CPU_SWING_RANGE:
			cpu_swing_timer = CPU_SWING_INTERVAL
			if diff <= PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
				cpu_swing_timer += randf() * CPU_SWING_INTERVAL_VARIANCE
				start_swing(NetworkTimeSynchronizer.get_time())
			else:
				cpu_swing_timer += (1.0 - randf() * 2.0) * CPU_SWING_INTERVAL_VARIANCE
				remaining_distance = remaining_distance.rotated(Vector3.UP, -_move_angle)
				start_swing(NetworkTimeSynchronizer.get_time())
			return Vector2.ZERO

		if remaining_distance.length() > CPU_SWING_RANGE:
			return cpu_chase_position(target_position)
	return Vector2.ZERO

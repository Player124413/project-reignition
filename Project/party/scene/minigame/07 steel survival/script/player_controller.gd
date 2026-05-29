### Player controller for the steel survival minigame.
extends PartyGameCharacterSpawner

signal hit

@export var rollback_timer : RollbackTimer
@export var character_physics_parent : RigidBody3D
@export var surface_platform : Node3D
@export var spike_ball_rotation : Node3D
@export var spike_ball_position : Node3D
@export var spike_ball : Area3D
@export var hurtbox : Area3D
@export var platform_parent : Node3D
@export var throw_curve : Curve
@export var recovery_curve : Curve

@export var spin_sfx : GroupSfxPlayer
@export var hit_sfx : GroupSfxPlayer
@export var throw_sfx : GroupSfxPlayer
@export var crumble_sfx : AudioStreamPlayer

var spin_sfx_timer : float
const SPIN_SFX_INTERVAL : float = 0.5

var _platforms : Array[RigidBody3D]

var _state : STATE
var _anim_state : STATE

var _current_health : int = MAX_HEALTH
const MAX_HEALTH : int = 3

enum STATE {
	IDLE,
	SPINNING,
	THROWING,
	RECOVERY,
	DAMAGE
}

var _current_rotation : float
var _current_distance : float = IDLE_DISTANCE
var _current_height : float
var _rotation_speed : float
var _throw_distance : float
var _action_timer : float

const MAX_SPIN_SPEED : float = 14.0
const SPIN_ACCELERATION : float = 20
const SPIN_DECELERATION : float = 80

const THROW_LENGTH : float = 0.4
const RECOVERY_LENGTH : float = 0.4
const IDLE_ACCELERATION : float = 160

const IDLE_DISTANCE : float = 15
const IDLE_HEIGHT : float = 0

const SPIN_DISTANCE : float = 30
const SPIN_HEIGHT : float = 30

const THROW_DISTANCE : float = 150
const THROW_HEIGHT : float = -50
const THROW_HEIGHT_MULTIPLIER : float = 5
const MINIMUM_THROW_SPEED : float = 0.6
const HITSTUN_LENGTH : float = 0.4

var _top_platform_position : Vector3
const PLATFORM_SIZE : float = 30
const SHAKE_AMOUNT : float = 1.0
const GRAVITY_SCALE : float = 100.0

func on_spawn_finished() -> void:
	rollback_timer.register_target(self)
	for child in platform_parent.get_children():
		register_rigidbody(child.get_child(0) as RigidBody3D)
	
	for child in chain_parent.get_children():
		_chains.append(child)
	
	hand_attachment.reparent(character_animator.skeleton)
	register_rigidbody(surface_platform.get_child(0) as RigidBody3D)
	_top_platform_position = _platforms[_platforms.size() - 2].position
	
	if is_multiplayer_authority():
		MinigameManager.instance.request_score_change(player_index, MAX_HEALTH)
	
	character_animator.play_minigame_animation(get_anim_prefix() + "wait")
	_current_distance = IDLE_DISTANCE
	process_movement_tick()
	call_deferred("process_animation")

func register_rigidbody(rb : RigidBody3D) -> void:
	_platforms.append(rb)
	(rb.get_child(1) as CollisionShape3D).disabled = true
	rb.freeze = true
	rb.gravity_scale = GRAVITY_SCALE

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority() && !_is_gameplay_finished:
		process_input()
	
	process_movement_tick()
	process_animation()
	
	if is_multiplayer_authority():
		process_rollback()

func process_input() -> void:
	if _state != STATE.IDLE && _state != STATE.SPINNING:
		return
	
	if is_cpu():
		process_cpu_input()
		return
	
	var is_pressed : bool = Input.is_action_pressed("button_primary" + get_input_suffix())
	if is_pressed:
		_state = STATE.SPINNING
	elif _state == STATE.SPINNING:
		attempt_throw()

func can_throw() -> bool:
	var throw_ratio : float = _rotation_speed / MAX_SPIN_SPEED
	return throw_ratio > MINIMUM_THROW_SPEED && abs(angle_difference(_current_rotation, PI)) < PI

func attempt_throw() -> void:
	if can_throw():
		_action_timer = 0
		_state = STATE.THROWING
		throw_sfx.play_in_group()
		var throw_ratio : float = _rotation_speed / MAX_SPIN_SPEED
		_throw_distance = lerp(SPIN_DISTANCE, THROW_DISTANCE, throw_ratio)
		return
	_state = STATE.IDLE

#####################
### ROLLBACK CODE ###
#####################
const RB_DST : int = 0
const RB_ROT : int = 1
const RB_HEIGHT : int = 2
const RB_SPD : int = 3
const RB_THR : int = 4
const RB_TIME : int = 5
const RB_STATE : int = 6

func on_rollback_applied(rb_params : Array) -> void:
	_current_distance = rb_params[RB_DST]
	_current_rotation = rb_params[RB_ROT]
	_current_height = rb_params[RB_HEIGHT]
	_rotation_speed = rb_params[RB_SPD]
	_throw_distance = rb_params[RB_THR]
	_action_timer = rb_params[RB_TIME]
	_state = rb_params[RB_STATE]

func process_rollback() -> void:
	rollback_timer.set_param(RB_DST, _current_distance)
	rollback_timer.set_param(RB_ROT, _current_rotation)
	rollback_timer.set_param(RB_HEIGHT, _current_height)
	rollback_timer.set_param(RB_SPD, _rotation_speed)
	rollback_timer.set_param(RB_THR, _throw_distance)
	rollback_timer.set_param(RB_TIME, _action_timer)
	rollback_timer.set_param(RB_STATE, _state)
	rollback_timer.process_rollback()

################
### CPU CODE ###
################
@export var cpu_remaining_targets : Array[Node3D]
var cpu_timer : float
var cpu_target : int = -1
const CPU_INTERVAL : float = 1.5
const CPU_VARIANCE : float = 0.5
const CPU_ROTATION_INTERVAL = PI * 0.5
const CPU_THROW_RANGE = PI * 0.15
const CPU_THROW_OFFSET = PI * 0.25
func process_cpu_input() -> void:
	if _state == STATE.IDLE:
		_state = STATE.SPINNING
		return
	
	cpu_timer = move_toward(cpu_timer, 0, get_physics_process_delta_time())
	if !is_zero_approx(cpu_timer):
		return
	cpu_timer = CPU_INTERVAL - randf() * CPU_VARIANCE
	
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		# Low chance to randomly throw
		if randf() > 0.8:
			attempt_throw()
		return
	
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		# Medium chance to randomly throw
		if randf() > 0.5:
			attempt_throw()
		return
	
	if !can_throw():
		return
	
	# Actually try to target a player
	if cpu_target == -1 || cpu_target >= cpu_remaining_targets.size():
		cpu_target = calculate_cpu_target()
	
	var throw_direction : Vector3 = cpu_remaining_targets[cpu_target].global_position - global_position
	var target_throw_angle : float = Vector3.FORWARD.rotated(Vector3.UP, rotation.y).signed_angle_to(throw_direction, Vector3.UP)
	target_throw_angle -= CPU_THROW_OFFSET
	var angle_delta : float = abs(angle_difference(target_throw_angle, _current_rotation))
	
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		cpu_timer = randf() * CPU_VARIANCE
	else:
		cpu_timer = 0
	
	if angle_delta <= CPU_THROW_RANGE:
		attempt_throw()
		cpu_target = -1

func calculate_cpu_target() -> int:
	for i in range(cpu_remaining_targets.size() - 1, -1, -1):
		if MinigameManager.instance.player_scores[cpu_remaining_targets[i].player_index] == 0:
			# This target has been defeated
			cpu_remaining_targets.remove_at(i)
	return randi_range(0, cpu_remaining_targets.size() - 1)

func process_rotation() -> void:
	if _state == STATE.SPINNING:
		_rotation_speed = move_toward(_rotation_speed, MAX_SPIN_SPEED, SPIN_ACCELERATION * get_physics_process_delta_time())
	else:
		_rotation_speed = move_toward(_rotation_speed, 0, SPIN_DECELERATION * get_physics_process_delta_time())

func process_distance() -> void:
	if _state == STATE.IDLE || _state == STATE.DAMAGE:
		_current_distance = move_toward(_current_distance, IDLE_DISTANCE, IDLE_ACCELERATION * get_physics_process_delta_time())
		_current_height = move_toward(_current_height, IDLE_HEIGHT, IDLE_ACCELERATION * get_physics_process_delta_time())
	elif _state == STATE.SPINNING:
		spin_sfx_timer = move_toward(spin_sfx_timer, 0, get_physics_process_delta_time())
		if is_zero_approx(spin_sfx_timer):
			spin_sfx.play_in_group()
			spin_sfx_timer = SPIN_SFX_INTERVAL
		_current_distance = move_toward(_current_distance, SPIN_DISTANCE, SPIN_ACCELERATION * get_physics_process_delta_time())
		_current_height = move_toward(_current_height, SPIN_HEIGHT, SPIN_ACCELERATION * get_physics_process_delta_time())
	elif _state == STATE.THROWING:
		_action_timer += get_physics_process_delta_time()
		var t : float = throw_curve.sample(_action_timer / THROW_LENGTH)
		_current_distance = lerp(SPIN_DISTANCE, _throw_distance, t)
		t = clamp(t * THROW_HEIGHT_MULTIPLIER, 0, 1)
		_current_height = lerp(SPIN_HEIGHT, THROW_HEIGHT, t)
		if _action_timer >= THROW_LENGTH:
			finish_throw(false)
	elif _state == STATE.RECOVERY:
		_action_timer += get_physics_process_delta_time()
		var t : float = recovery_curve.sample(clamp(_action_timer / RECOVERY_LENGTH, 0, 1))
		_current_height = lerp(IDLE_HEIGHT, THROW_HEIGHT, t)
		_current_distance = lerp(IDLE_DISTANCE, _throw_distance, t)
		if _action_timer >= RECOVERY_LENGTH:
			_state = STATE.IDLE

func finish_throw(hitstun : bool) -> void:
	_action_timer = -HITSTUN_LENGTH if hitstun else 0.0
	_state = STATE.RECOVERY

func process_movement_tick() -> void:
	process_rotation()
	process_distance()
	_current_rotation += _rotation_speed * get_physics_process_delta_time()
	_current_rotation = fmod(_current_rotation, TAU)
	spike_ball_position.position = Vector3.FORWARD * _current_distance + Vector3.UP * _current_height
	spike_ball_rotation.rotation = Vector3.UP * _current_rotation

func process_animation() -> void:
	if _anim_state != _state:
		update_animation()
	
	process_shaking()
	process_chain()
	
	if _state == STATE.SPINNING: # Sync spin speeds
		character_animator.set_speed(1.0 + _rotation_speed / MAX_SPIN_SPEED)
	else:
		character_animator.set_speed(1.0)

func process_shaking() -> void:
	if _current_health == MAX_HEALTH:
		return
	
	var shake_ratio : int = MAX_HEALTH - _current_health
	for i in range(0, _platforms.size() - 2):
		var pos : Vector3 = Vector3.MODEL_RIGHT * (1.0 - randf() * 2.0) * SHAKE_AMOUNT * shake_ratio
		pos += Vector3.MODEL_FRONT * (1.0 - randf() * 2.0) * SHAKE_AMOUNT * shake_ratio
		_platforms[i].position = pos
	
	var top_pos : Vector3 = Vector3.MODEL_RIGHT * (1.0 - randf() * 2.0) * SHAKE_AMOUNT * shake_ratio
	top_pos += Vector3.MODEL_FRONT * (1.0 - randf() * 2.0) * SHAKE_AMOUNT * shake_ratio
	_platforms[_platforms.size() - 2].position = _top_platform_position + top_pos

@export var chain_parent : Node3D
@export var hand_attachment : BoneAttachment3D
@export var chain_origin : Node3D
var _chains : Array[Node3D]
const CHAIN_SIZE : int = 5
func process_chain() -> void:
	var distance : Vector3 = spike_ball_position.global_position - chain_origin.global_position
	var direction : Vector3 = distance.normalized()
	var chain_length : int = floor(_current_distance / CHAIN_SIZE)
	for i in _chains.size():
		_chains[i].visible = i <= chain_length
		if !_chains[i].visible:
			continue
		var pos : Vector3 = direction * CHAIN_SIZE
		if i == chain_length:
			pos = spike_ball_position.global_position - pos * 2
		else:
			pos = chain_origin.global_position + pos * i
		_chains[i].look_at_from_position(pos, spike_ball_position.global_position)
		if i % 2 == 0:
			_chains[i].rotate_object_local(Vector3.MODEL_FRONT, PI * 0.5)

const SPIN_ANIM_LENGTH : float = 0.933
func update_animation() -> void:
	if _state == STATE.SPINNING:
		var seek : float = _current_rotation / TAU
		seek *= SPIN_ANIM_LENGTH
		character_animator.play_minigame_animation(get_anim_prefix() + "spin-c", 0.2, 1.0, seek)
	elif _state == STATE.IDLE || _state == STATE.RECOVERY:
		character_animator.play_minigame_animation(get_anim_prefix() + "wait", 0.4)
	elif _state == STATE.THROWING:
		character_animator.play_minigame_animation(get_anim_prefix() + "shoot")
	
	_anim_state = _state

@rpc("any_peer", "call_local", "reliable")
func take_damage() -> void:
	_current_health -= 1
	character_animator.play_minigame_animation(get_anim_prefix() + "hit")
	hit.emit()
	
	if _current_health == 0:
		for rb in _platforms:
			rb.freeze = false
			rb.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 10.0)
			rb.apply_central_impulse(Vector3.MODEL_REAR * randf() * 50.0)
		
		crumble_sfx.play()
		character_physics_parent.freeze = false
		set_physics_process(false)
		hurtbox.set_deferred("monitorable", false)
		MinigameManager.instance.register_completed_player()
	else:
		_top_platform_position += Vector3.MODEL_FRONT * -5 + Vector3.RIGHT * 4
		_platforms[_platforms.size() - 2].position = _top_platform_position
		hurtbox.global_position = _platforms[_platforms.size() - 2].global_position
		hit_sfx.play_in_group()
	
	_state = STATE.DAMAGE
	
	if is_multiplayer_authority():
		MinigameManager.instance.request_score_change(player_index,  -1)

func process_animation_event(info : int) -> void:
	if _current_health == 0:
		return
	if info == 0:
		_state = STATE.IDLE
		character_animator.play_minigame_animation(get_anim_prefix() + "wait", 0.02)

func _on_hitbox_area_entered(area: Area3D) -> void:
	if _state != STATE.THROWING:
		return
	
	if !is_multiplayer_authority():
		return
	
	if area == hurtbox: # Don't allow hitting self
		return
	
	_rotation_speed = 0.0
	_throw_distance = _current_distance
	finish_throw(true)
	
	if area.is_in_group("enemy"): # Hit another spikeball
		print("hit a spike ball.")
		return
	
	area.get_parent().rpc("take_damage")

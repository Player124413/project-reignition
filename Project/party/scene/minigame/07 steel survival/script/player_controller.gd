### Player controller for the steel survival minigame.
extends PartyGameCharacterSpawner

@export var character_physics_parent : RigidBody3D
@export var surface_platform : Node3D
@export var spike_ball_rotation : Node3D
@export var spike_ball_position : Node3D
@export var spike_ball : Area3D
@export var hurtbox : Area3D
@export var platform_parent : Node3D
@export var throw_curve : Curve
@export var recovery_curve : Curve

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

const IDLE_DISTANCE : float = 15
const THROW_DISTANCE : float = 150
const SPIN_DISTANCE : float = 30
const SPIN_HEIGHT : float = 0

const THROW_HEIGHT : float = -50
const MINIMUM_THROW_SPEED : float = 0.6
const HITSTUN_LENGTH : float = 0.4

var _top_platform_position : Vector3
const PLATFORM_SIZE : float = 30
const SHAKE_AMOUNT : float = 1.0
const GRAVITY_SCALE : float = 100.0

func on_spawn_finished() -> void:
	for child in platform_parent.get_children():
		register_rigidbody(child.get_child(0) as RigidBody3D)
	
	register_rigidbody(surface_platform.get_child(0) as RigidBody3D)
	_top_platform_position = _platforms[_platforms.size() - 2].position
	MinigameManager.instance.request_score_change(player_index, MAX_HEALTH)
	character_animator.play_minigame_animation(get_anim_prefix() + "wait")

func register_rigidbody(rb : RigidBody3D) -> void:
	_platforms.append(rb)
	(rb.get_child(1) as CollisionShape3D).disabled = true
	rb.freeze = true
	rb.gravity_scale = GRAVITY_SCALE


func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		process_input()
	
	process_movement_tick()
	process_animation()

func process_input() -> void:
	if is_cpu():
		return
	
	if _state != STATE.IDLE && _state != STATE.SPINNING:
		return
	
	var is_pressed : bool = Input.is_action_pressed("button_primary" + get_input_suffix())
	if is_pressed:
		_state = STATE.SPINNING
	elif _state == STATE.SPINNING:
		# TODO Check for throw
		var throw_ratio : float = _rotation_speed / MAX_SPIN_SPEED
		if throw_ratio < MINIMUM_THROW_SPEED:
			_state = STATE.IDLE
		else:
			_action_timer = 0
			_throw_distance = lerp(SPIN_DISTANCE, THROW_DISTANCE, throw_ratio)
			_state = STATE.THROWING

func process_rotation() -> void:
	if _state == STATE.SPINNING:
		_rotation_speed = move_toward(_rotation_speed, MAX_SPIN_SPEED, SPIN_ACCELERATION * get_physics_process_delta_time())
	else:
		_rotation_speed = move_toward(_rotation_speed, 0, SPIN_DECELERATION * get_physics_process_delta_time())

func process_throw_distance() -> void:
	if _state == STATE.IDLE || _state == STATE.DAMAGE:
		_current_distance = move_toward(_current_distance, IDLE_DISTANCE, SPIN_ACCELERATION * get_physics_process_delta_time())
	elif _state == STATE.SPINNING:
		_current_distance = move_toward(_current_distance, SPIN_DISTANCE, SPIN_ACCELERATION * get_physics_process_delta_time())
	elif _state == STATE.THROWING:
		_action_timer += get_physics_process_delta_time()
		var t : float = throw_curve.sample(_action_timer / THROW_LENGTH)
		_current_distance = lerp(SPIN_DISTANCE, _throw_distance, t)
		_current_height = lerp(SPIN_HEIGHT, THROW_HEIGHT, t)
		if _action_timer >= THROW_LENGTH:
			finish_throw(false)
	elif _state == STATE.RECOVERY:
		_action_timer += get_physics_process_delta_time()
		var t : float = recovery_curve.sample(clamp(_action_timer / RECOVERY_LENGTH, 0, 1))
		_current_height = lerp(SPIN_HEIGHT, THROW_HEIGHT, t)
		_current_distance = lerp(IDLE_DISTANCE, _throw_distance, t)
		if _action_timer >= RECOVERY_LENGTH:
			_state = STATE.IDLE

func finish_throw(hitstun : bool) -> void:
	_action_timer = -HITSTUN_LENGTH if hitstun else 0.0
	_state = STATE.RECOVERY

func process_movement_tick() -> void:
	process_rotation()
	process_throw_distance()
	_current_rotation += _rotation_speed * get_physics_process_delta_time()
	spike_ball_position.position = Vector3.FORWARD * _current_distance + Vector3.UP * _current_height
	spike_ball_rotation.rotation = Vector3.UP * _current_rotation

func process_animation() -> void:
	if _anim_state != _state:
		update_animation()
	
	process_shaking()
	
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

func update_animation() -> void:
	if _state == STATE.SPINNING:
		character_animator.play_minigame_animation(get_anim_prefix() + "spin-c", 0.2)
	elif _state == STATE.IDLE || _state == STATE.RECOVERY:
		character_animator.play_minigame_animation(get_anim_prefix() + "wait", 0.4)
	elif _state == STATE.THROWING:
		character_animator.play_minigame_animation(get_anim_prefix() + "shoot")
	
	_anim_state = _state

@rpc("any_peer", "call_local", "reliable")
func take_damage() -> void:
	_current_health -= 1
	character_animator.play_minigame_animation(get_anim_prefix() + "hit")
	
	if _current_health == 0:
		for rb in _platforms:
			rb.freeze = false
			rb.apply_torque_impulse(Vector3(randf(), randf(), randf()) * 10.0)
			rb.apply_central_impulse(Vector3.MODEL_REAR * randf() * 50.0)
		
		character_physics_parent.freeze = false
		set_physics_process(false)
		hurtbox.set_deferred("monitorable", false)
		MinigameManager.instance.register_completed_player()
	else:
		_top_platform_position += Vector3.MODEL_FRONT * -5 + Vector3.RIGHT * 4
		_platforms[_platforms.size() - 2].position = _top_platform_position
		hurtbox.global_position = _platforms[_platforms.size() - 2].global_position
	
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
	
	if area == hurtbox: # Don't allow hitting self
		return
	
	_rotation_speed = 0.0
	_throw_distance = _current_distance
	finish_throw(true)
	
	if area.is_in_group("enemy"): # Hit another spikeball
		return
	
	area.get_parent().rpc("take_damage")

### The player controller for the parasol ball minigame.
extends PartyGameCharacterMover

signal ball_hit

@export var hand_attachment : BoneAttachment3D
@export var collision_raycast : RayCast3D
@export var aim_speed : float = 8.0
@export var basket : Node3D

@export var swing_sfx : GroupSfxPlayer
@export var hit_sfx : GroupSfxPlayer

const HIT_HEIGHT : int = 30
const HIT_DIRECTION_INFLUENCE : float = PI * 0.2
var ball_targets : Array[Area3D]

func on_spawn_finished() -> void:
	super()
	hand_attachment.reparent(character_animator.skeleton)

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
	if ball_targets.size() != 0:
		hit_sfx.play_in_group()
		ball_hit.emit()
	
	# Launch all balls in range
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
	swing_sfx.play_in_group()
	var target_anim : StringName
	if dir == 1:
		character_animator.play_voice("grunt2")
		target_anim = get_anim_prefix() + "shot-right"
	else:
		character_animator.play_voice("grunt1")
		target_anim = get_anim_prefix() + "shot-left"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1, 0, tick)

func _on_hit_trigger_area_entered(area: Area3D) -> void:
	if !area.is_in_group("enemy") || !is_physics_processing():
		return
	
	ball_targets.append(area)
	if player_index == -1:
		rpc("start_swing", NetworkTimeSynchronizer.get_time(), -1)
	elif is_cpu():
		process_cpu_swing()

func _on_hit_trigger_area_exited(area: Area3D) -> void:
	if !area.is_in_group("enemy") || !is_physics_processing():
		return
	var index : int = ball_targets.find(area)
	if index != -1:
		ball_targets.remove_at(index)

const RB_SWING : int = 4
func on_rollback_applied(rb_params : Array) -> void:
	swing_state = rb_params[RB_SWING]
	super(rb_params)

func process_rollback() -> void:
	rollback_timer.set_param(RB_SWING, swing_state)
	super()

## Used to track cpu parasol balls
var cpu_parasols : Array[ParasolBall]
var cpu_target_parasol : ParasolBall
var cpu_swing_direction : int
func on_cpu_parasol_entered(area : Area3D) -> void:
	if area is not ParasolBall || area.hit_index != -1:
		return
	
	cpu_parasols.append(area)

func on_cpu_parasol_exited(area: Area3D) -> void:
	if area is not ParasolBall:
		return
	var index : int = cpu_parasols.find(area)
	if index != -1:
		cpu_parasols.remove_at(index)

const CPU_SWING_DISTANCE : float = 7.5
func process_cpu_swing() -> void:
	if !is_multiplayer_authority():
		return
	
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY || difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		cpu_swing_direction = sign(-basket.global_position.x)
		if cpu_swing_direction == 0:
			cpu_swing_direction += 1
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD: # Choose the proper swing side
		cpu_swing_direction = sign(ball_targets[0].global_position.x - character_body.global_position.x)
		if cpu_swing_direction == 0:
			cpu_swing_direction += 1
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EXTREME: # Choose the proper swing side
		cpu_swing_direction = sign(character_body.global_position.x)
	
	cpu_interval_timer = 0.0
	start_swing(NetworkTimeSynchronizer.get_time(), cpu_swing_direction)

func calculate_cpu_input() -> Vector2:
	process_cpu_target_parasol()
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	var direction : Vector2 = Vector2.DOWN
	if swing_state == SWING_STATE.AIMING:
		if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY || difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
			return Vector2.DOWN
		
		var basket_position : Vector2 = Vector2(basket.global_position.x, basket.global_position.z) 
		direction = Vector2.DOWN.rotated(-HIT_DIRECTION_INFLUENCE * cpu_swing_direction) # Calculate a "straight shot forward"
		if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
			# Kinda aim towards the basket
			direction = direction.rotated(-PI * 0.2 * sign(basket_position.x) * randf())
		else:
			# Much better aim
			basket_position -= Vector2(character_body.global_position.x, character_body.global_position.z)
			var rotation_amount : float = basket_position.angle_to(Vector2.UP)
			direction = direction.rotated(rotation_amount)
		return direction
	
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		# Choose a random direction (Even when there's nothing to hit)
		direction = direction.rotated(TAU * randf())
		return direction
	
	if cpu_target_parasol == null:
		return Vector2.ZERO
	
	# Chase the target
	var difference : Vector3 = cpu_target_parasol.global_position - character_body.global_position
	direction.x = difference.x
	direction.y = -difference.z
	direction = direction.limit_length()
	return direction

func process_cpu_target_parasol() -> void:
	if cancel_cpu_target_parasol():
		cpu_target_parasol.cpu_count -= 1
		cpu_target_parasol = null
	
	while cpu_target_parasol == null && cpu_parasols.size() != 0:
		var target_index : int = randi_range(0, cpu_parasols.size() - 1)
		if cpu_parasols[target_index].is_hit || !cpu_parasols[target_index].is_active:
			cpu_parasols.remove_at(target_index)
		else:
			cpu_target_parasol = cpu_parasols[target_index]
			cpu_target_parasol.cpu_count += 1

func cancel_cpu_target_parasol() -> bool:
	if cpu_target_parasol == null:
		return false
	
	if cpu_target_parasol.hit_index != -1 || !cpu_target_parasol.is_active:
		return true
	
	if cpu_target_parasol.cpu_count > 2:
		# Prevent cpus clumping together
		return true
	
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY || difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		# Easier cpus have simplier cancel checks
		return false
	
	var delta_pos : Vector3 = cpu_target_parasol.global_position - character_body.global_position
	var flat_pos : Vector2 = Vector2(delta_pos.x, delta_pos.z)
	if delta_pos.y < CPU_SWING_DISTANCE && flat_pos.length() > CPU_SWING_DISTANCE * 2.0:
		# Not reaching the ball in time. Find a different ball.
		return true
	
	return false

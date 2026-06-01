extends PartyGameCharacterMover

@export var collision_sfx : GroupSfxPlayer
@export var knockback_strength : float = 15.0
### Tracks whether the player is being knocked back or not.
var _is_knockback_active : bool
### The stored knockback angle
var _knockback_angle : float
### Tracks whether we played the falling voice clip or not.
var can_play_fall_voice : bool
var last_knockback_index : int = -1
const BASE_KNOCKBACK : float = 12.0

@export var ball_mesh : Node3D
var previous_ball_position : Vector3
### Multiplier for the ball's rotation
const BALL_ROTATION_FACTOR : float = 0.2
const SLIDE_STRENGTH : float = 30.0

func on_spawn_finished() -> void:
	super()
	previous_ball_position = ball_mesh.global_position
	character_animator.play_minigame_animation(get_anim_prefix() + "walk")
	BallSurvivalPlatform.instance.register_player(self)
	apply_gravity() # Snap to floor
	apply_movement()

func process_movement_tick() -> void:
	if !character_body.get_world_3d().space.is_valid():
		return
	
	if character_body.is_on_floor():
		var slide_vel : Vector3 = character_body.get_floor_normal()
		slide_vel.y = 0.0
		character_body.velocity = slide_vel * SLIDE_STRENGTH
		character_body.move_and_slide()
	
	super()
	if character_body.get_slide_collision_count() != 0:
		if is_multiplayer_authority() && character_body.get_slide_collision(0).get_collider(0) is CharacterBody3D:
			var other : PartyGameCharacterMover = character_body.get_slide_collision(0).get_collider(0).get_parent()
			request_knockback(other)
			other.request_knockback(self)

func process_inputs() -> void:
	if _is_knockback_active || is_falling():
		_input = Vector2.ZERO
		return
	super()

var cpu_target_player : PartyGameCharacterMover

func calculate_cpu_input() -> Vector2:
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	var pos : Vector3 = character_body.global_position
	pos.y = 0
	var dir : Vector2 = Vector2(-pos.x, pos.z).normalized()
	var variance : float = 1.0 - randf() * 2.0
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		return dir.rotated(variance * PI * 0.5)
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		return dir.normalized().rotated(variance * PI * 0.2)
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		cpu_interval_timer = 0.0
		var target_pos : Vector3 = cpu_target_player.global_position if cpu_target_player != null else Vector3.ZERO
		target_pos.y = 0
		if target_pos.length() < PLATFORM_RADIUS * 0.8 && pos.length() > PLATFORM_RADIUS * 0.5:
			cpu_target_player = null
		elif cpu_target_player == null:
			cpu_target_player = get_target_cpu()
		if cpu_target_player != null:
			pos = (character_body.global_position - cpu_target_player.global_position)
			dir = Vector2(-pos.x, pos.z).normalized()
		return dir.normalized().rotated(variance * PI * 0.2)
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EXTREME:
		cpu_interval_timer = 0.0
		var target_pos : Vector3 = cpu_target_player.global_position if cpu_target_player != null else Vector3.ZERO
		target_pos.y = 0
		if target_pos.length() < PLATFORM_RADIUS * 0.5 && pos.length() > PLATFORM_RADIUS * 0.2:
			cpu_target_player = null
		elif cpu_target_player == null:
			cpu_target_player = get_target_cpu()
		if cpu_target_player != null:
			pos = (character_body.global_position - cpu_target_player.global_position)
			dir = Vector2(-pos.x, pos.z).normalized()
		return dir.normalized().rotated(variance * PI * 0.2)
	return Vector2.ZERO

const PLATFORM_RADIUS : float = 30.0

### Gets the player that's closest to the edge so we can attack them.
func get_target_cpu() -> PartyGameCharacterMover:
	var closest : PartyGameCharacterMover = null
	for player in BallSurvivalPlatform.instance.players:
		if player == self:
			continue
		if closest == null:
			closest = player
		elif player.global_position.length_squared() > closest.global_position.length_squared():
			closest = player
	return closest

func process_speed() -> void:
	super()
	if _is_knockback_active && (is_zero_approx(_move_speed) || is_falling()):
		if is_zero_approx(_move_speed):
			_move_angle = _knockback_angle
		else:
			_move_angle += PI
			_move_speed *= -1
		_is_knockback_active = false
		last_knockback_index = -1 # Reset flag

func apply_gravity() -> void:
	super()
	var collision_test : KinematicCollision3D = character_body.move_and_collide(Vector3.DOWN * 10, true)
	if collision_test != null && collision_test.get_collider() != null:
		can_play_fall_voice = true
	elif can_play_fall_voice:
		can_play_fall_voice = false
		character_animator.play_voice("fall1")

func request_knockback(other : PartyGameCharacterMover) -> void:
	var knockback_direction : Vector3 = (character_body.global_position - other.character_body.global_position)
	var target_angle : float = Vector3.FORWARD.signed_angle_to(knockback_direction, Vector3.UP)
	var target_speed : float = BASE_KNOCKBACK + get_knockback_ratio() * knockback_strength
	other.rpc("apply_knockback", other._move_angle, target_angle, target_speed, other.player_index)

@rpc("any_peer", "call_local", "reliable")
func apply_knockback(original_angle : float, target_angle : float , target_speed : float, other_index : int) -> void:
	if other_index == last_knockback_index: # skip double collisions
		return
	call_deferred("apply_knockback_deferred", original_angle, target_angle, target_speed, other_index)

func apply_knockback_deferred(original_angle : float, target_angle : float , target_speed : float, other_index : int) -> void:
	# Set deferred so we calculate the other player's knockback from the proper speed
	if !_is_knockback_active:
		# Store knockback angle so we can return to it later
		_knockback_angle = original_angle
		_is_knockback_active = true
		collision_sfx.play_in_group()
	_move_angle = target_angle
	_move_speed = target_speed 
	last_knockback_index = other_index # Store index to detect double collisions
	character_animator.play_minigame_animation(get_anim_prefix() + "hit")
	character_animator.queue_minigame_animation(get_anim_prefix() + "walk", 0.3)
	character_animator.play_voice("balance")

func get_knockback_ratio() -> float:
	return _move_speed / run_speed

func process_rotation(target_angle : float) -> void:
	if is_falling():
		return
	super(target_angle)

func apply_movement_rotation() -> void:
	if is_falling() && _is_spawn_finished:
		return
	super()

func process_animation() -> void:
	super()
	
	var rotation_axis : Vector3 = (ball_mesh.global_position - previous_ball_position).rotated(Vector3.UP, PI * 0.5)
	if rotation_axis.is_zero_approx():
		return
	
	var rotation_amount : float = rotation_axis.length() * BALL_ROTATION_FACTOR
	ball_mesh.global_rotate(rotation_axis.normalized(), rotation_amount)
	previous_ball_position = ball_mesh.global_position

func get_target_animation() -> StringName:
	if is_falling():
		return "fall"
	
	if _is_knockback_active:
		return ""
	
	if is_zero_approx(_move_speed) || _is_braking || _is_start_turning:
		return "walk"
	
	return "back"

func is_falling() -> bool:
	return !character_body.is_on_floor() && character_body.get_slide_collision_count() == 0

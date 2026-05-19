extends PartyGameCharacterMover

@export var knockback_strength : float = 15.0
### Tracks whether the player is being knocked back or not.
var _is_knockback_active : bool
### The stored knockback angle
var _knockback_angle : float
var last_knockback_index : int = -1
const BASE_KNOCKBACK : float = 12.0

@export var ball_mesh : Node3D
### Multiplier for the ball's rotation
const BALL_ROTATION_FACTOR : float = 0.2

func on_spawn_finished() -> void:
	super()
	character_animator.play_minigame_animation(get_anim_prefix() + "walk")

func process_movement_tick() -> void:
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
	_move_angle = target_angle
	_move_speed = target_speed 
	last_knockback_index = other_index # Store index to detect double collisions
	character_animator.play_minigame_animation(get_anim_prefix() + "hit")
	character_animator.queue_minigame_animation(get_anim_prefix() + "walk", 0.3)

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
	var rotation_axis : Vector3 = Vector3.RIGHT.rotated(Vector3.UP, _move_angle)
	var rotation_amount : float = _move_speed * BALL_ROTATION_FACTOR * get_physics_process_delta_time()
	ball_mesh.global_rotate(rotation_axis, rotation_amount)

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

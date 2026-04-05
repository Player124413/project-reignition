extends Node3D

signal demo_finished

@export var player_index : int
@export var character_animator : CharacterAnimator

@export var camera : Camera3D
@export var spawn_position : Node3D
@export var bat_attachment : BoneAttachment3D
@export var catapult_animator : AnimationPlayer
@export var ball : Node3D
@export var ball_target : Node3D

@export_group("CPU Settings")
## Curves that are sampled to determine cpu's offset amount
@export var cpu_difficulty_curves : Array[Curve]

## The ratio at which CPU player will swing. Re-calculated every time a ball is pitched.
var cpu_swing_ratio : float
## The ratio at which CPU player will "contact". Re-calculated every time a ball is pitched.
var cpu_contact_ratio : float
## Tracks whether the cpu can swing or not. Prevents multiple random swings.
var can_cpu_swing : bool
## Tracks whether the player is swinging or not.
var is_swinging : bool
## Ratio from [0, 1] that determines the ball's position along its current trajectory.
var travel_ratio : float

## How close the ball has to be to the bat to count as a hit.
const HIT_WINDOW : float = 12.0;
const HOME_RUN_WINDOW : float = 8.0;
const IN_FIELD_ANGLE : float = PI * 0.25;

## How far the ball should go during a home run.
const HOME_RUN_DISTANCE : float = 1200.0
## How far the ball should go during an in-field.
const IN_FIELD_DISTANCE : float = 500.0
## How long the ball should travel when hit.
const HIT_TRAVEL_LENGTH : float = 1.0
## How high the ball should fly when hit.
const HIT_HEIGHT : float = 150.0

## Distance at which a "Strike" occurs and a new ball is thrown.
const STRIKE_DISTANCE : float = 100.0

## Multiplier for the catapult animation, because it's too slow by default.
const CATAPULT_ANIMATION_MULTIPLIER : float = 1.8
## Multiplier for the swing animation, because it feels sluggish otherwise.
const SWING_ANIMATION_MULTIPLIER : float = 2.0
## Windup length used for CPU controlled players to calculate when to swing.
const SWING_ANIMATION_WINDUP : float = 0.3333333;
## Maximum amount of swing variance in CPU controlled players.
const CPU_MAX_VARIANCE : float = 0.15;

## The speed at which the ball is currently travelling at.
var ball_speed : float
## The position the ball was hit at.
var ball_start_position : Vector3
## The position the ball will end at.
var ball_end_position : Vector3
var ball_state : BALL_STATES
enum BALL_STATES {
	LOAD,
	PITCH,
	HIT
}
## Queue of randomly generated pitch speeds
static var pitch_queue : Array[int]
var pitch_index : int
## List of possible pitch timings.
const PITCH_LENGTHS : Array[float] = [1.0, 1.5, 0.8]
## Total number of balls to send over the course of the mini-game.
const PITCH_COUNT : int = 10

# At what point to begin scaling the ball (so it's not gigantic next to the player).
const BALL_SCALE_DISTANCE : float = 80

func _ready() -> void:
	if NetworkManager.is_online:
		# TODO Set up authority
		pass
	
	if player_index != -1:
		# Instance Player Model
		character_animator = MinigameManager.instance.load_character_model(player_index)
		spawn_position.add_child(character_animator)
		character_animator.play_animation(get_anim_prefix() + "wait")
		
		# TODO Check if this player index is actually being used
		set_physics_process(false)
		MinigameManager.instance.gameplay_started.connect(Callable.create(self, "activate"))
		
		if is_multiplayer_authority() && player_index == 0: # Only generate queue from player 1
			rpc("generate_pitch_queue")
	
	ball.visible = false
	bat_attachment.reparent(character_animator.skeleton)
	character_animator.connect("animation_event", Callable.create(self, "process_animation_event"))

@rpc("any_peer", "call_local", "reliable")
func generate_pitch_queue() -> void:
	for i in PITCH_COUNT:
		var random_index : int = randi_range(0, PITCH_LENGTHS.size() - 1)
		pitch_queue.append(random_index)

func activate() -> void:
	set_physics_process(true)
	pitch_ball() # Start pitching balls

func _physics_process(_delta: float) -> void:
	if !is_multiplayer_authority():
		# TODO Sync with other users
		return
	
	process_swing()
	process_ball()
	process_camera()

func process_swing() -> void:
	if is_swinging:
		return
	
	if player_index == -1 || PartyManager.get_player_data(player_index).is_cpu_player(): # CPU Behaviour
		process_cpu()
	elif Input.is_action_just_pressed("button_primary1"):
		start_swing()

## Simply swings at the right time. The swing timing is set in calculate_swing_ratio().
func process_cpu() -> void:
	if can_cpu_swing && ball_state == BALL_STATES.PITCH && cpu_swing_ratio < travel_ratio:
		can_cpu_swing = false
		start_swing()

func start_swing() -> void:
	character_animator.play_minigame_animation(get_anim_prefix() + "swing", 0.1, SWING_ANIMATION_MULTIPLIER)
	is_swinging = true

## Handles ball movement.
func process_ball() -> void:
	if ball_state == BALL_STATES.LOAD:
		return
	
	travel_ratio = move_toward(travel_ratio, 1.0, ball_speed * get_physics_process_delta_time())
	ball.global_position = sample_hit_position(travel_ratio)
	
	# Update ball scale
	var scale_t : float = ball.global_position.distance_to(ball_target.global_position) / BALL_SCALE_DISTANCE
	scale_t = 1.0 - clamp(scale_t, 0.0, 1.0)
	ball.scale = Vector3.ONE.lerp(Vector3.ONE * 0.5, scale_t)
	if !is_equal_approx(travel_ratio, 1.0) || catapult_animator.is_playing():
		return
	
	if player_index == -1: # Finished the demo!
		demo_finished.emit()
		# Stop processing
		set_process(false)
		set_physics_process(false)
	else:
		pitch_ball()

func process_camera() -> void:
	if ball_state == BALL_STATES.HIT:
		camera.look_at_from_position(camera.global_position, ball.global_position, Vector3.UP)
	else:
		camera.transform = Transform3D.IDENTITY

func sample_hit_position(ratio : float) -> Vector3:
	var ball_position : Vector3 = ball_start_position.lerp(ball_end_position, ratio)
	if ball_state == BALL_STATES.HIT: # Add vertical height
		ball_position.y += sin(PI * ratio) * HIT_HEIGHT
	return ball_position

func get_anim_prefix() -> String:
	return "02-" if player_index == -1 else "%s/" % MinigameManager.ANIMATION_LIBRARY_PREFIX

## Handle animation events from the character's animation controller
func process_animation_event(info : int) -> void:
	if info == 0: # Return to idle
		is_swinging = false
		character_animator.play_minigame_animation(get_anim_prefix() + "wait", 0.1)
	elif info == 1: # Strike the ball
		check_hit()

func check_hit() -> void:
	if ball_state != BALL_STATES.PITCH: # Ball is not travelling
		return
	
	if player_index == -1 || PartyManager.get_player_data(player_index).is_cpu_player():
		# Calculate on the exact swing ratio to avoid fps jank
		ball.global_position = sample_hit_position(cpu_contact_ratio)
	
	var distance : float = ball.global_position.distance_to(ball_target.global_position)
	if distance < HIT_WINDOW:
		var travel_direction : Vector3 = (ball_end_position - ball_start_position).normalized()
		var hit_direction : int = sign(travel_direction.dot(ball_target.global_position - ball.global_position))
		hit_ball(distance, hit_direction)

func hit_ball(distance : float, direction : int, _network_time : float = 0.0) -> void:
	var angle : float = calculate_hit_angle(distance) * direction
	var target_distance : float = HOME_RUN_DISTANCE if distance < HOME_RUN_WINDOW else IN_FIELD_DISTANCE
	
	# Change state
	ball_state = BALL_STATES.HIT
	travel_ratio = 0.0 # TODO Change this based on network_time
	ball_speed = calculate_travel_speed(HIT_TRAVEL_LENGTH)
	ball_start_position = ball.global_position
	ball_end_position = ball_target.global_position
	ball_end_position += Vector3.FORWARD.rotated(Vector3.UP, angle) * target_distance

func calculate_hit_angle(hit_distance : float) -> float:
	return IN_FIELD_ANGLE * (hit_distance / HIT_WINDOW)

## Starts a pitch.
func pitch_ball() -> void:
	ball_state = BALL_STATES.LOAD
	ball.visible = false
	
	if pitch_index == PITCH_COUNT: # Finished pitching balls
		return
	catapult_animator.play("catapult", -1, CATAPULT_ANIMATION_MULTIPLIER)
	catapult_animator.seek(0.0)

## Called from the catapult animation when the ball spawns.
func load_ball() -> void:
	ball.top_level = false
	ball.transform = Transform3D.IDENTITY
	ball.reset_physics_interpolation()
	ball.visible = true

## Called from the catapult animation when the ball launches.
func launch_ball() -> void:
	ball.top_level = true
	ball_state = BALL_STATES.PITCH
	ball_start_position = ball.global_position
	ball_end_position = ball_target.global_position
	ball_end_position += (ball_end_position - ball_start_position).normalized() * STRIKE_DISTANCE
	if player_index == -1:
		ball_speed = calculate_travel_speed(PITCH_LENGTHS[0])
	else:
		var index : int = pitch_queue[pitch_index]
		ball_speed = calculate_travel_speed(PITCH_LENGTHS[index])
		pitch_index += 1
	travel_ratio = 0.0
	
	if is_multiplayer_authority():
		calculate_swing_ratio()

## Calculates the swing ratio for CPUs.
func calculate_swing_ratio() -> void:
	var total_distance : float = ball_start_position.distance_to(ball_end_position)
	var target_distance : float = ball_start_position.distance_to(ball_target.global_position) # This is the target contact ratio
	var cpu_offset : float = calculate_cpu_difficulty_offset() # Add randomness based on CPU difficulty
	var swing_offset : float = SWING_ANIMATION_WINDUP / SWING_ANIMATION_MULTIPLIER + get_physics_process_delta_time() * 2.0
	swing_offset += cpu_offset
	
	cpu_contact_ratio = (target_distance - (total_distance * ball_speed * cpu_offset)) / total_distance
	target_distance -= total_distance * ball_speed * swing_offset # Offset by windup length (relative to ratio)
	cpu_swing_ratio = target_distance / total_distance
	can_cpu_swing = true # Allow the cpu to swing

func calculate_cpu_difficulty_offset() -> float:
	if player_index == -1: # Demo has a consistent offset
		return 0
	
	var difficulty : int = PartyManager.get_player_data(player_index).cpu_difficulty
	var offset : float = cpu_difficulty_curves[difficulty].sample(randf()) * CPU_MAX_VARIANCE
	return offset

func calculate_travel_speed(travel_length : float) -> float:
	return 1.0 / travel_length

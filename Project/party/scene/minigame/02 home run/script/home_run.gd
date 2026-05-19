### Manages the Home Run party game.
### Netcode Implementation Details:
### When the game first loads, the host player generates a queue of ball speeds
### and sends that queue to the other players via an RPC call.
### As the game runs, Player animations are synced through RPC calls,
### and ball positions are resynced on contact.
### CPU swing timings are calculated and sent via RPC far in advance, then simulated locally.
extends PartyGameCharacterSpawner

signal ball_hit

@export var camera : Camera3D
@export var bat_attachment : BoneAttachment3D
@export var catapult_animator : AnimationPlayer
@export var ball : Node3D
@export var ball_target : Node3D
@export var hit_fx : Node3D

@export var hit_sfx : Array[AudioStreamPlayer]
@export var pitch_sfx : Array[GroupSfxPlayer]
@export var throw_sfx : Array[GroupSfxPlayer]
@export var swing_sfx : AudioStreamPlayer

var camera_transition : float
const CAMERA_TRANSITION_LENGTH : float = 0.1

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
const CATAPULT_ANIMATION_MULTIPLIER : float = 3.0
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
const PITCH_LENGTHS : Array[float] = [1.5, 1.0, 0.8]
## Total number of balls to send over the course of the mini-game.
const PITCH_COUNT : int = 10

# At what point to begin scaling the ball (so it's not gigantic next to the player).
const BALL_SCALE_DISTANCE : float = 80

func on_spawn_finished() -> void:
	ball.visible = false
	bat_attachment.reparent(character_animator.skeleton)
	character_animator.play_animation(get_anim_prefix() + "wait")

func on_host_spawned() -> void:
	MinigameManager.instance.peers_loaded.connect(Callable(self, "generate_pitch_queue"))

func generate_pitch_queue() -> void:
	for i in PITCH_COUNT:
		var random_index : int = randi_range(0, PITCH_LENGTHS.size() - 1)
		pitch_queue.append(random_index)
	rpc("sync_pitch_queue", pitch_queue) # Sync to all network devices

## Syncs the pitching queue across the network
@rpc("any_peer", "call_local", "reliable")
func sync_pitch_queue(new_queue : Array[int]) -> void:
	pitch_queue = new_queue

func activate() -> void:
	super()
	pitch_ball() # Start pitching balls

func on_minigame_finished() -> void:
	super()
	bat_attachment.visible = false

func _physics_process(_delta: float) -> void:
	process_swing()
	process_ball()
	process_camera()

func process_swing() -> void:
	if is_swinging:
		return
	
	if is_cpu():
		process_cpu()
		return
	
	if !is_multiplayer_authority():
		return
	
	if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
		start_player_swing()

## Simply swings at the right time. The swing timing is set in calculate_swing_ratio().
func process_cpu() -> void:
	if can_cpu_swing && ball_state == BALL_STATES.PITCH && cpu_swing_ratio < travel_ratio:
		can_cpu_swing = false
		start_cpu_swing()

## Starts a local swing animation from a CPU.
func start_cpu_swing() -> void:
	character_animator.play_minigame_animation(get_anim_prefix() + "swing", 0.1, SWING_ANIMATION_MULTIPLIER)
	is_swinging = true

## Starts an RPC swing from a player.
func start_player_swing() -> void:
	character_animator.rpc("play_minigame_animation",
		get_anim_prefix() + "swing",
		0.1,
		SWING_ANIMATION_MULTIPLIER,
		0.0,
		NetworkTimeSynchronizer.get_time())
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
		MinigameManager.instance.request_minigame_start() # Start the minigame
		deactivate()
	else:
		pitch_ball()

func process_camera() -> void:
	var target_transition : float = 1 if ball_state == BALL_STATES.HIT else 0
	camera_transition = move_toward(camera_transition, target_transition, get_physics_process_delta_time() / CAMERA_TRANSITION_LENGTH)
	camera.look_at_from_position(camera.global_position, ball.global_position, Vector3.UP)
	var t : float = smoothstep(0.0, 1.0, 1.0 - camera_transition)
	camera.transform = camera.transform.interpolate_with(Transform3D.IDENTITY, t)

func sample_hit_position(ratio : float) -> Vector3:
	var ball_position : Vector3 = ball_start_position.lerp(ball_end_position, ratio)
	if ball_state == BALL_STATES.HIT: # Add vertical height
		ball_position.y += sin(PI * ratio) * HIT_HEIGHT
	return ball_position

## Handle animation events from the character's animation controller
func process_animation_event(info : int) -> void:
	if info == 0: # Return to idle
		is_swinging = false
		character_animator.queue_minigame_animation(get_anim_prefix() + "wait", 0.1)
	elif info == 1 && (is_multiplayer_authority() || is_cpu()): # Strike the ball
		check_hit()
		swing_sfx.play()

## Checks whether the batter hit the ball or not.
func check_hit() -> void:
	if ball_state != BALL_STATES.PITCH: # Ball is not travelling
		return
	
	var ball_position : Vector3 = ball.global_position
	if is_cpu():
		# Calculate on the exact swing ratio to avoid fps jank
		ball_position = sample_hit_position(cpu_contact_ratio)
	
	var distance : float = ball_position.distance_to(ball_target.global_position)
	if distance < HIT_WINDOW:
		var travel_direction : Vector3 = (ball_end_position - ball_start_position).normalized()
		var hit_direction : int = sign(travel_direction.dot(ball_target.global_position - ball_position))
		if is_cpu():
			hit_ball(distance, hit_direction, ball_position, NetworkTimeSynchronizer.get_time())
		else:
			rpc("hit_ball", distance, hit_direction, ball_position, NetworkTimeSynchronizer.get_time())

@rpc("any_peer", "call_local", "reliable")
func hit_ball(distance : float, direction : int, hit_position : Vector3, network_time : float) -> void:
	var is_home_run : bool = distance < HOME_RUN_WINDOW
	var angle : float = calculate_hit_angle(distance) * direction
	var target_distance : float = HOME_RUN_DISTANCE if is_home_run else IN_FIELD_DISTANCE
	hit_sfx[1 if is_home_run else 0].play()
	
	if is_multiplayer_authority() && player_index != -1:
		MinigameManager.instance.request_score_change(player_index, 2 if is_home_run else 1)
		var popup_pos : Vector2 = score_counter.global_position + Vector2.RIGHT * score_counter.size.x * 0.5
		MinigameManager.instance.request_score_popup(player_index, 2 if is_home_run else 1, popup_pos)
	
	# Change state
	ball_state = BALL_STATES.HIT
	ball_speed = calculate_travel_speed(HIT_TRAVEL_LENGTH)
	ball_start_position = hit_position
	ball_end_position = ball_target.global_position
	ball_end_position += Vector3.FORWARD.rotated(Vector3.UP, angle) * target_distance
	hit_fx.global_position = hit_position
	
	# Resync ball position
	var delta_time : float = NetworkTimeSynchronizer.get_time() - network_time
	travel_ratio = ball_speed * delta_time
	ball.global_position = sample_hit_position(travel_ratio)
	ball_hit.emit()

func calculate_hit_angle(hit_distance : float) -> float:
	return IN_FIELD_ANGLE * (hit_distance / HIT_WINDOW)

## Starts a pitch.
func pitch_ball() -> void:
	ball_state = BALL_STATES.LOAD
	ball.visible = false
	
	if pitch_index == PITCH_COUNT: # Finished pitching balls
		MinigameManager.instance.register_completed_player()
		return
	
	catapult_animator.play("catapult", -1, CATAPULT_ANIMATION_MULTIPLIER)
	catapult_animator.seek(0.0)
	var speed_index : int = 1
	if player_index != -1:
		speed_index = pitch_queue[pitch_index]
	pitch_sfx[speed_index].play_in_group()

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
	var speed_index : int = 1
	if player_index != -1:
		speed_index = pitch_queue[pitch_index]
		pitch_index += 1
	
	ball_speed = calculate_travel_speed(PITCH_LENGTHS[speed_index])
	travel_ratio = 0.0
	throw_sfx[speed_index].play_in_group()
	pitch_sfx[speed_index].stop_in_group()

	if is_multiplayer_authority():
		rpc("calculate_swing_ratio", randf())

## Calculates the swing ratio for CPUs.
@rpc("any_peer", "call_local", "reliable")
func calculate_swing_ratio(random_value : float) -> void:
	var total_distance : float = ball_start_position.distance_to(ball_end_position)
	var target_distance : float = ball_start_position.distance_to(ball_target.global_position) # This is the target contact ratio
	var cpu_offset : float = calculate_cpu_difficulty_offset(random_value) # Add randomness based on CPU difficulty
	var swing_offset : float = SWING_ANIMATION_WINDUP / SWING_ANIMATION_MULTIPLIER + get_physics_process_delta_time() * 2.0
	swing_offset += cpu_offset
	
	cpu_contact_ratio = (target_distance - (total_distance * ball_speed * cpu_offset)) / total_distance
	target_distance -= total_distance * ball_speed * swing_offset # Offset by windup length (relative to ratio)
	cpu_swing_ratio = target_distance / total_distance
	can_cpu_swing = true # Allow the cpu to swing

func calculate_cpu_difficulty_offset(random_value : float) -> float:
	if player_index == -1: # Demo has a consistent offset
		return 0
	
	var difficulty : int = get_cpu_difficulty()
	var offset : float = cpu_difficulty_curves[difficulty].sample(random_value) * CPU_MAX_VARIANCE
	return offset

func calculate_travel_speed(travel_length : float) -> float:
	return 1.0 / travel_length

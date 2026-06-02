### Manages the Minecart Race party game.
extends PartyGameCharacterSpawner

@export var wall_detection : Node3D
@export var path_follower : PathFollow3D
@export var camera_root : Node3D
@export var minecart_root : Node3D
@export var minecart_animator: AnimationPlayer
@export var wheels : Array[Node3D]
@export var cart_roll_sfx : GroupSfxPlayer
@export var damage_sfx : GroupSfxPlayer
@export var pump_sfx : GroupSfxPlayer
@export var wind_sfx : GroupSfxPlayer

var lever_state: LEVER_STATES
enum LEVER_STATES {
	DOWN,
	UP
}

## How fast the cart is currently moving.
var current_speed : float
## How much extra slope momementum the cart has.
var slope_speed : float
## How fast the cart should fall.
var current_gravity : float

## Tracks whether the player can pump or not.
var can_pump : bool
## Tracks whether the player is taking damage or not.
var is_damage_active : bool
## Tracks whether the demo is active or not.
var is_demo_active : bool = true
## Tracks whether the demo pump is finished or not.
var is_demo_pump_finished : bool

## The progress at which to fire the demo pump.
const DEMO_PUMP_PROGRESS : float = 100.0

const GRAVITY : float = 500.0
const MAX_GRAVITY : float = 800.0

## How fast should the minecart move at the start.
const INITIAL_SPEED : float = 50.0
## How fast should the minecart move when hit.
const MIN_SPEED : float = 20.0
## How fast should the minecart go with pumping.
const MAX_SPEED : float = 300.0
## How much speed should be added each pump.
const ADDITIVE_SPEED : float = 50.0
const NORMAL_DECCELERATION : float = 5.0

## How much speed should be added during a slope.
const SLOPE_ACCELERATION : float = 200.0
## How much to deccelerate when going uphill or flat.
const SLOPE_DECCELERATION : float = 100.0
## How much additional speed to add when going downhill.
const MAX_DOWNHILL_ADDITIVE_SPEED : float = 60.0

### How far ahead to look for walls.
const WALL_DETECTION_LEAD : float = 120.0
const INITIAL_WALL_DETECTION_OFFSET : float = 5.0

## How much to smooth the cart's rotation.
const BASIS_ROTATION_SPEED : float = 0.3
## Multiplier for the pump animation.
const PUMP_ANIM_SPEED : float = 2.0
## Multiplier for the tires' animations.
const TIRE_ANIMATION_SPEED : float = 0.1

func on_spawn_finished() -> void:
	super()
	camera_root.top_level = true
	wall_detection.top_level = true
	
	rollback_timer.register_target(self)
	character_animator.play_animation(get_anim_prefix() + "low-wait")
	
	current_speed = INITIAL_SPEED
	MinigameManager.instance.gameplay_started.connect(Callable(self, "on_gamplay_started"))
	set_physics_process(true) # Movement is needed during the demo
	
	# Randomize sfx time so they aren't all overlapping
	get_tree().create_timer(randf()).timeout.connect(Callable(cart_roll_sfx, "play_in_group"))

func on_gamplay_started() -> void:
	can_pump = true
	is_demo_active = false

func on_gameplay_finished() -> void:
	super()
	can_pump = false

func _physics_process(_delta: float) -> void:
	if !_is_spawn_finished:
		return
	
	if is_demo_active:
		if lever_state == LEVER_STATES.UP && character_animator.get_current_animation() != get_anim_prefix() + "up":
			start_player_pump_down()
		elif !is_demo_pump_finished && path_follower.progress > DEMO_PUMP_PROGRESS:
			is_demo_pump_finished = true
			start_player_pump_up()
	
	process_movement_tick()
	process_pump()
	process_animation()
	
	if rollback_timer.is_authority():
		process_rollback()

#####################
### ROLLBACK CODE ###
#####################
@export var rollback_timer : RollbackTimer
const RB_POS : int = 0
const RB_SPD : int = 1
const RB_SLOPE_SPD : int = 2
const RB_GRAVITY : int = 3
func on_rollback_applied(rb_params : Array) -> void:
	path_follower.progress = rb_params[RB_POS]
	current_speed = rb_params[RB_SPD]
	slope_speed = rb_params[RB_SLOPE_SPD]
	current_gravity = rb_params[RB_GRAVITY]

func process_rollback() -> void:
	rollback_timer.set_param(RB_POS, path_follower.progress)
	rollback_timer.set_param(RB_SPD, current_speed)
	rollback_timer.set_param(RB_SLOPE_SPD, slope_speed)
	rollback_timer.set_param(RB_GRAVITY, current_gravity)
	rollback_timer.process_rollback()

func process_movement_tick() -> void:
	if _is_gameplay_finished:
		current_speed = move_toward(current_speed, MIN_SPEED, SLOPE_DECCELERATION * get_physics_process_delta_time())
	elif current_speed > INITIAL_SPEED && is_zero_approx(slope_speed):
		current_speed = move_toward(current_speed, INITIAL_SPEED, NORMAL_DECCELERATION * get_physics_process_delta_time())
	
	# Store starting state
	var starting_height : float = path_follower.global_position.y
	var starting_progress : float = path_follower.progress
	
	var tick_distance : float = (current_speed + slope_speed) * get_physics_process_delta_time()
	path_follower.progress += tick_distance # Move forward
	
	var process_fall : bool = false
	## Handle falling sections
	while is_processing_fall():
		path_follower.progress += tick_distance
		process_fall = true
	
	if process_fall: # Deal with vertical drops
		# Update path follower v_offset to remain visually consistent
		var delta_height : float = starting_height - path_follower.global_position.y
		path_follower.v_offset += delta_height
		
		# Catch up progress-wise
		var delta_progress : float = path_follower.progress - starting_progress
		delta_progress -= delta_height
		path_follower.progress += tick_distance - delta_progress
	
	process_gravity()
	process_slope()
	process_transforms()

func process_slope() -> void:
	var forward_dir : Vector3 = path_follower.global_basis.z
	if forward_dir.y > -0.2: # Flat or downhill
		if forward_dir.y > 0.2: # Uphill--affect actual speed
			current_speed = move_toward(current_speed, MIN_SPEED, SLOPE_DECCELERATION * get_physics_process_delta_time())
		slope_speed = move_toward(slope_speed, 0, SLOPE_DECCELERATION * get_physics_process_delta_time())
	else: # Downhill
		slope_speed = move_toward(slope_speed, MAX_DOWNHILL_ADDITIVE_SPEED, SLOPE_ACCELERATION * get_physics_process_delta_time())

func process_gravity() -> void:
	if is_zero_approx(path_follower.v_offset):
		current_gravity = 0
		return
	
	current_gravity = move_toward(current_gravity, MAX_GRAVITY, GRAVITY * get_physics_process_delta_time())
	path_follower.v_offset = move_toward(path_follower.v_offset, 0, current_gravity * get_physics_process_delta_time())
	if is_zero_approx(path_follower.v_offset):
		damage_sfx.play_in_group()

func process_transforms() -> void:
	if !_is_gameplay_finished:
		camera_root.global_position = path_follower.global_position
	minecart_root.global_position = path_follower.global_position
	
	# Update wall detection
	var speed_ratio : float = (current_speed + slope_speed) / MAX_SPEED
	var wall_detection_offset : float = (speed_ratio * WALL_DETECTION_LEAD + INITIAL_WALL_DETECTION_OFFSET)
	wall_detection.global_position = path_follower.global_position + Vector3.RIGHT * wall_detection_offset
	
	# Smooth out rotations
	var target_basis : Basis = minecart_root.global_basis
	target_basis = target_basis.slerp(path_follower.global_basis, BASIS_ROTATION_SPEED)
	minecart_root.global_basis = target_basis.orthonormalized()

## Returns whether the path is a vertical drop.
func is_processing_fall() -> bool:
	var dot : float = path_follower.basis.z.dot(Vector3.UP)
	return is_equal_approx(abs(dot), 1.0)

func process_pump() -> void:
	if _is_gameplay_finished || !can_pump:
		return
	
	if !is_multiplayer_authority():
		return
	
	var is_pressed : bool = false
	if is_cpu():
		is_pressed = process_cpu_inputs()
	else:
		is_pressed = Input.is_action_just_pressed("button_primary%s" % get_input_suffix())
	
	if is_pressed: # If the lever is up, pump down, and vice versa.
		if lever_state == LEVER_STATES.UP:
			rpc("start_player_pump_down")
		else:
			rpc("start_player_pump_up")

var walls_detected : int
var cpu_timer : float
const SLOW_CPU_INTERVAL : float = 0.2
const QUICK_CPU_INTERVAL : float = 0.05
const CPU_INTERVAL_VARIANCE : float = 0.15
func process_cpu_inputs() -> bool:
	cpu_timer = move_toward(cpu_timer, 0, get_physics_process_delta_time())
	if !is_zero_approx(cpu_timer):
		return false
	
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY: # Slow mash
		cpu_timer = SLOW_CPU_INTERVAL + (1.0 - randf() * 2.0) * CPU_INTERVAL_VARIANCE
		return randf() > 0.5
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL: # Just mashes
		cpu_timer = QUICK_CPU_INTERVAL + randf() * CPU_INTERVAL_VARIANCE
		return true
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD: # Wall avoidance
		if walls_detected <= 0:
			cpu_timer = SLOW_CPU_INTERVAL + randf() * CPU_INTERVAL_VARIANCE
		else:
			cpu_timer = QUICK_CPU_INTERVAL + randf() * CPU_INTERVAL_VARIANCE
		return walls_detected <= 0 || lever_state == LEVER_STATES.UP
	else:
		cpu_timer = QUICK_CPU_INTERVAL + randf() * CPU_INTERVAL_VARIANCE
		return walls_detected <= 0 || lever_state == LEVER_STATES.UP

func process_animation() -> void:
	var rot_amount : float = slope_speed + current_speed
	rot_amount *= TIRE_ANIMATION_SPEED * get_physics_process_delta_time()
	for wheel in wheels:
		wheel.rotation += Vector3.FORWARD * rot_amount

## Pushes the minecart lever down.
@rpc("authority", "call_local", "reliable")
func start_player_pump_down() -> void:
	can_pump = false
	lever_state = LEVER_STATES.DOWN
	minecart_animator.play("down", -1, PUMP_ANIM_SPEED)
	character_animator.play_minigame_animation(get_anim_prefix() + "down", 0.0, PUMP_ANIM_SPEED)
	character_animator.queue_minigame_animation(get_anim_prefix() + "low-wait")
	current_speed = move_toward(current_speed, MAX_SPEED, ADDITIVE_SPEED)
	pump_sfx.play_in_group()
	if is_equal_approx(current_speed, MAX_SPEED):
		wind_sfx.play_in_group()

## Pushes the minecart lever up.
@rpc("authority", "call_local", "reliable")
func start_player_pump_up() -> void:
	can_pump = false
	lever_state = LEVER_STATES.UP
	minecart_animator.play("up", -1, PUMP_ANIM_SPEED)
	character_animator.play_minigame_animation(get_anim_prefix() + "up", 0.0, PUMP_ANIM_SPEED)
	character_animator.queue_minigame_animation(get_anim_prefix() + "top-wait")
	pump_sfx.play_in_group()
	if !is_demo_active && !character_animator.is_voice_playing() && randf() > 0.75:
		character_animator.play_voice("grunt1")

## Animation event used to enable pumping again.
const ANIM_PUMP_ENABLED : int = 0
func process_animation_event(info : int) -> void:
	if info == ANIM_PUMP_ENABLED && !is_demo_active:
		can_pump = true
		is_damage_active = false

@rpc("authority", "call_local", "reliable")
func take_damage() -> void:
	if is_damage_active:
		return
	
	can_pump = false
	cpu_timer = 0
	walls_detected = 0
	is_damage_active = true
	current_speed = MIN_SPEED
	lever_state = LEVER_STATES.DOWN
	minecart_animator.play("damage", -1, PUMP_ANIM_SPEED)
	character_animator.play_minigame_animation(get_anim_prefix() + "damage")
	character_animator.queue_minigame_animation(get_anim_prefix() + "low-wait", 0.2)
	damage_sfx.play_in_group()
	character_animator.play_voice("hurt1")

func _on_detection_area_entered(area: Area3D) -> void:
	if !is_multiplayer_authority():
		return
	
	if area.is_in_group("wall"):
		rpc("take_damage")
	elif area.is_in_group("level wall"):
		MinigameManager.instance.request_time_change(player_index, NetworkTimeSynchronizer.get_time())
		MinigameManager.instance.request_minigame_finish()

func _on_wall_detection_area_entered(area: Area3D) -> void:
	if area.is_in_group("wall"):
		walls_detected += 1

func _on_wall_detection_area_exited(area: Area3D) -> void:
	if area.is_in_group("wall"):
		walls_detected = max(walls_detected - 1, 0)

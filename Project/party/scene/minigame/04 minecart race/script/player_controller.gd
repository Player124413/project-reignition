### Manages the Minecart Race party game.
extends PartyGameCharacterSpawner

@export var path_follower : PathFollow3D
@export var camera_root : Node3D
@export var minecart_root : Node3D
@export var minecart_animator: AnimationPlayer
@export var wheels : Array[Node3D]

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

const GRAVITY : float = 500.0
const MAX_GRAVITY : float = 800.0

## How fast should the minecart move at the start.
const INITIAL_SPEED : float = 50.0
## How fast should the minecart move when hit.
const MIN_SPEED : float = 20.0
## How fast should the minecart go with pumping.
const MAX_SPEED : float = 300.0
## How much speed should be added each pump.
const ADDITIVE_SPEED : float = 20.0

## How much speed should be added during a slope.
const SLOPE_ACCELERATION : float = 200.0
## How much to deccelerate when going uphill or flat.
const SLOPE_DECCELERATION : float = 100.0
## How much additional speed to add when going downhill.
const MAX_DOWNHILL_ADDITIVE_SPEED : float = 60.0

## How much to smooth the cart's rotation.
const BASIS_ROTATION_SPEED : float = 0.3
## Multiplier for the pump animation.
const PUMP_ANIM_SPEED : float = 2.0
## Multiplier for the tires' animations.
const TIRE_ANIMATION_SPEED : float = 0.1

func on_spawn_finished() -> void:
	super()
	current_speed = INITIAL_SPEED
	character_animator.play_animation(get_anim_prefix() + "low-wait")
	camera_root.top_level = true
	set_physics_process(true) # Movement is needed during the demo
	MinigameManager.instance.gameplay_started.connect(Callable(self, "on_gamplay_started"))

func on_gamplay_started() -> void:
	can_pump = true

func on_gameplay_finished() -> void:
	super()
	can_pump = false

func _physics_process(_delta: float) -> void:
	if !_is_spawn_finished:
		return
	
	process_movement_tick()
	process_pump()
	process_animation()

func process_movement_tick() -> void:
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

func process_transforms() -> void:
	if !_is_gameplay_finished:
		camera_root.global_position = path_follower.global_position
	minecart_root.global_position = path_follower.global_position
	
	# Smooth out rotations
	var target_basis : Basis = minecart_root.global_basis
	target_basis = target_basis.slerp(path_follower.global_basis, BASIS_ROTATION_SPEED)
	minecart_root.global_basis = target_basis.orthonormalized()

## Returns whether the path is a vertical drop.
func is_processing_fall() -> bool:
	var dot : float = path_follower.basis.z.dot(Vector3.UP)
	return is_equal_approx(abs(dot), 1.0)

func process_pump() -> void:
	if _is_gameplay_finished:
		current_speed = move_toward(current_speed, MIN_SPEED, SLOPE_DECCELERATION * get_physics_process_delta_time())
	
	if !can_pump || !is_multiplayer_authority():
		return
	
	var is_pressed : bool = false
	if is_cpu():
		is_pressed = process_cpu_inputs()
	else:
		is_pressed = Input.is_action_just_pressed("button_primary%s" % get_input_suffix())
	
	if is_pressed: # If the lever is up, pump down, and vice versa.
		if lever_state == LEVER_STATES.UP:
			start_player_pump_down()
		else:
			start_player_pump_up()

func process_cpu_inputs() -> bool:
	return false

func process_animation() -> void:
	var rot_amount : float = slope_speed + current_speed
	rot_amount *= TIRE_ANIMATION_SPEED * get_physics_process_delta_time()
	for wheel in wheels:
		wheel.rotation += Vector3.FORWARD * rot_amount

## Pushes the minecart lever down.
func start_player_pump_down() -> void:
	can_pump = false
	lever_state = LEVER_STATES.DOWN
	minecart_animator.play("down", -1, PUMP_ANIM_SPEED)
	character_animator.play_minigame_animation(get_anim_prefix() + "down", 0.0, PUMP_ANIM_SPEED)
	character_animator.queue_minigame_animation(get_anim_prefix() + "low-wait")
	current_speed = move_toward(current_speed, MAX_SPEED, ADDITIVE_SPEED)

## Pushes the minecart lever up.
func start_player_pump_up() -> void:
	can_pump = false
	lever_state = LEVER_STATES.UP
	minecart_animator.play("up", -1, PUMP_ANIM_SPEED)
	character_animator.play_minigame_animation(get_anim_prefix() + "up", 0.0, PUMP_ANIM_SPEED)
	character_animator.queue_minigame_animation(get_anim_prefix() + "top-wait")

## Animation event used to enable pumping again.
const ANIM_PUMP_ENABLED : int = 0
func process_animation_event(info : int) -> void:
	if info == ANIM_PUMP_ENABLED:
		can_pump = true
		is_damage_active = false

func _on_detection_area_entered(area: Area3D) -> void:
	if area.is_in_group("wall"):
		take_damage()
	elif area.is_in_group("level wall"):
		MinigameManager.instance.request_score_change(player_index, 1)
		MinigameManager.instance.request_minigame_finish()

func take_damage() -> void:
	if is_damage_active:
		return
	can_pump = false
	is_damage_active = true
	current_speed = MIN_SPEED
	lever_state = LEVER_STATES.DOWN
	minecart_animator.play("damage", -1, PUMP_ANIM_SPEED)
	character_animator.play_minigame_animation(get_anim_prefix() + "damage")
	character_animator.queue_minigame_animation(get_anim_prefix() + "low-wait", 0.2)

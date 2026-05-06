extends PartyGameCharacterSpawner

@export var cogwheels : Array[Node3D]
@export var majin_spawn_positions : Array[Node3D]
@export var handle : Node3D

## Total number of majin to spawn. Add 1 for the demo.
@export var total_majin_count : int = 45
## Total number of bonus majin to spawn.
@export var total_bonus_majin_count : int = 3
## List of all majin spawn times. Negative means that it's a bonus majin.
var majin_spawn_times : PackedFloat32Array
## Tracks the current majin spawn time.
var majin_spawn_timer : float
## Tracks the current majin being spawned.
var majin_spawn_index : int
## Total amount of time it should take to spawn all majins.
const TOTAL_SPAWN_TIME : float = 27
## Variance between each spawn time.
const SPAWN_TIME_VARIANCE : float = 0.1

@export var majin_scene : PackedScene
var majin_pool : Array[Node3D]
## Majin currently in play. Used for CPU calculations.
var active_majin : Array[Node3D]

## Ignore all majin above this node.
@export var cpu_upper_bound : Node3D
## Ignore all majin below this node.
@export var cpu_lower_bound : Node3D
## Determines whether a majin is on the upper gear or the lower gear.
@export var cpu_middle_bound : Node3D

var is_demo_complete : bool
var is_inverted : bool
var current_input : float

var current_rotation_speed : float
const ROTATION_ACCELERATION : float = 40.0
const ROTATION_DECCELERATION : float = 120.0
const MAX_ROTATION_SPEED : float = 5.0
const ANIMATION_SPEED : float = 3.0
## Amount to bias spawn randomness based on rotation speed.
const SPAWN_BIAS : float = 0.25

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if is_demo_complete:
			process_majin_spawn(delta)
			current_input = calculate_cpu_input() if is_cpu() else get_horizontal_input()
		
		process_rollback()
	
	process_movement_tick()
	process_animation()

#####################
### ROLLBACK CODE ###
#####################
@export var rollback_timer : RollbackTimer
const RB_INPUT : int = 0
const RB_SPD : int = 1
func on_rollback_applied(rb_params : Array) -> void:
	current_input = rb_params[RB_INPUT]
	current_rotation_speed = rb_params[RB_SPD]

func process_rollback() -> void:
	rollback_timer.set_param(RB_INPUT, current_input)
	rollback_timer.set_param(RB_SPD, current_rotation_speed) 
	rollback_timer.process_rollback()

func on_spawn_finished() -> void:
	set_physics_process(true)
	rollback_timer.register_target(self)
	
	initialize_majin()
	is_inverted = player_index % 2 == 1
	character_animator.play_minigame_animation(get_anim_prefix() + "pull")
	character_animator.set_speed(0)
	if is_inverted:
		var animator : AnimationPlayer = get_node("DirectionAnimator")
		animator.play("invert")
		animator.advance(0.0)
	
	if !is_multiplayer_authority():
		return
	
	spawn_majin()

func complete_demo() -> void:
	is_demo_complete = true
	set_physics_process(false)
	
	if NetworkManager.is_hosting_game:
		var start_callable : Callable = Callable.create(MinigameManager.instance, "request_minigame_start")
		get_tree().create_timer(1).timeout.connect(start_callable)

func deactivate() -> void:
	super()
	current_rotation_speed = 0
	character_animator.set_speed(0)

## Initialize the pool of majin.
func initialize_majin() -> void:
	for i in range(total_majin_count):
		var new_majin : Node3D = majin_scene.instantiate()
		new_majin.set_multiplayer_authority(get_multiplayer_authority())
		add_child(new_majin)
		new_majin.cogwheel = self
		new_majin.initialize()
		majin_pool.append(new_majin)
	
	if !is_multiplayer_authority():
		return
	
	# Set up spawn times
	majin_spawn_times.resize(total_majin_count)
	var base_spawn_interval : float = TOTAL_SPAWN_TIME / (total_majin_count - 1)
	for i in range(1, total_majin_count):
		majin_spawn_times[i] = i * base_spawn_interval + (1 - randf() * 2) * SPAWN_TIME_VARIANCE
	
	@warning_ignore("integer_division")
	var bonus_interval : int = (total_majin_count - 2) / total_bonus_majin_count
	for i in range(total_bonus_majin_count): # Flag bonus majin
		var lower_bound : int = bonus_interval * i
		lower_bound = max(lower_bound, 1)
		var upper_bound : int = bonus_interval * (i + 1)
		var index : int = randi_range(lower_bound, upper_bound)
		majin_spawn_times[index] *= -1
		if !is_cpu():
			print("Bonus majin are %s" % index)

func spawn_majin() -> void:
	var majin : Node3D = majin_pool[majin_spawn_index]
	var spawn_position_index : int = 0
	active_majin.append(majin)
	if is_demo_complete:
		var cut_off : float = 0.5
		cut_off += (current_rotation_speed * SPAWN_BIAS) / MAX_ROTATION_SPEED
		if is_inverted:
			cut_off = 1 - cut_off
		spawn_position_index = 0 if randf() > cut_off else 1
		
	var majin_position : Vector3 = majin_spawn_positions[spawn_position_index].global_position
	majin.request_spawn(majin_position, majin_spawn_times[majin_spawn_index] < 0)
	majin_spawn_index += 1

func on_majin_despawned(majin : Node3D) -> void:
	var index : int = active_majin.find(majin)
	if index != -1:
		active_majin.remove_at(index)

func process_majin_spawn(delta : float) -> void:
	if majin_spawn_index >= majin_spawn_times.size():
		return
	
	majin_spawn_timer += delta
	if majin_spawn_timer > abs(majin_spawn_times[majin_spawn_index]):
		spawn_majin()

## Applies an input when in demo mode. Called from slimes.
func apply_demo_input(is_contacting_slime : bool) -> void:
	current_input = 0
	if is_contacting_slime:
		current_input = -1 if is_inverted else 1

## Applies the input to the cogwheel.
func process_movement_tick() -> void:
	var target_speed : float = current_input * MAX_ROTATION_SPEED
	var target_rotation : float = ROTATION_ACCELERATION
	if sign(target_speed) != sign(current_rotation_speed):
		target_rotation = ROTATION_DECCELERATION
	current_rotation_speed = move_toward(current_rotation_speed, target_speed, target_rotation * get_physics_process_delta_time())

var cpu_input_timer : float
const CPU_INTERVAL : float = 1.5
const INTERVAL_VARIANCE : float = 0.4

func calculate_cpu_input() -> float:
	if active_majin.size() == 0: # Nothing to process
		return 0
	
	var difficulty : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	cpu_input_timer -= get_physics_process_delta_time()
	if cpu_input_timer > 0: # Don't update
		return current_input
	
	var target_input : float = current_input
	cpu_input_timer = CPU_INTERVAL + randf() * INTERVAL_VARIANCE
	if difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		# Choose a random direction and just hold it indefinitely
		target_input = 1 - (randf() * 2)
		if abs(target_input) < 0.6: # Overwhelmed; catch breath
			target_input = 0
			cpu_input_timer = CPU_INTERVAL - INTERVAL_VARIANCE
		else:
			target_input = sign(target_input) # Easy cpu doesn't know how to stack
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		# Choose a random direction and just hold it indefinitely
		if is_zero_approx(target_input):
			target_input = 1 if randf() > 0.5 else -1
		else: # Choose the opposite direction
			target_input *= -1
		cpu_input_timer = CPU_INTERVAL + randf() * INTERVAL_VARIANCE
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		# Always go for the direction with more majin on it
		var preferred_direction : int = get_side_priority()
		target_input = preferred_direction
		cpu_input_timer *= 0.2
	elif difficulty == PlayerData.CPU_DIFFICULTY_ENUM.EXTREME:
		# Always go for the direction with more majin on it, plus use accumulation and cashout
		var preferred_direction : int = get_height_priority()
		cpu_input_timer *= 0.2
		target_input = preferred_direction
	
	return target_input

## Returns the side with more majin on it, based on height.
func get_height_priority() -> int:
	var low_count : int = 0
	var high_count : int = 0
	for majin in active_majin:
		# Ignore airborne majin
		if majin.global_position.y > cpu_upper_bound.global_position.y:
			continue
		if majin.global_position.y < cpu_lower_bound.global_position.y:
			continue
		
		var priority : int = 5 if majin.is_bonus_majin else 1 # Prioritize bonus majin
		if majin.global_position.y > cpu_middle_bound.global_position.y:
			low_count += priority
		else:
			high_count += priority
	if low_count == 0 && high_count == 0:
		return 0
	var target : int = -1 if low_count > high_count else 1
	if is_inverted:
		target *= -1
	return target

## Returns the side with more majin on it, based on positions.
func get_side_priority() -> int:
	var left_count : int = 0
	var right_count : int = 0
	for majin in active_majin:
		# Ignore airborne majin
		if majin.global_position.y > cpu_upper_bound.global_position.y:
			continue
		if majin.global_position.y < cpu_lower_bound.global_position.y:
			continue
		
		var priority : int = 5 if majin.is_bonus_majin else 1 # Prioritize bonus majin
		if majin.position.x < 0:
			left_count += priority
		else:
			right_count += priority
	if left_count == 0 && right_count == 0:
		return 0
	var target : int = -1 if left_count > right_count else 1
	if !is_inverted:
		target *= -1
	return target

func process_animation() -> void:
	var target_animation : String
	if current_rotation_speed > 0:
		target_animation = get_anim_prefix() + "push"
	elif current_rotation_speed < 0:
		target_animation = get_anim_prefix() + "pull"
	
	if !target_animation.is_empty() && character_animator.get_current_animation() != target_animation:
		character_animator.play_minigame_animation(target_animation, 0.1, 1.0, character_animator.get_animation_position())
	
	var speed_ratio : float = current_rotation_speed / MAX_ROTATION_SPEED
	speed_ratio *= ANIMATION_SPEED
	character_animator.set_speed(abs(speed_ratio))
	var spin_ratio : float = character_animator.get_animation_position() / character_animator.get_animation_length() 
	var handle_rotation : float = TAU * spin_ratio
	handle_rotation += PI * 0.5
	handle.rotation = Vector3.RIGHT * handle_rotation
	
	for cog in cogwheels:
		cog.rotation += Vector3.FORWARD * current_rotation_speed * get_physics_process_delta_time()

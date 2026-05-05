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
const TOTAL_SPAWN_TIME : float = 26
## Variance between each spawn time.
const SPAWN_TIME_VARIANCE : float = 0.2

@export var majin_scene : PackedScene
var majin_pool : Array[Node3D]

var is_demo_complete : bool
var is_inverted : bool

var current_rotation_speed : float
const ROTATION_ACCELERATION : float = 40.0
const ROTATION_DECCELERATION : float = 120.0
const MAX_ROTATION_SPEED : float = 5.0
const ANIMATION_SPEED : float = 3.0

func on_spawn_finished() -> void:
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

@rpc
func spawn_majin() -> void:
	var majin : Node3D = majin_pool[majin_spawn_index]
	var spawn_position_index : int = 0
	if is_demo_complete && randf() > 0.5:
		spawn_position_index = 1
	var majin_position : Vector3 = majin_spawn_positions[spawn_position_index].global_position
	majin.request_spawn(majin_position, majin_spawn_times[majin_spawn_index] < 0)
	majin_spawn_index += 1

func process_majin_spawn(delta : float) -> void:
	if majin_spawn_index >= majin_spawn_times.size():
		return
	
	majin_spawn_timer += delta
	if majin_spawn_timer > abs(majin_spawn_times[majin_spawn_index]):
		spawn_majin()

func _physics_process(delta: float) -> void:
	if !is_demo_complete:
		return
	
	var input : float = 0.0 if is_cpu() else get_horizontal_input()
	apply_input(input, delta)
	
	if is_multiplayer_authority() && !is_cpu():
		process_majin_spawn(delta)

## Applies an input when in demo mode.
func apply_demo_input(is_contacting_slime : bool, delta : float) -> void:
	var input : float = 0
	if is_contacting_slime:
		input = -1 if is_inverted else 1
	apply_input(input, delta)

## Applies the input to the cogwheel.
func apply_input(input : float, delta : float) -> void:
	var target_speed : float = input * MAX_ROTATION_SPEED
	var target_rotation : float = ROTATION_ACCELERATION
	if sign(target_speed) != sign(current_rotation_speed):
		target_rotation = ROTATION_DECCELERATION
	current_rotation_speed = move_toward(current_rotation_speed, target_speed, target_rotation * delta)
	process_animation(delta)

func process_animation(delta: float) -> void:
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
		cog.rotation += Vector3.FORWARD * current_rotation_speed * delta

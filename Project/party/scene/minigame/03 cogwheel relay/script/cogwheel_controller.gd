extends PartyGameCharacterSpawner

@export var cogwheels : Array[Node3D]
@export var majin_spawn_positions : Array[Node3D]
@export var handle : Node3D

## Total number of majin to spawn. Add 1 for the demo.
@export var total_majin_count : int = 47
## Total number of bonus majin to spawn.
@export var total_bonus_majin_count : int = 3
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

## Initialize the pool of majin.
func initialize_majin() -> void:
	for i in range(total_bonus_majin_count):
		var new_majin : Node3D = majin_scene.instantiate()
		add_child(new_majin)
		new_majin.set_multiplayer_authority(get_multiplayer_authority())
		new_majin.cogwheel = self
		new_majin.visible = false
		new_majin.set_process(false)
		new_majin.set_physics_process(false)
		majin_pool.append(new_majin)

@rpc
func spawn_majin() -> void:
	if majin_pool.size() == 0:
		print("ERROR: No majins left in the pool.")
		return
	
	var majin : Node3D = majin_pool[0]
	majin_pool.remove_at(0)
	var spawn_index : int = 0
	if is_demo_complete && randf() > 0.5:
		spawn_index = 1
	var majin_position : Vector3 = majin_spawn_positions[spawn_index].global_position
	majin.request_spawn(majin_position, false)

func _physics_process(delta: float) -> void:
	if !is_demo_complete:
		return
	
	var input : float = 0.0 if is_cpu() else get_horizontal_input()
	apply_input(input, delta)

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

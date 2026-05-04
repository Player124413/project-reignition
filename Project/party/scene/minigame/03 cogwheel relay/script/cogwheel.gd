extends PartyGameCharacterSpawner

@export var cogwheels : Array[Node3D]
@export var handle : Node3D

var current_rotation_speed : float
const ROTATION_ACCELERATION : float = 80.0
const ROTATION_DECCELERATION : float = 240.0
const MAX_ROTATION_SPEED : float = 15.0
const ANIMATION_SPEED : float = 3.0

func on_spawn_finished() -> void:
	character_animator.play_minigame_animation(get_anim_prefix() + "pull")
	character_animator.set_speed(0)
	if player_index % 2 == 1:
		get_node("DirectionAnimator").play("invert")

func _physics_process(delta: float) -> void:
	var input : float = get_horizontal_input()
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

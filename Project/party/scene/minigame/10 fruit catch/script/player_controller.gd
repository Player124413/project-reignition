extends PartyGameCharacterSpawner

@export var hand_end : Node3D
@export var pole : Node3D
@export var rapier_tip : Node3D
@export var lookat : LookAtModifier3D
@export var twist_disperser : BoneTwistDisperser3D
@export var two_bone_ik : TwoBoneIK3D
@export var copy_transform_modifier : CopyTransformModifier3D
var initial_transform : Transform3D

func on_spawn_finished() -> void:
	super()
	character_animator.play_animation("%s/wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	
	lookat.reparent(character_animator.skeleton)
	lookat.target_node = lookat.get_path_to(rapier_tip)
	twist_disperser.reparent(character_animator.skeleton)
	two_bone_ik.reparent(character_animator.skeleton)
	two_bone_ik.set_target_node(0, two_bone_ik.get_path_to(hand_end))
	two_bone_ik.set_pole_node(0, two_bone_ik.get_path_to(pole))
	copy_transform_modifier.reparent(character_animator.skeleton)
	copy_transform_modifier.set_reference_node(0, copy_transform_modifier.get_path_to(hand_end))
	initial_transform = hand_end.global_transform

func on_minigame_finished() -> void:
	super()
	hand_end.visible = false

var current_aim_pos : Vector2
var aim_speed : float = 3.0
const POSITION_FACTOR : float = 1.5
const MAX_ROTATION : Vector2 = Vector2(PI * 0.2, PI * 0.2)
const MIN_ROTATION : Vector2 = Vector2(PI * -0.2, PI * -0.1)
const HURT_TRIGGER_PARAMETER : StringName = "parameters/hurt_trigger/request"
const HURT_SEEK_PARAMETER : StringName = "parameters/hurt_seek/seek_request"

func start_demo() -> void:
	await get_tree().create_timer(NetworkManager.calculate_transition_tick()).timeout
	## TODO Spawn fruit and start demo
	MinigameManager.instance.request_minigame_start()
	

func get_input_suffix() -> String:
	return "1"

func _physics_process(_delta: float) -> void:
	if player_index != -1:
		return
	
	process_movement_tick()
	process_animation()

func process_movement_tick() -> void:
	current_aim_pos += Vector2(get_horizontal_input(), get_vertical_input()) * aim_speed * get_physics_process_delta_time()
	current_aim_pos = current_aim_pos.clamp(MIN_ROTATION, MAX_ROTATION)
	var aim_basis : Basis = initial_transform.basis
	aim_basis = aim_basis.rotated(Vector3.RIGHT, current_aim_pos.y)
	aim_basis = aim_basis.rotated(Vector3.UP, -current_aim_pos.x)
	aim_basis = aim_basis.orthonormalized()
	hand_end.global_basis = aim_basis
	
	var aim_position : Vector3 = initial_transform.origin
	aim_position.x += current_aim_pos.x * POSITION_FACTOR
	aim_position.y += current_aim_pos.y * POSITION_FACTOR
	hand_end.global_position = aim_position

func process_animation() -> void:
	pass

func disable_tree() -> void:
	character_animator.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

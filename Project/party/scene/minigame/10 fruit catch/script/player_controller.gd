extends PartyGameCharacterSpawner

@export var fruit_manager : Node3D

@export_group("Components")
@export var hand_end : Node3D
@export var pole : Node3D
@export var rapier_tip : Node3D
@export var lookat : LookAtModifier3D
@export var twist_disperser : BoneTwistDisperser3D
@export var two_bone_ik : TwoBoneIK3D
@export var copy_transform_modifier : CopyTransformModifier3D
@export var rollback_timer : RollbackTimer

@export_group("Stats")
@export var acceleration : float
@export var decceleration : float
var aim_speed : float = 3.0
var _move_speed : float
var _camera : Camera3D

var initial_transform : Transform3D
var _input : Vector2
var _previous_input : Vector2
var is_input_disabled : bool
var cpu_fruit_queue : Array[Node3D]

var current_aim_pos : Vector2
const POSITION_FACTOR : float = 1.2
const MAX_ROTATION : Vector2 = Vector2(PI * 0.3, PI * 0.35)
const MIN_ROTATION : Vector2 = Vector2(PI * -0.3, PI * -0.2)

func on_spawn_finished() -> void:
	super()
	if is_instance_valid(rollback_timer):
		rollback_timer.register_target(self)
	
	fruit_manager.set_player_index(player_index)
	fruit_manager.fruit_spawned.connect(Callable(self, "on_fruit_spawned"))
	
	character_animator.play_animation("%s/wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	
	_camera = get_viewport().get_camera_3d()
	
	lookat.reparent(character_animator.skeleton)
	lookat.target_node = lookat.get_path_to(rapier_tip)
	twist_disperser.reparent(character_animator.skeleton)
	two_bone_ik.reparent(character_animator.skeleton)
	two_bone_ik.set_target_node(0, two_bone_ik.get_path_to(hand_end))
	two_bone_ik.set_pole_node(0, two_bone_ik.get_path_to(pole))
	copy_transform_modifier.reparent(character_animator.skeleton)
	copy_transform_modifier.set_reference_node(0, copy_transform_modifier.get_path_to(hand_end))
	initial_transform = hand_end.global_transform
	if is_instance_valid(character_animator.data) && character_animator.data.model_size == PartyCharacterResource.MODEL_SIZES.SMALL:
		character_animator.position += Vector3.UP * 2 # Slightly lower for smaller models

func on_fruit_spawned(fruit : Node3D) -> void:
	cpu_fruit_queue.append(fruit)

func on_minigame_finished() -> void:
	if player_index != -1:
		super()
	hand_end.visible = false

func start_demo() -> void:
	if NetworkManager.is_hosting_game:
		fruit_manager.request_fruit_spawn()

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority() || player_index == -1:
		_input = get_input()
	process_invincibility()
	process_movement_tick()
	if player_index != -1 && is_multiplayer_authority():
		process_rollback()

#####################
### ROLLBACK CODE ###
#####################
const RB_POS : int = 0
const RB_SPD : int = 1
const RB_INPUT : int = 2
func on_rollback_applied(rb_params : Array) -> void:
	current_aim_pos = rb_params[RB_POS]
	_move_speed = rb_params[RB_SPD]
	_input = rb_params[RB_INPUT]

func process_rollback() -> void:
	rollback_timer.set_param(RB_POS, current_aim_pos)
	rollback_timer.set_param(RB_SPD, _move_speed)
	rollback_timer.set_param(RB_INPUT, _input)
	rollback_timer.process_rollback()

func process_movement_tick() -> void:
	if is_input_disabled:
		return
	
	var target_speed : float = _input.length() * aim_speed
	var delta : float = acceleration if target_speed > _move_speed else decceleration
	_move_speed = move_toward(_move_speed, target_speed, delta * get_physics_process_delta_time())
	current_aim_pos += _previous_input * _move_speed * get_physics_process_delta_time()
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

func get_input() -> Vector2:
	if !_input.is_zero_approx():
		_previous_input = _input.normalized()
	
	if !is_multiplayer_authority() && player_index != -1: # No input recieved. Use previous input.
		return _input
	
	if !is_cpu():
		return Vector2(get_horizontal_input(), get_vertical_input()).limit_length()
	
	var target_fruit : Node3D = get_target_fruit()
	if !is_instance_valid(target_fruit):
		return Vector2.ZERO
	
	var fruit_pos : Vector2 = _camera.unproject_position(target_fruit.global_position)
	var tip_pos : Vector2 = _camera.unproject_position(rapier_tip.global_position)
	var target_input : Vector2 = (fruit_pos - tip_pos)
	target_input *= 0.005
	target_input.y *= -1
	return target_input.limit_length()

@rpc("any_peer", "call_local", "reliable")
func take_damage(tick : float) -> void:
	is_input_disabled = true
	character_animator.play_minigame_animation("%s/hurt" % MinigameManager.ANIMATION_LIBRARY_PREFIX, 0.1, 1.0, 0.0, tick)

func process_animation_event(info : int) -> void:
	if info == 0:
		character_animator.play_animation("%s/wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true, 0.1)
		is_input_disabled = false
		request_invincibility()

func get_target_fruit() -> Node3D:
	while !cpu_fruit_queue.is_empty():
		if cpu_fruit_queue[0]._is_collected || cpu_fruit_queue[0].global_position.z > rapier_tip.global_position.z:
			cpu_fruit_queue.remove_at(0)
		else:
			return cpu_fruit_queue[0]
	return null

func disable_tree() -> void:
	if player_index == -1:
		spawn_position.visible = false
	else:
		super()

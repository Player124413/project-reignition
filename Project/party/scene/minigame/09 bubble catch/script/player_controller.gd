### The player controller for the butterfly catching minigame.
extends PartyGameCharacterMover

@export var hand_attachment : BoneAttachment3D
@export var bubble_maker_mesh : MeshInstance3D
@export var fill_mesh : MeshInstance3D
@export var trail_mesh : GPUParticles3D
@export var bubble_maker_materials : Array[Material]
@export var bubble_fill_materials : Array[Material]
@export var bubble_trail_materials : Array[ParticleProcessMaterial]
@export var bubble_parent : Node3D

var bubbles : Array[Node3D]
var is_demo_swing : bool

func start_demo() -> void:
	swing_power = 0
	is_demo_swing = true
	is_swing_active = true
	character_animator.play_minigame_animation(get_anim_prefix() + "swing-l", 0, 1.4, 0, NetworkTimeSynchronizer.get_time())

func pool_bubble(bubble : Node3D) -> void:
	bubbles.append(bubble)

@rpc("any_peer", "call_local", "reliable")
func spawn_bubble(pos : Vector3, size : int, tick : float) -> void:
	if size == 0 || bubbles.size() == 0: # No bubble :(
		return
	
	var bubble : Node3D = bubbles[0]
	bubbles.remove_at(0)
	bubble.spawn(pos, size, tick)
	is_swing_active = false

func on_spawn_finished() -> void:
	super()
	for bubble in bubble_parent.get_children():
		if bubble is Node3D:
			bubble.despawned.connect(Callable(self, "pool_bubble").bind(bubble))
			bubbles.append(bubble)
			bubble.update_material(player_index)
	hand_attachment.reparent(character_animator.skeleton)
	bubble_maker_mesh.material_override = bubble_maker_materials[player_index]
	fill_mesh.material_override = bubble_fill_materials[player_index]
	trail_mesh.process_material = bubble_trail_materials[player_index]

func on_minigame_finished() -> void:
	super()
	hand_attachment.visible = false

var swing_power : int
var is_swing_active : bool

func process_rotation(target_angle : float) -> void:
	if is_swing_active:
		return
	super(target_angle)

func process_speed() -> void:
	if is_swing_active:
		_move_speed = move_toward(_move_speed, 0, brake_friction * get_physics_process_delta_time())
		return
	super()

const ANIM_SHOT_FINISH : int = 0
const ANIM_BUBBLE_SIZE_SMALL : int = 1
const ANIM_BUBBLE_SIZE_MEDIUM : int = 2
const ANIM_BUBBLE_SIZE_LARGE : int = 3
const ANIM_BUBBLE_SPAWN : int = 4
const ANIM_TRAIL_START : int = 8
const ANIM_TRAIL_STOP : int = 9
const ANIM_STEP_LEFT : int = 10
const ANIM_STEP_RIGHT : int = 11
func process_animation() -> void:
	if is_swing_active:
		apply_movement_rotation()
		return
	super()

func process_animation_event(event : int) -> void:
	if event == ANIM_SHOT_FINISH: # Finished swinging
		is_swing_active = false
	elif event == ANIM_BUBBLE_SPAWN:
		# TODO Spawn bubble
		pass
	elif event >= ANIM_BUBBLE_SIZE_SMALL && event <= ANIM_BUBBLE_SIZE_LARGE:
		swing_power = event
		if is_demo_swing:
			if event == ANIM_BUBBLE_SIZE_LARGE:
				is_demo_swing = false
				rpc("spawn_bubble", bubble_parent.global_position, swing_power, NetworkTimeSynchronizer.get_time())
		elif is_cpu() && is_multiplayer_authority() && check_cpu_bubble_spawn():
			rpc("spawn_bubble", bubble_parent.global_position, swing_power, NetworkTimeSynchronizer.get_time())
	elif event == ANIM_TRAIL_START:
		trail_mesh.emitting = true
	elif event == ANIM_TRAIL_STOP:
		trail_mesh.emitting = false

func process_inputs() -> void:
	if is_swing_active:
		if !is_cpu():
			if Input.is_action_just_released("button_primary%s" % get_input_suffix()) || Input.is_action_just_released("button_secondary%s" % get_input_suffix()):
				rpc("spawn_bubble", bubble_parent.global_position, swing_power, NetworkTimeSynchronizer.get_time())
		return
	
	if !is_cpu():
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			rpc("start_swing", NetworkTimeSynchronizer.get_time(), 1)
		elif Input.is_action_just_pressed("button_secondary%s" % get_input_suffix()):
			rpc("start_swing", NetworkTimeSynchronizer.get_time(), -1)
	super()

################
### CPU CODE ###
################
var target_butterfly : Node3D
var cpu_swing_timer : float
const CPU_SWING_INTERVAL : float = 0.4
const CPU_SWING_INTERVAL_VARIANCE : float = 0.2
const CPU_SWING_RANGE : int = 6
const CPU_LEAD_AMOUNT : int = 8
@rpc("any_peer", "call_local", "reliable")
func update_target_butterfly(index : int) -> void:
	if index == -1:
		target_butterfly = null
		return
	target_butterfly = ButterflyManager.instance.butterflies[index]

func calculate_cpu_input() -> Vector2:
	if !is_instance_valid(target_butterfly) || !target_butterfly.is_cpu_targetable():
		if is_multiplayer_authority():
			rpc("update_target_butterfly", calculate_target_butterfly_index())
		return Vector2.ZERO
	
	if is_swing_active:
		return Vector2.ZERO
	
	var target_position : Vector3 = target_butterfly.global_position
	var diff : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if diff >= PlayerData.CPU_DIFFICULTY_ENUM.HARD:
		target_position += Vector3.FORWARD.rotated(Vector3.UP, _move_angle + PI * 0.5)
		if diff >= PlayerData.CPU_DIFFICULTY_ENUM.EXTREME: # Lead the butterfly
			target_position -= target_butterfly.root.basis.z * CPU_LEAD_AMOUNT
			target_position.x = clamp(target_position.x, -target_butterfly.SPAWN_BOUNDS, target_butterfly.SPAWN_BOUNDS)
	
	if is_multiplayer_authority():
		cpu_swing_timer = move_toward(cpu_swing_timer, 0, get_physics_process_delta_time())
		var remaining_distance : Vector3 = target_position - character_body.global_position
		remaining_distance.y = 0
		if is_zero_approx(cpu_swing_timer) && remaining_distance.length() < CPU_SWING_RANGE:
			cpu_swing_timer = CPU_SWING_INTERVAL
			if diff <= PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
				cpu_swing_timer += randf() * CPU_SWING_INTERVAL_VARIANCE
				rpc("start_swing", NetworkTimeSynchronizer.get_time(), 1 if randf() > 0.5 else -1)
			else:
				cpu_swing_timer += (1.0 - randf() * 2.0) * CPU_SWING_INTERVAL_VARIANCE
				remaining_distance = remaining_distance.rotated(Vector3.UP, -_move_angle)
				rpc("start_swing", NetworkTimeSynchronizer.get_time(), sign(remaining_distance.x))
			return Vector2.ZERO
	return cpu_chase_position(target_position)

func get_cpu_interval() -> float:
	return 0.0 # Don't use cpu intervals for this minigame

func check_cpu_bubble_spawn() -> bool:
	var diff : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.EASY:
		return randf() < 0.2
	elif diff == PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
		return randf() < 0.2 * swing_power # More chance to swing a big bubble
	else: # Always go for full power
		if swing_power == ANIM_BUBBLE_SIZE_LARGE:
			return true
	
	return false

## Select a random butterfly to chase.
func calculate_target_butterfly_index() -> int:
	var target_index : int = 0
	var diff : PlayerData.CPU_DIFFICULTY_ENUM = get_cpu_difficulty()
	if diff == PlayerData.CPU_DIFFICULTY_ENUM.EXTREME:
		target_index = randi_range(0, 1) # First attempt for the bonus butterflies
	else: # Look for any
		target_index = randi_range(0, ButterflyManager.instance.butterflies.size() - 1)
	var iteration : int = 0
	while iteration < ButterflyManager.instance.butterflies.size():
		if ButterflyManager.instance.butterflies[target_index].is_cpu_targetable():
			return target_index
		iteration += 1
		target_index = (target_index + 1) % ButterflyManager.instance.butterflies.size()
	return -1

@rpc("any_peer", "call_local", "reliable")
func start_swing(tick : float, dir : int) -> void:
	swing_power = 0
	is_swing_active = true
	var target_anim : StringName
	if dir == 1:
		target_anim = get_anim_prefix() + "swing-r"
	else:
		target_anim = get_anim_prefix() + "swing-l"
	character_animator.play_minigame_animation(target_anim, 0, 1.4, 0, tick)
	if is_multiplayer_authority() && is_cpu():
		if get_cpu_difficulty() < PlayerData.CPU_DIFFICULTY_ENUM.NORMAL: # Easier cpus jump to a different butterfly
			rpc("update_target_butterfly", -1)

func get_target_animation() -> StringName:
	var base : StringName = super()
	if base == "run":
		return "walk"
	return base

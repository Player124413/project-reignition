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

@rpc("any_peer", "call_local", "reliable")
func start_swing(tick : float, dir : int) -> void:
	swing_power = 0
	is_swing_active = true
	var target_anim : StringName
	if dir == 1:
		target_anim = get_anim_prefix() + "swing-r"
	else:
		target_anim = get_anim_prefix() + "swing-l"
	character_animator.rpc("play_minigame_animation", target_anim, 0, 1.4, 0, tick)

func get_target_animation() -> StringName:
	var base : StringName = super()
	if base == "run":
		return "walk"
	return base

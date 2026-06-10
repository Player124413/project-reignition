extends PartyGameCharacterSpawner

@export var stomach_attachment : BoneAttachment3D
@export var rapier_attachment : BoneAttachment3D
## The "default" position of the shoulder bone.
@export var shoulder_inherited_attachment : BoneAttachment3D
var initial_basis : Basis
## The bone attachment that overrides the shoulder's transform.
@export var shoulder_override_attachment : BoneAttachment3D

func on_spawn_finished() -> void:
	super()
	stomach_attachment.reparent(character_animator.skeleton)
	rapier_attachment.reparent(character_animator.skeleton)
	shoulder_inherited_attachment.reparent(character_animator.skeleton)
	initial_basis = shoulder_inherited_attachment.global_basis
	shoulder_override_attachment.external_skeleton = shoulder_override_attachment.get_path_to(character_animator.skeleton)
	character_animator.play_animation("%s/wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX)

func on_minigame_finished() -> void:
	super()
	rapier_attachment.visible = false

var current_aim_pos : Vector2
var aim_speed : float = 10.0
const MAX_ROTATION : Vector2 = Vector2(PI, PI * 0.2)
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
	current_aim_pos = current_aim_pos.clamp(-MAX_ROTATION, MAX_ROTATION)
	print(current_aim_pos)
	var aim_basis : Basis = initial_basis
	aim_basis = aim_basis.rotated(Vector3.RIGHT, current_aim_pos.y)
	aim_basis = aim_basis.rotated(Vector3.UP, -current_aim_pos.x)
	aim_basis = aim_basis.orthonormalized()
	shoulder_override_attachment.global_basis = aim_basis

func process_animation() -> void:
	pass

func disable_tree() -> void:
	character_animator.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

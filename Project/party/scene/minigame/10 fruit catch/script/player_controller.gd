extends PartyGameCharacterSpawner

@export var bone_attachment : BoneAttachment3D
func on_spawn_finished() -> void:
	super()
	initialize_animation_tree(get_anim_prefix(), []) # No need to relink animations bc the demo uses the same library
	bone_attachment.reparent(character_animator.skeleton)

func on_minigame_finished() -> void:
	super()
	bone_attachment.visible = false

var current_blend : Vector2
var aim_speed : float = 10.0
const BLEND_PARAMETER : StringName = "parameters/aim_blend/blend_position"
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
	current_blend += Vector2(get_horizontal_input(), get_vertical_input()) * aim_speed * get_physics_process_delta_time()

func process_animation() -> void:
	animation_tree.set(BLEND_PARAMETER, current_blend)

func disable_tree() -> void:
	character_animator.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

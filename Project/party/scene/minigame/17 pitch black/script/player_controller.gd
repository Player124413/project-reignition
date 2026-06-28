extends PartyGameCursorMover

@export var cursor: TextureRect
@export var cursor_label: Label
@export var cursor_correct: TextureRect
@export var cursor_incorrect: TextureRect
@export var cursor_animator: AnimationPlayer
@export var picture_manager: PictureManager
@export var spotlight: CSGCylinder3D
@export var hand_attachment: BoneAttachment3D
@export var lamp: Node3D
@export var collision: Area3D
var can_initiate_success = false
var is_demo_complete: bool = false
var spotlight_pos


func on_spawn_finished() -> void:
	super()
	hand_attachment.reparent(character_animator.skeleton)
	character_animator.play_animation("%s/light-wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	cursor_label.text = tr(character_animator.data.character_name)
	set_physics_process(true)
	spotlight_pos = spotlight.global_position.z
	cursor_min_clamp.x = 175
	cursor_min_clamp.y = 175
	cursor_max_clamp.x = get_viewport().get_visible_rect().size.x - 175
	cursor_max_clamp.y = get_viewport().get_visible_rect().size.y - 175

func process_movement_tick() -> void:
	if _state == STATE.IDLE:
		super()
	lamp.look_at(spotlight.global_position, Vector3.UP, true)
	collision.global_position = spotlight.global_position

	if !is_demo_complete:
		demo_movement()
	else:
		spotlight_movement()

func process_inputs() -> void:
	if !is_cpu() && _state == STATE.IDLE:
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			if can_initiate_success:
				start_success()
			else:
				start_miss()
	super()

const ANIM_MISS_START: int = 0
const ANIM_MISS_END: int = 1

func process_animation_event(event: int) -> void:
	if event == ANIM_MISS_START:
		_state = STATE.BUSY
	elif event == ANIM_MISS_END:
		_state = STATE.IDLE
	

func set_state(state: STATE):
	_state = state

func start_miss() -> void:
	character_animator.play_animation("%s/miss" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	cursor_animator.play("miss")
	cursor_incorrect.position = cursor.position
	#_state = STATE.BUSY
	

func start_success() -> void:
	cursor_animator.play("correct")
	cursor_correct.position = cursor.position
	picture_manager.play_correct_sequence()
	_state = STATE.BUSY

func complete_demo() -> void:
	is_demo_complete = true

func demo_movement() -> void:
	var pos_3d := spotlight.global_position
	var cam := get_viewport().get_camera_3d()
	var pos_2d := cam.unproject_position(pos_3d)
	cursor.global_position = pos_2d - cursor.size

func spotlight_movement() -> void:
	const RAY_LENGTH = 120
	var camera3d = get_viewport().get_camera_3d()
	var from = camera3d.project_ray_origin(cursor.position)
	var to = from + camera3d.project_ray_normal(cursor.position) * RAY_LENGTH

	to.z = spotlight_pos

	spotlight.global_position = to
	return


func _on_area_3d_area_exited(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		can_initiate_success = false


func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		can_initiate_success = true

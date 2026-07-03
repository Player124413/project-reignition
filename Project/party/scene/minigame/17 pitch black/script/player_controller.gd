class_name PicturePlayerController extends PartyGameCursorMover

@export var cursor: TextureRect
@export var cursor_label: Label
@export var cursor_correct: TextureRect
@export var cursor_incorrect: TextureRect
@export var cursor_animator: AnimationPlayer
@export var picture_manager: PictureManager
@export var spotlight: CSGCylinder3D
@export var hand_attachment: BoneAttachment3D
@export var lamp: Node3D
@export var lamp_light: OmniLight3D
@export var collision: Area3D
@export var sfx_wrong: GroupSfxPlayer
@export var sfx_correct: GroupSfxPlayer
var rng: RandomNumberGenerator
var can_initiate_success = false
var is_demo_complete: bool = false
var spotlight_pos
var camera : Camera3D

## How much the cursor can move relative to the picture manager (in 3d world coords).
const CLAMP_WORLD_EXTENTS : Vector3 = Vector3(65.0, 20.0, 0.0)

var _state: STATE
enum STATE {
	IDLE,
	BUSY,
	MOVE_ONLY,
	MISS
}

func on_spawn_finished() -> void:
	super()
	hand_attachment.reparent(character_animator.skeleton)
	character_animator.play_animation("%s/light-wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	cursor_label.text = tr(character_animator.data.character_name).to_upper()
	camera = get_viewport().get_camera_3d()
	set_physics_process(true)
	spotlight_pos = spotlight.global_position.z
	initialize_clamp_regions()
	rng = RandomNumberGenerator.new()

	if is_cpu():
		update_cpu_search_params()
		update_target_pos()

## Calculates how much to clamp the cursor by.
func initialize_clamp_regions() -> void:
	var world_pos : Vector3 = picture_manager.global_position + CLAMP_WORLD_EXTENTS
	var unprojected_pos : Vector2 = camera.unproject_position(world_pos)
	cursor_max_clamp.x = unprojected_pos.x
	cursor_min_clamp.y = unprojected_pos.y
	
	world_pos = picture_manager.global_position - CLAMP_WORLD_EXTENTS
	unprojected_pos = camera.unproject_position(world_pos)
	cursor_min_clamp.x = unprojected_pos.x
	cursor_max_clamp.y = unprojected_pos.y

func process_movement_tick() -> void:
	if _state == STATE.IDLE || _state == STATE.MOVE_ONLY:
		super()
	lamp.look_at(spotlight.global_position, Vector3.UP, true)
	collision.global_position = spotlight.global_position

	if !is_demo_complete:
		demo_movement()
	else:
		spotlight_movement()
		if is_cpu() && _state == STATE.IDLE:
			cpu_movement()

func process_inputs() -> void:
	if !is_demo_complete:
		return
	
	if !is_cpu() && _state == STATE.IDLE:
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			rpc("start_success" if can_initiate_success else "start_miss")
	super()

const ANIM_MISS_START: int = 0
const ANIM_MISS_END: int = 1

func process_animation_event(event: int) -> void:
	if event == ANIM_MISS_START:
		_state = STATE.MISS
	elif event == ANIM_MISS_END:
		if _state == STATE.MISS:
			_state = STATE.IDLE
		character_animator.play_animation("%s/light-wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)

@rpc("any_peer", "call_local", "reliable")
func start_miss() -> void:
	character_animator.play_voice("fail")
	sfx_wrong.play_in_group()
	character_animator.play_animation("%s/miss" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	cursor_animator.play("miss")
	cursor_incorrect.position = cursor.position
	
@rpc("any_peer", "call_local", "reliable")
func start_success() -> void:
	character_animator.play_voice("celebrate1")
	if is_demo_complete:
		var score_pos: Vector2 = score_counter.global_position
		score_pos.x = score_counter.global_position.x + (score_counter.size.x / 2)
		picture_manager.request_score_popup(player_index, 1, score_pos)
	sfx_correct.play_in_group()
	cursor_animator.play("correct")
	cursor_correct.position = cursor.position
	picture_manager.play_correct_sequence()

func complete_demo() -> void:
	is_demo_complete = true

func demo_movement() -> void:
	var pos : Vector2 = camera.unproject_position(spotlight.global_position)
	cursor.global_position = pos

func spotlight_movement() -> void:
	var z_depth : float = camera.global_position.z - spotlight.global_position.z
	var pos : Vector3 = camera.project_position(cursor.global_position, z_depth)
	pos.z = spotlight.global_position.z
	spotlight.global_position = pos

func _on_area_3d_area_exited(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		can_initiate_success = false

func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy"):
		can_initiate_success = true

#####################
### ROLLBACK CODE ###
#####################
const RB_STATE: int = 3
const RB_CPUSTATE: int = 4
const RB_CPUTARGET: int = 5

func on_rollback_applied(rb_params: Array) -> void:
	_state = rb_params[RB_STATE]
	_cpu_state = rb_params[RB_CPUSTATE]
	target_pos = rb_params[RB_CPUTARGET]
	super(rb_params)

func process_rollback() -> void:
	rollback_timer.set_param(RB_STATE, _state)
	rollback_timer.set_param(RB_CPUSTATE, _cpu_state)
	rollback_timer.set_param(RB_CPUTARGET, target_pos)
	super()

################
### CPU CODE ###
################
@export var cpu_search_timer: Timer
##The amount of time it takes for cpus to search before confirming
var CPU_SEARCH_TIME: float
##The chance the next target will be the correct answer. If this rng hits, then the cpu will always confirm
var CPU_CORRECT_CHANCE: int
##When CPU_CORRECT_CHANCE is triggered, this will turn to true
var CPU_CAN_CONFIRM: bool = false

var target_pos: Vector2 = Vector2.DOWN

var _cpu_state: CPU_STATE
enum CPU_STATE {
	WAITING, ## The CPU can't currently do anything
	SEARCHING ## The CPU is actively moving
}

##Lower difficulty CPUs will mess up more often, while higher difficulties will deliberate more before confirming a choice.
func update_target_pos() -> void:
	var random_pos_x: float = rng.randf_range(cursor_min_clamp.x, cursor_max_clamp.x)
	var random_pos_y: float = rng.randf_range(cursor_min_clamp.y, cursor_max_clamp.y)
	var random_pos = Vector2(random_pos_x, random_pos_y)
	target_pos = random_pos
	if can_cpu_search_correctly():
		target_pos = picture_manager.get_correct_picture_pos()
		CPU_CAN_CONFIRM = true

func update_cpu_search_params() -> void:
	match get_cpu_difficulty():
		PlayerData.CPU_DIFFICULTY_ENUM.EASY:
			CPU_SEARCH_TIME = randi_range(8, 11)
			CPU_CORRECT_CHANCE = 13
		PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
			CPU_SEARCH_TIME = randi_range(7, 10)
			CPU_CORRECT_CHANCE = 12
		PlayerData.CPU_DIFFICULTY_ENUM.HARD:
			CPU_SEARCH_TIME = randi_range(6, 9)
			CPU_CORRECT_CHANCE = 11
		PlayerData.CPU_DIFFICULTY_ENUM.EXTREME:
			CPU_SEARCH_TIME = randi_range(5, 8)
			CPU_CORRECT_CHANCE = 10

func set_cpu_timer_paused(value : bool) -> void:
	cpu_search_timer.paused = value

func cpu_movement() -> void:
	if _cpu_state == CPU_STATE.SEARCHING:
		request_cpu_position(target_pos)
	if cursor.global_position == target_pos:
		generate_new_target()

func can_cpu_search_correctly() -> bool:
	if rng.randi_range(1, CPU_CORRECT_CHANCE) == 1:
		return true
	return false

func generate_new_target() -> void:
	update_target_pos()

	if CPU_CAN_CONFIRM:
		cpu_search_timer.timeout.emit()

func _on_cpu_timer_timeout() -> void:
	if is_cpu() && _cpu_state == CPU_STATE.SEARCHING:
		_cpu_state = CPU_STATE.WAITING
		if _state == STATE.IDLE:
			rpc("start_success" if can_initiate_success else "start_miss")
		
		update_cpu_search_params()
		update_target_pos()
		cpu_search_timer.start(CPU_SEARCH_TIME)
		_cpu_state = CPU_STATE.SEARCHING

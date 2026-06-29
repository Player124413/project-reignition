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
@export var collision: Area3D
@export var cpu_timer: Timer

var rng: RandomNumberGenerator
var can_initiate_success = false
var is_demo_complete: bool = false
var spotlight_pos

var _state: STATE
enum STATE {
	IDLE,
	BUSY
}

func on_spawn_finished() -> void:
	super()
	hand_attachment.reparent(character_animator.skeleton)
	character_animator.play_animation("%s/light-wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	cursor_label.text = tr(character_animator.data.character_name).to_upper()
	set_physics_process(true)
	spotlight_pos = spotlight.global_position.z
	cursor_min_clamp.x = 175
	cursor_min_clamp.y = 175
	cursor_max_clamp.x = get_viewport().get_visible_rect().size.x - 200
	cursor_max_clamp.y = get_viewport().get_visible_rect().size.y - 200

	print("Cusor Min Clamp: " + str(cursor_min_clamp))
	print("Cusor Max Clamp: " + str(cursor_max_clamp))
	rng = RandomNumberGenerator.new()

	if is_cpu():
		update_cpu_search_params()
		update_target_pos()

func process_movement_tick() -> void:
	if _state == STATE.IDLE:
		super()
	lamp.look_at(spotlight.global_position, Vector3.UP, true)
	collision.global_position = spotlight.global_position

	if !is_demo_complete:
		demo_movement()
	else:
		spotlight_movement()
		if is_cpu() && CPU_CAN_SEARCH && _state == STATE.IDLE:
			cpu_movement()

func process_inputs() -> void:
	if !is_cpu() && _state == STATE.IDLE:
		if Input.is_action_just_pressed("button_primary%s" % get_input_suffix()):
			if can_initiate_success:
				start_success()
			else:
				start_miss()
	
	if is_cpu() && _state == STATE.IDLE:
		if CPU_DONE_SEARCHING:
			CPU_DONE_SEARCHING = false
			CPU_CAN_SEARCH = false

			
			if can_cpu_confirm():
				if can_initiate_success:
					start_success()
					update_cpu_search_params()
				else:
					start_miss()
			
			CPU_CONFIRM_CHANCE -= 1
			CPU_CONFIRM_CHANCE = clamp(CPU_CONFIRM_CHANCE, 1, 10)
			CPU_SEARCH_AMOUNT -= 1
			CPU_SEARCH_AMOUNT = clamp(CPU_SEARCH_AMOUNT, 0, 10)

			
			update_target_pos()


	super()

const ANIM_MISS_START: int = 0
const ANIM_MISS_END: int = 1

func process_animation_event(event: int) -> void:
	if event == ANIM_MISS_START:
		_state = STATE.BUSY
	elif event == ANIM_MISS_END:
		_state = STATE.IDLE
		character_animator.play_animation("%s/light-wait" % MinigameManager.ANIMATION_LIBRARY_PREFIX, true)
	

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
	#_state = STATE.BUSY

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


################
### CPU CODE ###
################

var target_pos: Vector2 = Vector2.DOWN
##How many times should a CPU change positions before finding the correct answer. The last search will always be the correct answer
var CPU_SEARCH_AMOUNT: int
##The chance a CPU will confirm when they reach the end of a search. The chance goes down with each successive search.
var CPU_CONFIRM_CHANCE: int
##The chance the next target will be the correct answer. If this rng hits, then the cpu will always confirm
var CPU_CORRECT_CHANCE: int
##Has the cpu reached the destination? If so, then pick a new destination.
var CPU_DONE_SEARCHING: bool = false
var CPU_CAN_SEARCH: bool = false

##Lower difficulty CPUs will mess up more often, while higher difficulties will deliberate more before confirming a choice.

func update_target_pos() -> void:
	var random_pos_x: float = rng.randf_range(cursor_min_clamp.x, cursor_max_clamp.x)
	var random_pos_y: float = rng.randf_range(cursor_min_clamp.y, cursor_max_clamp.y)
	var random_pos = Vector2(random_pos_x, random_pos_y)

	var correct: int = rng.randi_range(1, CPU_CORRECT_CHANCE)

	if CPU_SEARCH_AMOUNT != 0:
		target_pos = random_pos
	elif correct == 1 || CPU_SEARCH_AMOUNT == 0:
		target_pos = picture_manager.get_correct_picture_pos()
	
	print("NEXT CPU POS: " + str(target_pos))
	CPU_CAN_SEARCH = true
	cpu_timer.start()


func update_cpu_search_params() -> void:
	match get_cpu_difficulty():
		PlayerData.CPU_DIFFICULTY_ENUM.EASY:
			CPU_SEARCH_AMOUNT = rng.randi_range(6, 10) ## The CPU will search 5-9 times
			CPU_CONFIRM_CHANCE = 6 ## 1 in 5 chance for the cpu to confirm a choice
			CPU_CORRECT_CHANCE = 8 ## 1 in 7 chance the next target will be the correct one
		PlayerData.CPU_DIFFICULTY_ENUM.NORMAL:
			CPU_SEARCH_AMOUNT = rng.randi_range(5, 9)
			CPU_CONFIRM_CHANCE = 7
			CPU_CORRECT_CHANCE = 7
		PlayerData.CPU_DIFFICULTY_ENUM.HARD:
			CPU_SEARCH_AMOUNT = rng.randi_range(4, 7)
			CPU_CONFIRM_CHANCE = 8
			CPU_CORRECT_CHANCE = 6
		PlayerData.CPU_DIFFICULTY_ENUM.EXTREME:
			CPU_SEARCH_AMOUNT = rng.randi_range(3, 5)
			CPU_CONFIRM_CHANCE = 9
			CPU_CORRECT_CHANCE = 5

func cpu_movement() -> void:
	request_cpu_position(target_pos)
	if cursor.global_position == target_pos:
		CPU_DONE_SEARCHING = true
func can_cpu_confirm() -> bool:
	if rng.randi_range(1, CPU_CONFIRM_CHANCE) == 1:
		return true
	
	if CPU_SEARCH_AMOUNT == 0:
		return true

	return false

func can_cpu_search_correctly() -> bool:
	if rng.randi_range(1, CPU_CORRECT_CHANCE) == 1:
		return true
	
	return false


func _on_timer_timeout() -> void:
	CPU_SEARCH_AMOUNT -= 1
	CPU_SEARCH_AMOUNT = clamp(CPU_SEARCH_AMOUNT, 0, 10)
	update_target_pos()
	
	pass # Replace with function body.

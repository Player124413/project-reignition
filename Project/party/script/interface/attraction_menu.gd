### Manages the attraction menu.
extends Menu

@export var description : DescriptionBox
@export var selection_animator : AnimationPlayer
@export var attraction_animators : Array[AnimationPlayer]
@export var omochao : CharacterAnimator
@export var omochao_locations : Array[Node3D]
var current_omochao_location : int
var original_omochao_transform : Transform3D
var omochao_move_ratio : float
var omochao_turn_influence : float
const OMOCHAO_SPEED : float = 1.0
const OMOCHAO_TURN_SPEED : float = 10.0
const OMOCHAO_RETURN_SPEED : float = 5.0
var is_dialog_active : bool

func _ready() -> void:
	super()
	# TODO Make active immediately and skip intro animation if the menu is already active.
	for attraction : AnimationPlayer in attraction_animators:
		# Force reset the attraction animators
		attraction.play("RESET")
		attraction.advance(0.0)

func show_menu() -> void:
	super()
	current_selection = Vector2i(1, 0)
	selection_animator.play("RESET")
	selection_animator.advance(0.0)
	current_omochao_location = omochao_locations.size() - 1
	omochao_move_ratio = 1.0
	omochao.play_animation("select")
	is_dialog_active = true
	description.show_button()
	# TODO Add separate option for returning from a party game.
	description.set_text("party_attract_menu1")

func process_cursor() -> void:
	# Process position
	omochao_move_ratio = move_toward(omochao_move_ratio, 1.0, OMOCHAO_SPEED * get_physics_process_delta_time())
	var t : float = smoothstep(0.0, 1.0, omochao_move_ratio)
	var target_transform : Transform3D = omochao_locations[current_omochao_location].global_transform
	omochao.global_transform = original_omochao_transform.interpolate_with(target_transform, t)
	# Process turning TODO Improve this
	if is_equal_approx(1.0, omochao_move_ratio):
		omochao_turn_influence = move_toward(omochao_turn_influence, 0.0, OMOCHAO_RETURN_SPEED * get_physics_process_delta_time())
	else:
		omochao_turn_influence = move_toward(omochao_turn_influence, 1.0, OMOCHAO_TURN_SPEED * get_physics_process_delta_time())
	var look_at_basis : Basis = original_omochao_transform.looking_at(target_transform.origin, omochao.global_basis.y, true).basis
	omochao.global_basis = omochao.global_basis.slerp(look_at_basis, omochao_turn_influence)

func confirm() -> void:
	if is_dialog_active:
		# TODO Process dialog box
		if description.get_text() == "party_attract_menu2":
			is_dialog_active = false
			description.hide_button()
			update_cursor_position()
		else:
			description.set_text("party_attract_menu2")
		return

func cancel() -> void:
	if is_dialog_active:
		return
	
	description.set_text("party_attract_menu3")

func update_selection() -> void:
	var previous_selection : Vector2i = current_selection
	current_selection.x = clamp(current_selection.x + input_axis.x, 0, 2)
	current_selection.y = clamp(current_selection.y + input_axis.y, 0, 2)
	if current_selection.y >= 2:
		current_selection.x = 0
	elif previous_selection.y >= 2:
		current_selection.x = 1 # Select the middle option when returning from exit
	
	if current_selection != previous_selection:
		update_cursor_position()
		start_selection_timer()

func update_cursor_position() -> void:
	# TODO Change Omochao's target position and play animation
	var target_animation : StringName = "exit"
	if current_selection == Vector2i(0, 0):
		target_animation = "world-bazaar"
	elif current_selection == Vector2i(1, 0):
		target_animation = "tournament-palace"
	elif current_selection == Vector2i(2, 0):
		target_animation = "genie-lair"
	elif current_selection == Vector2i(0, 1):
		target_animation = "world-library"
	elif current_selection == Vector2i(1, 1):
		target_animation = "treasure-hunt"
	elif current_selection == Vector2i(2, 1):
		target_animation = "pirate-coast"
	
	omochao_move_ratio = 0.0
	omochao_turn_influence = 0.0
	original_omochao_transform = omochao.global_transform
	description.set_text("party_" + target_animation.replace("-", "_") + "_desc")
	current_omochao_location = current_selection.x + current_selection.y * 3
	selection_animator.play(target_animation, 0.05)

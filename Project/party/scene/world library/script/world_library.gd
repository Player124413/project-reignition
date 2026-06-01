extends Menu

@export var debug_minigame : MinigameResource

@export var description : DescriptionBox
@export_group("Default Submenu")
@export var default_page_root : Control
@export var default_parent : GridContainer
## Cursor used for the default menu.
@export var default_cursor : Control
@export var default_options : Array[Label]

@export_group("Minigame Submenu")
@export var minigame_page_root : Control
@export var minigame_option_list_parent : Control
## Cursor used for the minigame menu.
@export var minigame_cursor : Control

## The complete list of loaded minigames.
var minigame_list : Array[MinigameResource]
## The list of current minigames.
var current_minigame_list : Array[MinigameResource]
## List of selectable minigame options.
var minigame_option_list : Array[WLMinigameOption]
## Path to all standard minigame resources.
const MINIGAME_PATH : String = "res://party/resource/minigame/"
var max_minigame_selection : int

## Tracks whether the menu is loading from a minigame or not.
var is_loading_from_minigame : bool

var current_menu : SUBMENUS = SUBMENUS.DEFAULT
enum SUBMENUS {
	DEFAULT,
	ALL,
	RECORD,
	SURVIVAL,
	POINT,
	RACE,
	RANKINGS,
	CHARACTER,
	FINAL
}

var selection_type : SELECTION
enum SELECTION {
	CONFIRM,
	CANCEL,
	LEFT,
	RIGHT
}

func initialize() -> void:
	for child in minigame_option_list_parent.get_children():
		if child is WLMinigameOption:
			minigame_option_list.append(child)
	
	var dirAccess : DirAccess = DirAccess.open(MINIGAME_PATH)
	for file in dirAccess.get_files():
		var resource : Resource = ResourceLoader.load(MINIGAME_PATH + file)
		if resource is MinigameResource:
			minigame_list.append(resource)

func confirm() -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	rpc("start_confirm")

@rpc("any_peer", "call_local", "reliable")
func start_confirm() -> void:
	# For this current branch, we're just loading the mini-game immediately.
	if current_menu == SUBMENUS.DEFAULT:
		if current_selection != Vector2i(0, 0): # TODO Allow selecting other options
			return
		
		description.hide_description()
		selection_type = SELECTION.CONFIRM
		animator.play("left")
	elif current_menu == SUBMENUS.RANKINGS:
		pass
	elif current_menu == SUBMENUS.CHARACTER:
		pass
	elif NetworkManager.is_hosting_game: # Load the currently selected minigame
		var minigame_index : int = current_selection.x * minigame_option_list_parent.get_child_count()
		minigame_index += current_selection.y
		rpc("load_minigame", minigame_index)

func cancel() -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	rpc("start_cancel")

@rpc("any_peer", "call_local", "reliable")
func start_cancel() -> void:
	if current_menu == SUBMENUS.DEFAULT:
		if NetworkManager.is_hosting_game:
			NetworkManager.rpc("unload_scene", scene_file_path, NetworkManager.TRANSITION_TYPE_ENUM.ATTRACTION_SELECTOR)
		return
	
	selection_type = SELECTION.CANCEL
	animator.play("right")

func process_selection() -> void:
	default_page_root.visible = false
	minigame_page_root.visible = false
	
	if selection_type == SELECTION.CANCEL:
		process_cancel()
	else:
		process_confirm()

func process_confirm() -> void:
	if current_menu == SUBMENUS.DEFAULT:
		current_selection = Vector2i.ZERO # Reset to first entry in page
		current_menu = SUBMENUS.ALL # TODO Allow selecting other minigame categories
	
	if current_menu != SUBMENUS.DEFAULT: # TODO Account for ranking and records
		current_selection.y = 0 # Reset to first entry in page
		update_minigame_list()

func process_cancel() -> void:
	# Update the current selection based on the current submenu
	if current_menu == SUBMENUS.ALL:
		current_selection = Vector2i(0, 0)
	elif current_menu == SUBMENUS.RECORD:
		current_selection = Vector2i(1, 0)
	
	elif current_menu == SUBMENUS.SURVIVAL:
		current_selection = Vector2i(0, 1)
	elif current_menu == SUBMENUS.RANKINGS:
		current_selection = Vector2i(1, 1)
	
	elif current_menu == SUBMENUS.POINT:
		current_selection = Vector2i(0, 2)
	elif current_menu == SUBMENUS.CHARACTER:
		current_selection = Vector2i(1, 2)
	
	elif current_menu == SUBMENUS.RACE:
		current_selection = Vector2i(0, 3)
	elif current_menu == SUBMENUS.FINAL:
		current_selection = Vector2i(1, 3)
	update_default_cursor_selection()
	current_menu = SUBMENUS.DEFAULT
	default_page_root.visible = true

func update_minigame_list() -> void:
	# Build active minigame list
	current_minigame_list.clear()
	for minigame in minigame_list: # TODO Filter minigames by type
		current_minigame_list.append(minigame)
	
	max_minigame_selection = minigame_option_list.size()
	for i in minigame_option_list.size():
		var index : int = i + (minigame_option_list.size() * current_selection.x)
		minigame_option_list[i].visible = index < current_minigame_list.size()
		if minigame_option_list[i].visible:
			minigame_option_list[i].change_resource(current_minigame_list[index])
		else:
			max_minigame_selection -= 1
	
	current_selection.y = 0
	update_minigame_cursor_selection()
	minigame_page_root.visible = true

func update_selection() -> void:
	rpc("change_selection", input_axis)
	start_selection_timer()

@rpc("any_peer", "call_local", "reliable")
func change_selection(input : Vector2i) -> void:
	if current_menu == SUBMENUS.DEFAULT:
		var max_x : int = default_parent.columns
		@warning_ignore("integer_division")
		var max_y : int = default_parent.get_child_count() / max_x
		current_selection.x = (current_selection.x + input.x) % max_x
		current_selection.y = (current_selection.y + input.y) % max_y
		update_default_cursor_selection()
		description.set_text(default_options[current_selection.x + current_selection.y * max_x].text + "_desc")
	else: # TODO Add rankings and records
		if input.x != 0 && current_minigame_list.size() > minigame_option_list.size():
			var max_x : int = ceil(current_minigame_list.size() / (minigame_option_list.size() as float))
			selection_type = SELECTION.LEFT if input.x > 0 else SELECTION.RIGHT
			var old_selection : int = current_selection.x
			current_selection.x += input.x
			if current_selection.x < 0:
				current_selection.x = max_x - 1
			elif current_selection.x >= max_x:
				current_selection.x = 0
			if old_selection != current_selection.x:
				animator.play("left" if input.x > 0 else "right")
		elif input.y != 0:
			var old_selection : int = current_selection.y
			current_selection.y += input.y
			if current_selection.y < 0:
				current_selection.y = max_minigame_selection - 1
			elif current_selection.y >= max_minigame_selection:
				current_selection.y = 0
			if old_selection != current_selection.y:
				update_minigame_cursor_selection()

func update_default_cursor_selection() -> void:
	default_cursor.reparent(default_parent.get_child(current_selection.x + (current_selection.y * 2)), false)

func update_minigame_cursor_selection() -> void:
	minigame_cursor.reparent(minigame_option_list[current_selection.y], false)

func show_menu() -> void:
	super()
	if NetworkManager.attraction_loaded.is_connected(Callable(self, "show_menu")):
		NetworkManager.attraction_loaded.disconnect(Callable(self, "show_menu"))
	if is_loading_from_minigame: # Advance to the end of the animation
		animator.advance(animator.current_animation_length)
		is_loading_from_minigame = false # Return to normal state

func enable_processing() -> void:
	super()
	
	if current_menu == SUBMENUS.DEFAULT:
		description.show_description()

@rpc("any_peer", "call_local", "reliable")
func load_minigame(minigame_index : int) -> void:
	PartyManager.queued_minigame = minigame_list[minigame_index]
	is_loading_from_minigame = true # Store flag for return load
	hide_menu()
	disable_processing()
	RuleManager.cancelled.connect(Callable(self, "show_menu"), ConnectFlags.CONNECT_ONE_SHOT)
	RuleManager.show_menu()
	NetworkManager.attraction_loaded.connect(Callable(self, "show_menu"), ConnectFlags.CONNECT_ONE_SHOT)

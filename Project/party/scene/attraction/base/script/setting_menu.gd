class_name AttractionSettingMenu extends Menu

signal selection_changed (selection : Vector2i)
signal menu_finished

@export var cursor : Control
@export var options : Array[AttractionSettingOption]
@export var description : DescriptionBox
@export var description_prefix : String
@export var description_start_index : int = 2

func confirm() -> void:
	if current_selection.y == options.size() - 1:
		if NetworkManager.is_hosting_game:
			rpc("rpc_hide_menu")
		disable_processing()

func cancel() -> void:
	pass

func process_cursor() -> void:
	cursor.global_position = options[current_selection.y].global_position

func update_selection() -> void:
	var old_selection : int = current_selection.y
	if input_axis.y != 0:
		current_selection.y = (current_selection.y + input_axis.y) % options.size()
		if old_selection != current_selection.y:
			rpc("set_vertical_selection", current_selection.y)
			selection_changed.emit(current_selection)
			start_selection_timer()
		return
	
	if options[current_selection.y].option_count == 1:
		return
	old_selection = current_selection.x
	current_selection.x = (current_selection.x + input_axis.x) % options[current_selection.y].option_count
	if old_selection != current_selection.x:
		options[current_selection.y].rpc("set_selection", current_selection.x)
		selection_changed.emit(current_selection)
		start_selection_timer()

@rpc("any_peer", "call_local", "reliable")
func set_vertical_selection(selection : int) -> void:
	current_selection.y = selection
	current_selection.x = options[current_selection.y]._current_selection
	update_description_text()

func show_menu() -> void:
	super()
	for i in options.size():
		options[i].show_option()
	description.hide_button()
	description.show_description()
	update_description_text()
	current_selection.y = 0
	current_selection.x = options[0]._current_selection

func update_description_text() -> void:
	description.set_text(description_prefix + str(description_start_index + current_selection.y))

@rpc("any_peer", "call_local", "reliable")
func rpc_hide_menu() -> void:
	hide_menu()

func hide_menu() -> void:
	super()
	description.hide_description()
	for i in options.size():
		options[i].hide_option()
	menu_finished.emit()

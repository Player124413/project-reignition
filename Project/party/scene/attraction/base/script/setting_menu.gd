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
		hide_menu()
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
			current_selection.x = options[current_selection.y]._current_selection
			selection_changed.emit(current_selection)
			start_selection_timer()
		return
	
	if options[current_selection.y].option_count == 1:
		return
	old_selection = current_selection.x
	current_selection.x = (current_selection.x + input_axis.x) % options[current_selection.y].option_count
	if old_selection != current_selection.x:
		options[current_selection.y].set_selection(current_selection.x)
		selection_changed.emit(current_selection)
		start_selection_timer()

func show_menu() -> void:
	super()
	for i in options.size():
		options[i].show_option()
	current_selection.y = 0
	current_selection.x = options[0]._current_selection

func hide_menu() -> void:
	super()
	for i in options.size():
		options[i].hide_option()
	menu_finished.emit()

### Description/dialog box for party mode.
class_name DescriptionBox extends Menu

signal draw_started
signal draw_finished
## Emitted when the player selects "yes." 
signal confirmed
## Emitted when the player selects "no."
signal cancelled

@export var allow_canceling : bool = true
@export var label : Label
@export var draw_characters : bool
@export var cursor_animator : AnimationPlayer
var draw_timer : float = DRAW_INTERVAL
const DRAW_INTERVAL : float = 0.05
var _is_drawing : bool
var _is_menu_queued : bool

func process_cursor() -> void:
	if !draw_characters || !_is_drawing:
		return
	
	if is_action_just_pressed("button_primary", "sys_select", "ui_select"):
		rpc("finish_drawing")
		return
	
	draw_timer -= get_physics_process_delta_time()
	if draw_timer <= 0:
		draw_timer = DRAW_INTERVAL
		label.visible_characters += 1
		if label.visible_characters >= tr(label.text).length():
			rpc("finish_drawing")

@rpc("any_peer", "call_local", "reliable")
func finish_drawing() -> void:
	label.visible_characters = -1
	_is_drawing = false
	draw_finished.emit()
	if _is_menu_queued:
		_is_menu_queued = false
		show_confirmation(player_index)

func show_menu() -> void:
	if draw_characters:
		_is_menu_queued = true
		return
	super()

func get_text() -> String:
	return label.text

@rpc("any_peer", "call_local", "reliable")
func set_text(text : String, queue_menu : bool = false) -> void:
	label.text = text
	if draw_characters:
		_is_drawing = true
		_is_menu_queued = queue_menu
		label.visible_characters = 0
		draw_started.emit()

@rpc("any_peer", "call_local", "reliable")
func show_description() -> void:
	animator.play("init")
	animator.advance(0.0)
	animator.play("show")
	animator.advance(0.0)

func show_button() -> void:
	animator.play("show-button")
	animator.advance(0.0)

func hide_button() -> void:
	animator.play("hide-button")
	animator.advance(0.0)

@rpc("any_peer", "call_local", "reliable")
func hide_description() -> void:
	animator.play("hide")
	animator.seek(0, true)

func update_selection() -> void:
	if input_axis.y < 0:
		rpc("set_confirmation_selection", 0)
	elif input_axis.y > 0:
		rpc("set_confirmation_selection", 1)

func confirm() -> void:
	disable_processing()
	rpc("apply_selection", current_selection.y)

func cancel() -> void:
	if !allow_canceling:
		return
	disable_processing()
	rpc("apply_selection", 1)

@rpc("any_peer", "call_local", "reliable")
func apply_selection(selection : int) -> void:
	set_confirmation_selection(selection) # Switch to the correct selection if needed
	cursor_animator.play("select")
	if selection == 0:
		animator.play("select-yes")
		confirmed.emit()
	else:
		animator.play("select-no")
		cancelled.emit()

@rpc("any_peer", "call_local", "reliable")
func set_confirmation_selection(selection : int) -> void:
	if selection != current_selection.y:
		current_selection.y = selection
		cursor_animator.play("select-yes" if selection == 0 else "select-no")
		cursor_animator.advance(0.0)

@rpc("any_peer", "call_local", "reliable")
func show_confirmation(index : int) -> void:
	set_player_index(index)
	if draw_characters && _is_drawing:
		_is_menu_queued = true
		return
	current_selection.y = 1
	cursor_animator.play("RESET")
	cursor_animator.advance(0.0)
	cursor_animator.play("select-no")
	animator.play("show-confirmation")

## Disconnects all signals from the confirmation box.
func disconnect_all_signals() -> void:
	for connection in confirmed.get_connections():
		confirmed.disconnect(connection["callable"])
	for connection in cancelled.get_connections():
		cancelled.disconnect(connection["callable"])

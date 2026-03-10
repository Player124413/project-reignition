### Handles the interface for Online Connections.
extends Menu

## Nodes for selecting an option from the online menu.
@export var online_nodes : Array[Control]
@export var selection_label : SyncedLabel
@export var transition_label : SyncedLabel
@export var cursor : Control

## Is the player selection a connection option?
var is_connection_menu_active : bool = true
## Tracks whether the player is trying to be the host, join, or play offline.
var connection_mode_selection : int

## Localization keys for connection selection options.
var connection_values : Array[String] = [
	"party_offline",
	"party_host",
	"party_join",
]

func process_cursor() -> void:
	cursor.global_position = online_nodes[current_selection.y + current_selection.x].global_position

func update_selection() -> void:
	if is_connection_menu_active:
		update_connection_selection()
	else:
		update_online_selection()

## Updates selection for [host, join, offline] menu.
func update_connection_selection() -> void:
	if input_axis.x == 0:
		return
	start_selection_timer();
	connection_mode_selection += input_axis.x
	if connection_mode_selection > connection_values.size() - 1:
		connection_mode_selection = 0
	elif connection_mode_selection < 0:
		connection_mode_selection = connection_values.size() - 1
	
	transition_label.set_synced_text(selection_label.text)
	selection_label.set_synced_text(connection_values[connection_mode_selection])
	animator.play("select-left" if input_axis.x < 0 else "select-right")
	animator.seek(0.0)

## Updates selection for [address, port, connect] menu.
func update_online_selection() -> void:
	var previous_selection : Vector2i = current_selection
	current_selection.y = clamp(current_selection.y + input_axis.y, 0, online_nodes.size() - 2)
	if current_selection.y == online_nodes.size() - 2:
		current_selection.x = clamp(current_selection.x + input_axis.x, 0, 1)
	else:
		current_selection.x = 0
	if previous_selection != current_selection:
		start_selection_timer()

func confirm() -> void:
	if is_connection_menu_active:
		if connection_mode_selection == 0:
			# TODO Launch in offline mode
			return
		
		# Open online menu
		animator.play("host" if connection_mode_selection == 1 else "join")
		animator.advance(0.0)
		animator.play("show-online-menu")
		is_connection_menu_active = false
		return
	## TODO Process connection requests

func cancel() -> void:
	if is_connection_menu_active:
		# Return to main menu
		_is_menu_processing = false
		animator.play("return-to-main-menu")
		return
	
	# Return to connection mode selection
	is_connection_menu_active = true
	animator.play("hide-online-menu")

func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://interface/menu/Menu.tscn")

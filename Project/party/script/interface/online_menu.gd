### Handles the interface for Online Connections.
extends Menu

## Nodes for selecting an option from the online menu.
@export var online_nodes : Array[Control]
@export var address_edit : LineEdit
@export var room_edit : LineEdit
@export var selection_label : SyncedLabel
@export var transition_label : SyncedLabel
@export var cursor : Control

## Is the player selection a connection option?
var is_connection_menu_active : bool = true
## Tracks whether the player is trying to be the host, join, or play offline.
var connection_mode_selection : int

func get_max_vertical_selection() -> int:
	return online_nodes.size() - 2

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
	current_selection.y = clamp(current_selection.y + input_axis.y, 0, get_max_vertical_selection())
	if current_selection.y == get_max_vertical_selection():
		current_selection.x = clamp(current_selection.x + input_axis.x, 0, 1)
	else:
		current_selection.x = 0
	
	room_edit.release_focus()
	address_edit.release_focus()
	if online_nodes[current_selection.y] == address_edit:
		address_edit.grab_focus()
		address_edit.edit()
	elif online_nodes[current_selection.y] == room_edit and room_edit.editable:
		room_edit.grab_focus()
		room_edit.edit()
	else:
		grab_focus()
	
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
	if room_edit.has_focus() || address_edit.has_focus():
		return
	# Process connection requests
	if current_selection.y == get_max_vertical_selection():
		if current_selection.x == 1:
			connect_noray()

## Starts a connection to the Noray server.
func connect_noray() -> void:
	NetworkManager.is_hosting_game = connection_mode_selection == 1
	NetworkManager.start_network_signals()
	if !address_edit.text.is_empty():
		NetworkManager.address = address_edit.text
	if !room_edit.text.is_empty():
		NetworkManager.room_id = room_edit.text
	
	# Connect to server
	if NetworkManager.is_hosting_game:
		NetworkManager.host_connected.connect(_on_host_connected)
		NetworkManager.create_server_peer()
	else:
		NetworkManager.create_client_peer()

## Called when the host connects to Noray. Updates the GameID and allows players to copy room data.
func _on_host_connected() -> void:
	room_edit.text = NetworkManager.room_id

func cancel() -> void:
	if is_connection_menu_active:
		# Return to main menu
		_is_menu_processing = false
		animator.play("return-to-main-menu")
		return
	
	if room_edit.has_focus() || address_edit.has_focus():
		return
	# Return to connection mode selection
	is_connection_menu_active = true
	animator.play("hide-online-menu")

func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://interface/menu/Menu.tscn")

### Handles the interface for Online Connections.
extends Menu

## Nodes for selecting an option from the online menu.
@export var online_nodes : Array[Control]
@export var address_edit : LineEdit
@export var room_edit : LineEdit
@export var selection_label : SyncedLabel
@export var transition_label : SyncedLabel
@export var cursor : Control
@export var player_count_menu : Menu

## Is the player selection a connection option?
var is_connection_menu_active : bool = true
## Tracks whether the player is trying to be the host, join, or play offline.
var connection_mode_selection : int
## Is the player currently trying to connect?
var is_attempting_connection : bool

## Localization keys for connection selection options.
var connection_values : Array[String] = [
	"party_offline",
	"party_host",
	"party_join",
]

func show_menu() -> void:
	address_edit.text = NetworkManager.address
	super()

func process_cursor() -> void:
	cursor.global_position = online_nodes[current_selection.y + current_selection.x].global_position

func update_selection() -> void:
	if is_attempting_connection:
		return
	
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
	current_selection.y = clamp(current_selection.y + input_axis.y, 0, online_nodes.size() - 1)
	
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
	if is_attempting_connection:
		return
	
	if is_connection_menu_active:
		if connection_mode_selection == 0:
			# Offline is essentially a single host peer
			NetworkManager.is_hosting_game = true
			rpc("initialize_players")
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
	if current_selection.y == 2:
		process_copy_paste()
	elif current_selection.y == 3:
		connect_noray()
	elif NetworkManager.is_hosting_game && current_selection.y == 4:
		rpc("initialize_players")

## Processes the Copy/Paste button.
func process_copy_paste() -> void:
	if NetworkManager.is_hosting_game:
		var room_data_text : String = room_edit.text
		if !address_edit.text.is_empty():
			room_data_text = address_edit.text + "\n" + room_data_text
		DisplayServer.clipboard_set(room_data_text)
	else:
		var room_data : PackedStringArray = DisplayServer.clipboard_get().split('\n')
		if room_data.size() == 1:
			# Assume the player copied the room id if there's only 1 entry
			room_edit.text = room_data[0]
		elif room_data.size() == 2:
			address_edit.text = room_data[0]
			room_edit.text = room_data[1]

@rpc("authority", "call_local", "reliable")
func initialize_players() -> void:
	PartyManager.initialize_offline_player_data()
	if NetworkManager.is_online:
		PartyManager.connect("players_initialized", show_player_count_menu, CONNECT_ONE_SHOT)
		if NetworkManager.is_hosting_game:
			PartyManager.initialize_online_player_data()
	else:
		# Launch into offline mode
		show_player_count_menu()

func show_player_count_menu() -> void:
	player_count_menu.show_menu()
	hide_menu()
	disable_processing()

## Starts a connection to the Noray server.
func connect_noray() -> void:
	is_attempting_connection = true # Lockout menu inputs
	NetworkManager.is_hosting_game = connection_mode_selection == 1
	NetworkManager.start_network_signals()
	if !address_edit.text.is_empty():
		NetworkManager.address = address_edit.text
	if !room_edit.text.is_empty():
		NetworkManager.room_id = room_edit.text
	
	# Connect to server
	if NetworkManager.is_hosting_game:
		if !NetworkManager.host_connected.is_connected(_on_host_connected):
			NetworkManager.host_connected.connect(_on_host_connected)
		NetworkManager.create_server_peer()
	else:
		NetworkManager.create_client_peer()

## Called when the host connects to Noray. Updates the GameID and allows players to copy room data.
func _on_host_connected() -> void:
	room_edit.text = NetworkManager.room_id

func cancel() -> void:
	if is_attempting_connection:
		return
	
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
	NetworkManager.force_disconnect() # Force disconnect from online mode

func return_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://interface/menu/Menu.tscn")

func _enter_tree() -> void:
	NetworkManager.connect("connection_attempt_finished", Callable.create(self, "finish_connection_attempt"))

func _exit_tree() -> void:
	NetworkManager.disconnect("connection_attempt_finished", Callable.create(self, "finish_connection_attempt"))

func finish_connection_attempt(err : Error) -> void:
	if err != OK:
		NetworkManager.log_message(tr("network_error").replace("0", error_string(err)))
	is_attempting_connection = false

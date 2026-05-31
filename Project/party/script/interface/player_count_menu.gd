### Handles setting up the number of players.
extends Menu

@export var online_menu : Menu
@export var character_select_menu : Menu
@export var player_count_options : Array[Control]

func show_menu() -> void:
	super()
	for player in player_count_options:
		player.initialize()

func update_selection() -> void:
	if input_axis.x == 0:
		return
	# Add and remove players
	var cpu_index : int = PartyManager.get_first_player_index_device(0)
	if input_axis.x > 0 && cpu_index < player_count_options.size() && cpu_index != -1:
		# Only add players if there's a cpu slot to replace
		start_selection_timer()
		if NetworkManager.is_hosting_game:
			add_player(1)
		else:
			rpc("request_add_player", multiplayer.get_unique_id())
	elif input_axis.x < 0 && PartyManager.get_player_count_device(multiplayer.get_unique_id()) > 1:
		# Only remove players when there's at least one player left connected to this device
		start_selection_timer()
		if NetworkManager.is_hosting_game:
			remove_player(1)
		else:
			rpc("request_remove_player", multiplayer.get_unique_id())

func confirm() -> void:
	if !NetworkManager.is_hosting_game:
		return
	rpc("open_character_select_menu")

func cancel() -> void:
	if !NetworkManager.is_hosting_game:
		return
	rpc("show_online_menu")

@rpc("authority", "call_local", "reliable")
func show_online_menu() -> void:
	online_menu.show_menu()
	hide_menu()
	disable_processing()

# Adds a player for this device.
@rpc("authority", "call_local", "reliable")
func add_player(device : int) -> void:
	var data_index : int = PartyManager.get_first_player_index_device(0)
	var local_player_index : int = PartyManager.get_player_count_device(device) + 1
	var first_index : int
	if NetworkManager.is_online:
		first_index = PartyManager.get_first_player_index_device(device)
		first_index = PartyManager.get_player_data(first_index).player_index
	else:
		first_index = PartyManager.get_first_player_index_device(0)
	
	if !NetworkManager.is_hosting_game:
		return
	
	PartyManager.rpc("set_player_indexes", data_index, first_index, device, local_player_index)
	for i in range(data_index + 1, PartyManager.MAX_PLAYER_COUNT):
		var player_data : PlayerData = PartyManager.get_player_data(i)
		PartyManager.rpc("set_player_indexes", i, player_data.player_index - 1, player_data.device, player_data.local_player_index)
	player_count_options[data_index].rpc("switch_animation")
	rpc("redraw_players")

# Removes a player from this device.
@rpc("authority", "call_local", "reliable")
func remove_player(device : int) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	var last_index : int = PartyManager.get_last_player_index_device(device) # Select the last player
	var cpu_count : int = PartyManager.get_player_count_device(0)
	for i in range(last_index, PartyManager.MAX_PLAYER_COUNT - 1):
		# Shift all players down by one 
		var next_player_data : PlayerData = PartyManager.get_player_data(i + 1)
		player_count_options[i].rpc("switch_animation")
		PartyManager.rpc("set_player_indexes", i, next_player_data.player_index, next_player_data.device, next_player_data.local_player_index)
	player_count_options[PartyManager.MAX_PLAYER_COUNT - 1].rpc("switch_animation")
	PartyManager.rpc("set_player_indexes", PartyManager.MAX_PLAYER_COUNT - 1, cpu_count, 0, 1)
	rpc("redraw_players")

@rpc("authority", "call_local", "reliable")
func open_character_select_menu() -> void:
	disable_processing()
	hide_menu()
	character_select_menu.show_menu()

## RPC call for the host to add a player for a device.
@rpc("any_peer", "call_local", "reliable")
func request_add_player(device : int) -> void:
	# Only allow the host to change players
	if !NetworkManager.is_hosting_game || !_is_menu_processing:
		return
	rpc("add_player", device)

## RPC call for the host to remove a player for a device.
@rpc("any_peer", "call_local", "reliable")
func request_remove_player(device : int) -> void:
	# Only allow the host to change players
	if !NetworkManager.is_hosting_game || !_is_menu_processing:
		return
	rpc("remove_player", device)

@rpc("authority", "call_local", "reliable")
func redraw_players() -> void:
	for option in player_count_options:
		option.update_text()

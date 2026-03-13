### Menu to handle selecting characters.
extends Menu

@export var player_count_menu : Menu

## References
@export var cursors : Array[Control]
@export var previews : Array[Control]
@export var portrait_parent : HBoxContainer
@export var portrait_scene : PackedScene
var portraits : Array[Control]

## Number of rows for the portraits.
const PORTRAIT_ROWS : int = 2

func _ready() -> void:
	super()
	for cursor in cursors:
		cursor.moved.connect(recieve_cursor_movement)
		cursor.confirmed.connect(recieve_cursor_confirm)
		cursor.cancelled.connect(recieve_cursor_cancel)
	
	for preview in previews:
		preview.confirmed.connect(recieve_difficulty_confirm)
		preview.cancelled.connect(recieve_difficulty_cancel)
	
	initialize_portraits()

func initialize_portraits() -> void:
	@warning_ignore("integer_division")
	var column_count : int = PartyManager._character_data.size() / PORTRAIT_ROWS
	for i in column_count:
		var column_container : VBoxContainer = VBoxContainer.new()
		column_container.add_theme_constant_override("separation", portrait_parent.get_theme_constant("separation"))
		portrait_parent.add_child(column_container)
	
	for i in PartyManager._character_data.size():
		var new_portrait : Control = create_portrait(PartyManager._character_data[i])
		portraits.append(new_portrait)
		@warning_ignore("integer_division")
		portrait_parent.get_child(i / PORTRAIT_ROWS).add_child(new_portrait)
	# Add an extra portrait for random selections
	var random_portrait : Control = create_portrait(null)
	portraits.append(random_portrait)
	portrait_parent.add_child(random_portrait)

func create_portrait(character_data : PartyCharacterResource) -> Control:
	var portrait : Control = portrait_scene.instantiate() as Control
	portrait.linked_character = character_data
	return portrait

func recieve_cursor_movement(index : int, direction : Vector2i) -> void:
	var cursor_selection : Vector2i = cursors[index].current_selection + direction
	# Wrap selection around portraits
	var silent_movement : bool = false
	@warning_ignore("integer_division")
	var portrait_columns : int = portraits.size() / PORTRAIT_ROWS
	if cursors[index].current_selection.x == portrait_columns:
		# Don't update visual positions when selecting up/down on the random button
		silent_movement = direction.x == 0
		cursor_selection.y = clamp(cursor_selection.y, 0, PORTRAIT_ROWS - 1)
	elif cursor_selection.y < 0 || cursor_selection.y > PORTRAIT_ROWS - 1:
		cursor_selection.y -= sign(cursor_selection.y) * PORTRAIT_ROWS
	if cursor_selection.x < 0 || cursor_selection.x > portrait_columns:
		cursor_selection.x -= sign(cursor_selection.x) * (portrait_columns + 1)
	cursors[index].rpc("set_current_selection", cursor_selection) # Update the cursor's selection property
	if silent_movement:
		cursors[index].set_deferred("scroll_timer", 0)
	else:
		var portrait : Control = get_portrait(cursor_selection)
		rpc("update_cursor_position", index, cursor_selection)
		previews[cursors[index].port_index].rpc("set_character_text", "" if portrait.linked_character == null else portrait.linked_character.character_name)

func recieve_cursor_confirm(index : int) -> void:
	rpc("request_character_selection", index)

func recieve_cursor_cancel(index : int) -> void:
	rpc("request_character_cancellation", index)

## Tries to confirm a player's selection.
@rpc("any_peer", "call_local", "reliable")
func request_character_selection(index : int) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	var portrait : Control = get_portrait(cursors[index].current_selection)
	var character_data : PartyCharacterResource = portrait.linked_character
	if character_data == null:
		print("Selecting Random is not implemented yet.")
		cursors[index].rpc("request_enable_processing")
		return
	
	if !PartyManager.is_character_available(character_data):
		# Character is already taken; allow cursor movement again
		cursors[index].rpc("request_enable_processing")
		return
	
	# Set the player's character data.
	# Must be done through a look-up as references break over rpc calls
	var port_index : int = cursors[index].port_index
	PartyManager.rpc("set_character_data", port_index, character_data.character_name)
	portrait.rpc("select", port_index)
	previews[port_index].rpc("select")
	
	var player_data : PlayerData = PartyManager.get_player_data(port_index)
	if player_data.is_cpu_player():
		# Show CPU difficulty selection
		previews[port_index].rpc("show_difficulty", player_data.local_player_index, cursors[index].get_multiplayer_authority(), index)
		return
	advance_cursor_port(index)

## Tries to cancel a player's selection.
@rpc("any_peer", "call_local", "reliable")
func request_character_cancellation(index : int) -> void:
	if !NetworkManager.is_hosting_game:
		return
	
	var port_index : int = cursors[index].port_index
	var player_data : PlayerData = PartyManager.get_player_data(port_index)
	if player_data.character_data == null:
		# Nothing was selected to begin with
		if player_data.is_cpu_player():
			unadvance_cursor_port(index)
		elif cursors[index].is_multiplayer_authority() && port_index == 0:
			rpc("show_player_count_menu") # Return to the previous menu (only works on the host)
			for i in PartyManager.MAX_PLAYER_COUNT:
				# Reset all character data
				PartyManager.rpc("set_character_data", i, "")
		else:
			cursors[index].rpc("request_enable_processing")
		return
	var selection : Vector2i = get_portrait_selection_from_data(player_data.character_data)
	var portrait : Control = get_portrait(selection)
	cursors[index].rpc("set_current_selection", selection)
	rpc("update_cursor_position", index, selection)
	portrait.rpc("deselect")
	previews[port_index].rpc("deselect")
	PartyManager.rpc("set_character_data", port_index, "") # Clear player data

@rpc("any_peer", "call_local", "reliable")
func update_cursor_position(index : int, portrait_index : Vector2i) -> void:
	cursors[index].set_cursor_position(get_portrait(portrait_index).get_cursor_position())

## Updates (or disables if no ports are left to configure) a cursor to select the next player's port.
func advance_cursor_port(index : int) -> void:
	var next_port : int = cursors[index].port_index + 1
	for i in cursors.size():
		if cursors[i].is_processing_inputs && cursors[i].port_index >= next_port:
			next_port = cursors[i].port_index + 1
	if next_port >= PartyManager.MAX_PLAYER_COUNT:
		cursors[index].rpc("hide_cursor")
	else:
		var portrait : Control = get_portrait(cursors[index].current_selection)
		cursors[index].rpc("set_player_tag", next_port)
		rpc("update_cursor_position", index, cursors[index].current_selection)
		previews[next_port].rpc("set_character_text", "" if portrait.linked_character == null else portrait.linked_character.character_name)

## Moves a cursor back a port.
func unadvance_cursor_port(index : int) -> void:
	previews[cursors[index].port_index].rpc("set_character_text", "")
	var current_port_index : int = cursors[index].port_index - 1
	while (current_port_index >= 0):
		var player_data : PlayerData = PartyManager.get_player_data(current_port_index)
		if player_data.is_cpu_player() || (player_data.device == cursors[index].get_multiplayer_authority() && player_data.local_player_index == cursors[index].controller_index):
			# Found the port to revert to
			break
		current_port_index -= 1
	
	cursors[index].rpc("set_player_tag", current_port_index)
	rpc("request_character_cancellation", index)

## Handles CPU difficulty inputs
func recieve_difficulty_confirm(index : int, difficulty : int, cursor_index : int) -> void:
	rpc("request_difficulty_selection", index, difficulty, cursor_index)

func recieve_difficulty_cancel(cursor_index : int) -> void:
	rpc("request_character_cancellation", cursor_index)

@rpc("any_peer", "call_local", "reliable")
func request_difficulty_selection(index : int, difficulty : int, cursor_index : int) -> void:
	if !NetworkManager.is_hosting_game:
		return
	PartyManager.rpc("set_difficulty", index, difficulty)
	previews[index].rpc("set_player_text", "") # Empty string means use the current difficulty selection
	advance_cursor_port(cursor_index)

@rpc("authority", "call_local", "reliable")
func show_player_count_menu() -> void:
	hide_menu()
	disable_processing()
	player_count_menu.show_menu()

func show_menu() -> void:
	for cursor in cursors:
		cursor.initialize()
	for portrait in portraits:
		portrait.initialize()
	for preview in previews:
		preview.initialize()
	super()

## Shows all the character portraits
func show_portraits() -> void:
	var delay : float = 0.5 / portraits.size()
	for i in range(0, portraits.size()):
		portraits[i].show_portrait(delay * i)

## Shows all the previews
func show_previews() -> void:
	for preview in previews:
		preview.show_preview()

## Shows all the cursors and places them in the correct positions
func show_cursors() -> void:
	if !NetworkManager.is_hosting_game:
		return
	var cpu_index = PartyManager.get_first_player_index_device(0)
	var last_index = cpu_index if cpu_index != -1 else PartyManager.MAX_PLAYER_COUNT
	for i in last_index:
		var selection : Vector2i = Vector2i.RIGHT * i
		var portrait : Control = get_portrait(selection)
		cursors[i].rpc("set_current_selection", selection)
		rpc("update_cursor_position", i, selection)
		cursors[i].rpc("set_player_tag", i)
		previews[i].rpc("set_character_text", "" if portrait.linked_character == null else portrait.linked_character.character_name)

## Returns the portrait given its position on the selection grid.
func get_portrait(selection : Vector2i) -> Control:
	var index : int = selection.y + selection.x * PORTRAIT_ROWS
	index = clamp(index, 0, portraits.size() - 1)
	return portraits[index]

## Returns the portrait given its position on the selection grid.
func get_portrait_selection_from_data(character_data : PartyCharacterResource) -> Vector2i:
	for portrait in portraits:
		if portrait.linked_character == character_data:
			return Vector2i(portrait.get_parent().get_index(), portrait.get_index())
	return Vector2i.MIN

extends Menu

## Emitted when the minigame is cancelled (World Library only)
signal cancelled

@export var description : DescriptionBox
@export var back_button : Control
@export var minigame_name : Label
@export var minigame_thumbnail : TextureRect
var _max_selection : int

func show_menu() -> void:
	super()
	set_player_index(0) # Rules always use the first player's controller.
	
	minigame_name.text = tr(PartyManager.queued_minigame.localization_key)
	var index : int = minigame_name.text.find("!")
	if index == -1:
		index = minigame_name.text.find("！") # Search for fullspace exclamation
	if index != -1:
		minigame_name.text = minigame_name.text.insert(index + 1, '\n')
	
	minigame_thumbnail.texture = PartyManager.queued_minigame.thumbnail
	
	back_button.visible = PartyManager.current_mode == PartyManager.CURRENT_MODE_ENUM.WORLD_LIBRARY
	
	current_selection.x = 0
	_max_selection = PartyManager.queued_minigame.description_count - 1
	if _max_selection != 0:
		_max_selection += 1
		current_selection.x += 1
	
	description.set_text(get_description(current_selection.x))
	description.hide_button()
	description.show_description()

func update_selection() -> void:
	if input_axis.x == 0 || _max_selection == 0:
		return
	
	var old_selection : int = current_selection.x
	current_selection.x += input_axis.x
	if current_selection.x < 1:
		current_selection.x = _max_selection
	elif current_selection.x > _max_selection:
		current_selection.x = 1
	if old_selection != current_selection.x:
		rpc("update_description", current_selection.x)
		start_selection_timer()

@rpc("any_peer", "call_local", "reliable")
func update_description(selection : int) -> void:
	current_selection.x = selection
	description.set_text(get_description(current_selection.x))

func get_description(index : int) -> String:
	var localization_key : String = PartyManager.queued_minigame.localization_key
	if index != 0:
		localization_key += str(index)
	localization_key += "_desc"
	return localization_key

func pause() -> void:
	rpc("load_minigame")
	disable_processing()

func cancel() -> void:
	if !back_button.visible:
		return
	rpc("cancel_minigame")
	disable_processing()

@rpc("any_peer", "call_local", "reliable")
func cancel_minigame() -> void:
	hide_menu()
	await get_tree().create_timer(0.5).timeout
	cancelled.emit()
	disconnect_signals()

@rpc("any_peer", "call_local", "reliable")
func load_minigame() -> void:
	hide_menu()
	disable_processing()
	if NetworkManager.is_hosting_game:
		NetworkManager.rpc("load_scene", PartyManager.queued_minigame.scene_path, NetworkManager.TRANSITION_TYPE_ENUM.PARTY_GAME)

func disconnect_signals() -> void:
	for connection in cancelled.get_connections():
		cancelled.disconnect(connection["callable"])

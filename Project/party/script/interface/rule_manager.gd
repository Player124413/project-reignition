extends Menu

## Emitted when the minigame is cancelled (World Library only)
signal cancelled
var minigame_path : String

func set_minigame(path : String) -> void:
	minigame_path = path

func show_menu() -> void:
	super()
	set_player_index(0) # Rules always use the first player's controller.

func confirm() -> void:
	rpc("load_minigame")
	disable_processing()

func cancel() -> void:
	if PartyManager.current_mode != PartyManager.CURRENT_MODE_ENUM.WORLD_LIBRARY:
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
	await get_tree().create_timer(0.5).timeout
	if NetworkManager.is_hosting_game:
		NetworkManager.rpc("load_scene", minigame_path, NetworkManager.TRANSITION_TYPE_ENUM.PARTY_GAME)

func disconnect_signals() -> void:
	for connection in cancelled.get_connections():
		cancelled.disconnect(connection["callable"])

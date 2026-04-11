extends Menu

@export_file_path("*.tscn") var minigame_scene : String

func confirm() -> void:
	# TODO Use Submenus.
	# For this current branch, we're just loading the mini-game immediately.
	rpc("load_minigame")


@rpc("any_peer", "call_local", "reliable")
func load_minigame() -> void:
	hide_menu()
	disable_processing()
	if NetworkManager.is_hosting_game:
		NetworkManager.rpc("load_scene", minigame_scene, NetworkManager.TRANSITION_TYPE_ENUM.PARTY_GAME)

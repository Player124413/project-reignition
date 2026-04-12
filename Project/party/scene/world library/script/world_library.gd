extends Menu

@export var debug_minigame : MinigameResource
var load_from_minigame : bool

func confirm() -> void:
	# TODO Use Submenus.
	# For this current branch, we're just loading the mini-game immediately.
	rpc("load_minigame")

func show_menu() -> void:
	super.show_menu()
	if load_from_minigame: # Advance to the end of the animation
		animator.advance(animator.current_animation_length)

@rpc("any_peer", "call_local", "reliable")
func load_minigame() -> void:
	hide_menu()
	disable_processing()
	load_from_minigame = true # Store flag for return load
	NetworkManager.attraction_loaded.connect(Callable(self, "show_menu"), ConnectFlags.CONNECT_ONE_SHOT)
	if NetworkManager.is_hosting_game:
		NetworkManager.rpc("load_scene", debug_minigame.scene_path, NetworkManager.TRANSITION_TYPE_ENUM.PARTY_GAME)

### Handles signals on the base PartyMenu.tscn.
class_name PartyMenu extends Control

static var instance : PartyMenu

func _init() -> void:
	instance = self

func _ready() -> void:
	NetworkManager.attraction_loaded.connect(Callable(self, "disable"), CONNECT_ONE_SHOT)
	NetworkManager.attraction_unloaded.connect(Callable(self, "enable"))

func _exit_tree() -> void:
	if NetworkManager.attraction_loaded.is_connected(Callable(self, "disable")):
		NetworkManager.attraction_loaded.disconnect(Callable(self, "disable"))

## Disables main Party Menu.
func disable() -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	
	visible = false
	set_process_mode(Node.PROCESS_MODE_DISABLED)

## Re-enables and shows the main Party Menu.
func enable() -> void:
	NetworkManager.attraction_loaded.connect(Callable(self, "disable"), CONNECT_ONE_SHOT)
	visible = true
	set_process_mode(Node.PROCESS_MODE_INHERIT)

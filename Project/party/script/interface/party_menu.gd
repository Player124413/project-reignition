### Handles signals on the base PartyMenu.tscn.
class_name PartyMenu extends Control

static var instance : PartyMenu

func _init() -> void:
	instance = self

func _ready() -> void:
	NetworkManager.attraction_started.connect(Callable.create(self, "disable"))

func _exit_tree() -> void:
	if NetworkManager.attraction_started.is_connected(Callable.create(self, "disable")):
		NetworkManager.attraction_started.disconnect(Callable.create(self, "disable"))

## Disables main Party Menu.
func disable() -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	
	visible = false
	set_process_mode(Node.PROCESS_MODE_DISABLED)

## Re-enables and shows the main Party Menu.
func enable() -> void:
	visible = true
	set_process_mode(Node.PROCESS_MODE_INHERIT)

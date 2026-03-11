### Handles setting up the number of players.
extends Menu

@export var online_menu : Menu
@export var player_count_options : Array[Control]
var cpu_index : int = 3

func show_menu() -> void:
	super()
	for player in player_count_options:
		player.initialize()

func update_selection() -> void:
	if input_axis.x == 0:
		return
	# Add and remove players
	if input_axis.x < 0 && cpu_index > 0:
		remove_player()
		start_selection_timer()
		redraw_players()
	elif input_axis.x > 0 && cpu_index < player_count_options.size() - 1:
		add_player()
		start_selection_timer()
		redraw_players()

func cancel() -> void:
	online_menu.show_menu()
	hide_menu()
	disable_processing()

# Adds a player for this device.
func add_player() -> void:
	cpu_index += 1
	PartyManager.get_player_data(cpu_index).is_cpu_player = !PartyManager.get_player_data(cpu_index).is_cpu_player
	player_count_options[cpu_index].switch_animation()

# Removes a player from this device.
func remove_player() -> void:
	PartyManager.get_player_data(cpu_index).is_cpu_player = !PartyManager.get_player_data(cpu_index).is_cpu_player
	player_count_options[cpu_index].switch_animation()
	cpu_index -= 1

func redraw_players() -> void:
	for option in player_count_options:
		option.update_text()

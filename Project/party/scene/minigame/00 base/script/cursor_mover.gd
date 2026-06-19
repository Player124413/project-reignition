class_name PartyGameCursorMover extends PartyGameCharacterSpawner

@export_group("Components")
@export var rollback_timer: RollbackTimer
@export var cursor_texture_rect: Control

@export_group("Movement Settings")
@export var cursor_move_speed: float = 10

var color: Color

func on_spawn_finished() -> void:
	cursor_texture_rect.get_child(0).self_modulate = get_color()
	cursor_texture_rect.get_child(1).self_modulate = get_color()

func get_color() -> Color:
	match character_animator.data.character_name:
		"party_sonic":
			return Color.AQUA
		"party_tails":
			return Color.YELLOW
		"party_knuckles":
			return Color.RED
		"party_amy":
			return Color.FUCHSIA
		"party_shadow":
			return Color.MIDNIGHT_BLUE
		"party_cream":
			return Color.DARK_ORANGE
		"party_silver":
			return Color.LIGHT_GRAY
		"party_blaze":
			return Color.BLUE_VIOLET
	return Color.WHITE

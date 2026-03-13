## Represents a portrait on the character select screen.
extends Control

@export var cursor_point : Control
@export var linked_character : PartyCharacterResource
@export var timer : Timer
@export var random_label : Label
@export var animator : AnimationPlayer
@export var character_texture : TextureRect

@export var selection_texture : TextureRect
@export var selection_glow_texture : TextureRect
@export var selection_textures : Array[Texture]

func _ready() -> void:
	timer.timeout.connect(play_show)

func initialize() -> void:
	random_label.visible = linked_character == null
	if linked_character != null:
		if linked_character.is_unlocked():
			character_texture.texture = linked_character.character_select_portrait
		else:
			character_texture.texture = linked_character.locked_character_select_portrait
	animator.play("init")
	animator.advance(0.0)

## Shows the portrait after a certain amount of seconds.
func show_portrait(delay : float) -> void:
	if is_zero_approx(delay):
		play_show()
	else:
		timer.start(delay)

func play_show() -> void:
	animator.play("show")

## Called when this portrait is selected.
@rpc("authority", "call_local", "reliable")
func select(port_index : int) -> void:
	selection_texture.texture = selection_textures[port_index]
	selection_glow_texture.texture = selection_texture.texture
	animator.play("select")

## Called when this portrait is selected.
@rpc("authority", "call_local", "reliable")
func deselect() -> void:
	animator.play("deselect")

## Returns the position cursors should be anchored to.
func get_cursor_position() -> Vector2:
	return cursor_point.global_position

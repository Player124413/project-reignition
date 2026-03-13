extends Control

@export var player_label : SyncedLabel
@export var character_label : SyncedLabel
@export var model_parent : Node3D
@export var animator : AnimationPlayer

var instanced_model : Node3D

func initialize() -> void:
	animator.play("init")
	animator.advance(0.0)

func show_preview() -> void:
	animator.play("show")
	var player_data : PlayerData = PartyManager.get_player_data(get_index())
	player_label.set_synced_text(player_data.player_tag)
	character_label.set_synced_text("")

@rpc("any_peer", "call_local", "reliable")
func set_character_text(text : String) -> void:
	character_label.set_synced_text(text)

## Selects the character and loads the model
@rpc("authority", "call_local", "reliable")
func select() -> void:
	## TODO Load character model and play animation/sfx
	print("Model instancing in Character Select Menu isn't implemented yet!")

@rpc("authority", "call_local", "reliable")
func deselect() -> void:
	if is_instance_valid(instanced_model):
		# Delete instanced model
		instanced_model.queue_free()

extends Node

@export var texture_animator : AnimationPlayer
@export var switch_animator : AnimationPlayer
@export var player_label : SyncedLabel

var _player_index : int

func _ready() -> void:
	_player_index = get_index()

func initialize() -> void:
	switch_animator.play("init")
	switch_animator.advance(0.0)
	update_text()
	update_player_texture()

func update_text() -> void:
	player_label.set_synced_text(PartyManager.get_player_data(_player_index).player_tag)

func update_player_texture() -> void:
	var player_data : PlayerData = PartyManager.get_player_data(_player_index)
	texture_animator.play("com" if player_data.is_cpu_player() else "player")

@rpc("any_peer", "call_local", "reliable")
func switch_animation() -> void:
	switch_animator.play("switch")
	switch_animator.seek(0.0)

func show_option() -> void:
	switch_animator.play("show")
	switch_animator.seek(0.0)

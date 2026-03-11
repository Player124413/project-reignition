extends Node

@export var texture_animator : AnimationPlayer
@export var switch_animator : AnimationPlayer
@export var player_label : SyncedLabel

var _player_index : int

const cpu_string : String = "party_com"
const player_string : String = "party_player"

func _ready() -> void:
	_player_index = get_index()

func initialize() -> void:
	switch_animator.play("init")
	switch_animator.advance(0.0)
	update_text()
	update_player_texture()

func update_text() -> void:
	var target_text : String
	var player_data : PlayerData = PartyManager.get_player_data(_player_index)
	if player_data.is_cpu_player:
		target_text = tr(cpu_string).replace("0", str(player_data.player_index + 1))
	else:
		target_text = tr(player_string).replace("0", str(player_data.player_index + 1))
		if NetworkManager.is_online:
			target_text += "-" + str(player_data.device_index)
	player_label.set_synced_text(target_text)

func update_player_texture() -> void:
	var player_data : PlayerData = PartyManager.get_player_data(_player_index)
	texture_animator.play("com" if player_data.is_cpu_player else "player")

func switch_animation() -> void:
	switch_animator.play("switch")
	switch_animator.seek(0.0)

func show_option() -> void:
	switch_animator.play("show")
	switch_animator.seek(0.0)

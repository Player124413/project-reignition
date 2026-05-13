class_name GroupSfxManager extends Node

static var instance : GroupSfxManager
var sfx_dictionary : Dictionary

func _ready() -> void:
	instance = self

func register_player(player : GroupSfxPlayer, group : StringName) -> void:
	if !sfx_dictionary.has(group):
		sfx_dictionary.get_or_add(group, [player])
	else:
		sfx_dictionary[group].append(player)
		# Adjust volume of all in group
		var volume : float = 1.0 / sfx_dictionary[group].size()
		for i in range(sfx_dictionary[group].size() - 1, 0, -1):
			if is_instance_valid(sfx_dictionary[group][i]):
				sfx_dictionary[group][i].set_volume(volume)
			else:
				sfx_dictionary[group].remove_at(i)

func unregister_player(player : GroupSfxPlayer, group : StringName) -> void:
	if !sfx_dictionary.has(group):
		return
	
	var index : int = sfx_dictionary[group].find(player)
	if index != -1:
		sfx_dictionary[group].remove_at(index)
		if sfx_dictionary[group].size() == 0:
			sfx_dictionary.erase(group)

### Represents a player's game data.
class_name PlayerData extends Node


## Localization keys
const cpu_string : String = "party_com"
const player_string : String = "party_player"

## The network peer id that owns this player. 
var device : int

## The selected character for this particular player.
var character_data : PartyCharacterResource

## The player's index in the interval [0, 3].
var player_index : int

## The local player index in the interval [0, 3] for multiple players on a single client.
var local_player_index : int

## How well the player did in the previous mini-game from [0, 3]. Same numbers means a tie has occurred.
var previous_minigame_placement : int

## The tag show to players for identification purposes.
var player_tag : String

## Is this player being controlled by the computer?
func is_cpu_player() -> bool:
	return device == 0

## Returns the tag shown to players.
func update_player_tag() -> void:
	if is_cpu_player():
		player_tag = tr(cpu_string).replace("0", str(player_index + 1))
	else:
		player_tag = tr(player_string).replace("0", str(player_index + 1))
		if NetworkManager.is_online:
			player_tag += "-" + str(local_player_index + 1)

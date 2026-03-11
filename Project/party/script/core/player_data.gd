### Represents a player's game data.
class_name PlayerData extends Node

## Is this player being controlled by the computer?
var is_cpu_player : bool

## The selected character for this particular player.
var character_data : PartyCharacterResource

## The player's index in the interval [0, 3].
var player_index : int

## The device client's index in the interval [0, 3].
var device_index : int

## How well the player did in the previous mini-game from [0, 3]. Same numbers means a tie has occurred.
var previous_minigame_placement : int

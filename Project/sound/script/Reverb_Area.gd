extends Area3D

@export_range(0.0, 1.0) var wet_target: float = 0.5
@export var fade_time: float = 0.4

static var _buses_ready := false
static var _game_bus_idx := -1
static var _voice_bus_idx := -1

static var _game_reverb: AudioEffectReverb
static var _voice_reverb: AudioEffectReverb

static var _tween: Tween
static var _active: Array = []


func _ready() -> void:
	_setup_audio()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _setup_audio() -> void:
	if _buses_ready:
		return

	_game_bus_idx = AudioServer.get_bus_index("GAME SFX")
	_voice_bus_idx = AudioServer.get_bus_index("VOICE")

	if _game_bus_idx == -1:
		push_error("GAME SFX bus missing")

	if _voice_bus_idx == -1:
		push_error("VOICE bus missing")

	# Get/create reverb on GAME SFX
	if _game_bus_idx != -1:
		_game_reverb = AudioServer.get_bus_effect(_game_bus_idx, 0) as AudioEffectReverb
		if _game_reverb == null:
			_game_reverb = AudioEffectReverb.new()
			AudioServer.add_bus_effect(_game_bus_idx, _game_reverb)

	# Get/create reverb on VOICE
	if _voice_bus_idx != -1:
		_voice_reverb = AudioServer.get_bus_effect(_voice_bus_idx, 0) as AudioEffectReverb
		if _voice_reverb == null:
			_voice_reverb = AudioEffectReverb.new()
			AudioServer.add_bus_effect(_voice_bus_idx, _voice_reverb)

	_reset_audio()

	_buses_ready = true


func _exit_tree() -> void:
	_active.clear()
	_reset_audio()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	if not _active.has(self):
		_active.append(self)

	_apply()


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	_active.erase(self)

	if _active.is_empty():
		_reset_audio()
	else:
		_apply()


func _apply() -> void:
	var target := 0.0

	if not _active.is_empty():
		target = _active.back().wet_target

	_set_wet(target)


func _set_wet(value: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()

	if _game_reverb:
		AudioServer.set_bus_effect_enabled(_game_bus_idx, 0, value > 0)
		_tween.parallel().tween_property(
			_game_reverb,
			"wet",
			value,
			fade_time
		)

	if _voice_reverb:
		AudioServer.set_bus_effect_enabled(_voice_bus_idx, 0, value > 0)
		_tween.parallel().tween_property(
			_voice_reverb,
			"wet",
			value,
			fade_time
		)

	if is_zero_approx(value):
		_tween.tween_callback(_disable)


func _reset_audio() -> void:
	_set_wet(0.0)


func _disable() -> void:
	if _game_bus_idx != -1:
		AudioServer.set_bus_effect_enabled(_game_bus_idx, 0, false)

	if _voice_bus_idx != -1:
		AudioServer.set_bus_effect_enabled(_voice_bus_idx, 0, false)

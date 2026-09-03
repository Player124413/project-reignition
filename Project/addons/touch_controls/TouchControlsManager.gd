extends CanvasLayer
## Main touch controls overlay manager for Android.
##
## Creates and manages virtual joystick + keyboard-style keycap buttons
## that simulate the game's existing Input actions. The overlay lives on
## a persistent autoload CanvasLayer, so the buttons are visible and
## functional in EVERY screen: gameplay, title, menus, pause (the whole
## layer is PROCESS_MODE_ALWAYS so input keeps flowing while the tree
## is paused). Buttons automatically show the keyboard key bound to each
## action in the InputMap (e.g. Jump = V, Menu = Enter, Brake = Shift).
##
## Features:
## - Virtual analog joystick (left side)
## - Keycap buttons labeled with their bound keyboard key
## - Menu navigation cluster (arrows + Enter) for title/pause/options
## - Auto-detect mobile vs desktop (shows on any touchscreen device)
## - Auto-hide on gamepad connection
## - **Edit mode** (press ✎) — drag, resize, toggle visibility
## - **Save/load** custom layouts to user://touch_layout.cfg
## - **Disable** touch controls entirely
## - **Mobile performance** auto-tuning

class_name TouchControlsManager

signal touch_enabled_changed(enabled: bool)
signal layout_changed

# ─── Exported Settings ───────────────────────────────────────────────

## Enable touch controls (auto-detected on mobile, force for desktop testing)
@export var force_enabled: bool = false
## Automatically hide controls when a physical gamepad is connected
@export var auto_hide_on_controller: bool = true
## Show debug overlay for touch regions
@export var debug_mode: bool = false
## Show the small function caption under each keycap ("Jump", "Brake"...)
@export var show_captions: bool = true

# ─── Internal State ──────────────────────────────────────────────────

var is_visible_override: bool = true

# Backing field for the touch_enabled property (Godot 4 property syntax)
var _touch_enabled_backing: bool = true
var touch_enabled: bool = true:
	get:
		return _touch_enabled_backing
	set(value):
		if _touch_enabled_backing == value:
			return
		_touch_enabled_backing = value
		if not _touch_enabled_backing:
			_force_release_all()
		_refresh_key_visibility()
		touch_enabled_changed.emit(value)

var _initialized: bool = false
# When a real gamepad last produced input (ms). We deliberately do NOT hide
# the overlay merely because Input.get_connected_joypads() is non-empty —
# many Android devices expose phantom "joystick" sensor devices, which used
# to hide every key. The overlay only steps back while a pad is genuinely
# in use (button/axis input within the last PAD_ACTIVE_WINDOW_MS).
var _last_pad_input_ms: int = -100000
const PAD_ACTIVE_WINDOW_MS := 4000
var _disable_banner: Label

# References to control nodes
var _joystick: TouchVirtualJoystick
var _buttons: Array[VirtualButton] = []

# Editor reference
var _editor: TouchControlsEditor

# Performance manager
var _perf: MobilePerformanceManager

# Whether we loaded a custom layout
var _has_custom_layout: bool = false

# Base keycap size as fraction of screen height
const KEY_BASE_SIZE := 0.085

# Button configuration:
# [action, caption, toggle, pos_x_norm, pos_y_norm, size_mult, width_mult, extra_actions]
# The printed label is resolved at runtime from the InputMap keyboard binding.
const BUTTON_CONFIG := [
	# Right side — main gameplay keys (labels follow the keyboard bindings)
	["button_jump",        "Jump",        false, 0.835, 0.845, 1.15, 1.0, []],
	["button_action",      "Action",      false, 0.715, 0.760, 0.85, 1.0, []],
	["button_attack",      "Attack",      false, 0.900, 0.685, 0.85, 1.0, []],
	["button_brake",       "Brake",       false, 0.615, 0.865, 0.70, 1.5, []],
	["button_speedbreak",  "Speed Break", true,  0.800, 0.545, 0.62, 1.4, []],
	["button_timebreak",   "Time Break",  true,  0.930, 0.450, 0.62, 1.4, []],
	["button_light_dash",  "Light Dash",  false, 0.680, 0.420, 0.62, 1.4, []],
	["button_step_left",   "Step Left",   false, 0.850, 0.130, 0.55, 1.0, []],
	["button_step_right",  "Step Right",  false, 0.940, 0.130, 0.55, 1.0, []],

	# Bottom middle — menu navigation row (works in title/options/pause).
	# Each arrow presses ui_* AND move_* so both menu focus and gameplay
	# movement react to the same keycap.
	["ui_left",            "Left",        false, 0.275, 0.900, 0.62, 1.0, ["move_left"]],
	["ui_up",              "Up",          false, 0.340, 0.900, 0.62, 1.0, ["move_up"]],
	["ui_down",            "Down",        false, 0.405, 0.900, 0.62, 1.0, ["move_down"]],
	["ui_right",           "Right",       false, 0.470, 0.900, 0.62, 1.0, ["move_right"]],
	["sys_pause",          "Menu / Back", false, 0.585, 0.900, 0.62, 1.7, ["ui_accept"]],
	["ui_select",          "Select",      false, 0.680, 0.900, 0.62, 1.4, []],

	# Edit-layout key (top-right). Not a game action — opens the editor.
	["edit_touch",         "Edit",        false, 0.965, 0.045, 0.60, 1.0, []],
]

# Fallback printed labels for actions without keyboard bindings
const FALLBACK_LABELS := {
	"edit_touch": "✎",
}

func _ready() -> void:
	layer = 128  # Very high layer, above everything
	# Buttons must keep working while the game is paused (pause menu,
	# world select etc. set SceneTree.paused = true).
	process_mode = PROCESS_MODE_ALWAYS
	
	# "edit_touch" is an internal action — register it so it always exists
	if not InputMap.has_action("edit_touch"):
		InputMap.add_action("edit_touch")
	
	# Enable where touch input makes sense: mobile, any touchscreen device,
	# the desktop editor (for testing — keys react to mouse there), or forced
	if not force_enabled and not _is_mobile() and not _has_touchscreen() and not OS.has_feature("editor"):
		visible = false
		set_process_input(false)
		return
	
	# Initialize performance manager on mobile
	if _is_mobile():
		_perf = MobilePerformanceManager.new()
		add_child(_perf)
		print("MobilePerformance: Auto-tuning started")
	
	# Load saved enabled state
	_load_enabled_state()
	
	# Wait one frame for the viewport to be ready
	await get_tree().process_frame
	
	# Check for saved layout first
	_has_custom_layout = _load_custom_layout_if_exists()
	
	_build_layout()
	_initialized = true
	
	# Listen for controller connections (informational only — see _pad_active)
	if auto_hide_on_controller:
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	
	_refresh_key_visibility()
	_show_disable_banner_if_needed()

func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")

func _has_touchscreen() -> bool:
	return DisplayServer.is_touchscreen_available()

# ─── Keyboard key label resolution ───────────────────────────────────

## Returns the printable label for the first keyboard key bound to an action.
func _primary_key_label(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k: int = e.keycode
			if k == KEY_NONE:
				k = e.physical_keycode
			if k != KEY_NONE:
				return _key_to_text(k)
	return ""

func _key_to_text(k: int) -> String:
	match k:
		KEY_ESCAPE:
			return "Esc"
		KEY_ENTER, KEY_KP_ENTER:
			return "Enter"
		KEY_SPACE:
			return "Space"
		KEY_TAB:
			return "Tab"
		KEY_SHIFT:
			return "Shift"
		KEY_CTRL:
			return "Ctrl"
		KEY_ALT:
			return "Alt"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_DELETE:
			return "Del"
		KEY_BACKSPACE:
			return "⌫"
	if k >= 32 and k <= 126:
		return char(k).to_upper()
	return "?"

func _load_enabled_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://touch_toggle.cfg") == OK:
		touch_enabled = cfg.get_value("general", "enabled", true)
	else:
		touch_enabled = true

func _save_enabled_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "enabled", touch_enabled)
	cfg.save("user://touch_toggle.cfg")

func _load_custom_layout_if_exists() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load("user://touch_layout.cfg") == OK

func _build_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1920, 1080)
	
	# ─── Create Joystick (Left Side) ──────────────────────────────
	var joystick_scene := preload("res://addons/touch_controls/VirtualJoystick.tscn")
	if joystick_scene:
		_joystick = joystick_scene.instantiate()
		add_child(_joystick)
	else:
		_joystick = TouchVirtualJoystick.new()
		add_child(_joystick)
	
	var joystick_size := viewport_size.y * 0.22  # 22% of screen height
	_joystick.max_radius = joystick_size * 0.45
	_joystick.custom_minimum_size = Vector2(joystick_size, joystick_size)
	_joystick.size = Vector2(joystick_size, joystick_size)
	_joystick.position = Vector2(viewport_size.x * 0.08 - joystick_size * 0.5, viewport_size.y * 0.62 - joystick_size * 0.5)
	
	# ─── Create Keycap Buttons ────────────────────────────────────
	_buttons.clear()
	var base_size := viewport_size.y * KEY_BASE_SIZE
	
	for cfg in BUTTON_CONFIG:
		var action: String = cfg[0]
		var cap_func: String = cfg[1]
		var toggle: bool = cfg[2]
		var size_mult: float = float(cfg[5])
		var width_mult: float = float(cfg[6])
		
		var btn := VirtualButton.new()
		btn.name = "Key_" + action
		btn.action_name = action
		btn.toggle_mode = toggle
		btn.button_scale = 1.0
		var extras: Array[String] = []
		for x in cfg[7]:
			extras.append(String(x))
		btn.extra_actions = extras
		btn.caption = cap_func if show_captions else ""
		
		var key_text: String = _primary_key_label(action)
		if key_text.is_empty():
			key_text = str(FALLBACK_LABELS.get(action, action.substr(0, 1).to_upper()))
		btn.button_label = key_text
		
		var h: float = base_size * size_mult
		var w: float = h * width_mult
		btn.custom_minimum_size = Vector2(w, h)
		btn.size = Vector2(w, h)
		btn.set_meta("width_ratio", width_mult)
		btn.set_meta("size_mult", size_mult)
		var bx: float = viewport_size.x * float(cfg[3]) - w * 0.5
		var by: float = viewport_size.y * float(cfg[4]) - h * 0.5
		btn.position = Vector2(maxf(bx, 0.0), maxf(by, 0.0))
		
		if action == "edit_touch":
			btn.pressed_started.connect(open_editor)
		
		add_child(btn)
		_buttons.append(btn)
	
	# ─── Apply custom layout if it exists ─────────────────────────
	if _has_custom_layout:
		_apply_custom_layout()
	
	_refresh_key_visibility()
	
	# ─── Debug overlay ────────────────────────────────────────────
	if debug_mode:
		var debug_lbl := Label.new()
		debug_lbl.name = "DebugLabel"
		debug_lbl.text = "Touch Controls Active"
		debug_lbl.position = Vector2(viewport_size.x * 0.35, viewport_size.y * 0.01)
		debug_lbl.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		debug_lbl.add_theme_font_size_override("font_size", 14)
		add_child(debug_lbl)

func open_editor() -> void:
	if _editor and _editor.is_editing():
		return
	
	_editor = TouchControlsEditor.new()
	add_child(_editor)
	_editor.editor_closed.connect(_on_editor_closed)
	
	# Hide regular controls during edit (they're still visible but with overlay)
	_editor.enter_edit_mode(self)

func _on_editor_closed(changed: bool) -> void:
	if _editor:
		_editor.queue_free()
		_editor = null
	
	if changed:
		layout_changed.emit()

func _apply_custom_layout() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://touch_layout.cfg") != OK:
		return
	
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	
	# Apply to joystick
	if _joystick and cfg.has_section("joystick"):
		var nx := cfg.get_value("joystick", "pos_x", 0.08)
		var ny := cfg.get_value("joystick", "pos_y", 0.62)
		var sz := cfg.get_value("joystick", "size_norm", 0.22)
		var elem_size: float = viewport_size.y * sz
		_joystick.size = Vector2(elem_size, elem_size)
		_joystick.position = Vector2(viewport_size.x * nx - elem_size * 0.5, viewport_size.y * ny - elem_size * 0.5)
		_joystick.max_radius = elem_size * 0.45
		_joystick._generate_textures()
	
	# Apply to buttons
	for btn in _buttons:
		var section := btn.action_name
		if not cfg.has_section(section):
			continue
		
		var visible_val := cfg.get_value(section, "visible", true)
		btn.visible = visible_val
		
		var nx := cfg.get_value(section, "pos_x", 0.5)
		var ny := cfg.get_value(section, "pos_y", 0.5)
		var sz := cfg.get_value(section, "size_norm", btn.get_meta("size_mult", 1.0) * KEY_BASE_SIZE)
		var wr := float(cfg.get_value(section, "width_ratio", btn.get_meta("width_ratio", 1.0)))
		var elem_size: float = maxf(viewport_size.y * sz, 30.0)
		
		# Keycaps keep their own child layout via NOTIFICATION_RESIZED
		btn.size = Vector2(elem_size * wr, elem_size)
		btn.position = Vector2(viewport_size.x * nx - btn.size.x * 0.5, viewport_size.y * ny - elem_size * 0.5)

func _rebuild_layout() -> void:
	# Clear all existing controls
	if _joystick:
		_joystick.queue_free()
		_joystick = null
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()
	
	# Rebuild
	_build_layout()

func _pad_active() -> bool:
	return auto_hide_on_controller and Time.get_ticks_msec() - _last_pad_input_ms < PAD_ACTIVE_WINDOW_MS

func _input(event: InputEvent) -> void:
	if not auto_hide_on_controller:
		return
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_last_pad_input_ms = Time.get_ticks_msec()
			_update_visibility()
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.6:
			_last_pad_input_ms = Time.get_ticks_msec()
			_update_visibility()
	elif event is InputEventScreenTouch:
		# User reached for the touchscreen — the pad is not in use anymore,
		# bring the keycaps back immediately.
		if _last_pad_input_ms > 0:
			_last_pad_input_ms = -100000
			_update_visibility()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	print("TouchOverlay: joystick device %d %s (keys only hide on real pad input)" % [device, "connected" if connected else "disconnected"])

func _update_visibility() -> void:
	if not is_visible_override:
		visible = false
		return
	
	if _pad_active() and touch_enabled:
		visible = false
		_force_release_all()
	else:
		visible = true
	
	_refresh_key_visibility()

## When touch is disabled, keep only the ✎ Edit key visible so the user
## can always come back and re-enable the controls. When enabled, restore
## per-button visibility from the saved layout.
func _refresh_key_visibility() -> void:
	if not _initialized:
		return
	
	if touch_enabled:
		if _disable_banner and is_instance_valid(_disable_banner):
			var tw := create_tween()
			tw.tween_property(_disable_banner, "modulate:a", 0.0, 0.3)
			tw.tween_callback(_disable_banner.queue_free)
			_disable_banner = null
		for btn in _buttons:
			btn.visible = true
		if _joystick:
			_joystick.visible = true
		var cfg := ConfigFile.new()
		if cfg.load("user://touch_layout.cfg") == OK:
			for btn in _buttons:
				var section := btn.action_name
				if cfg.has_section(section):
					btn.visible = bool(cfg.get_value(section, "visible", true))
			if _joystick and cfg.has_section("joystick"):
				_joystick.visible = bool(cfg.get_value("joystick", "visible", true))
	else:
		if _joystick:
			_joystick.visible = false
		for btn in _buttons:
			btn.visible = (btn.action_name == "edit_touch")

func _force_release_all() -> void:
	if _joystick:
		_joystick.force_release()
	for btn in _buttons:
		btn.force_release()

## When the controls come back soft-disabled (user pressed DISABLE earlier,
## flag persisted in user://touch_toggle.cfg), show a blinking hint pointing
## at the ✎ key — the only control that stays reachable.
func _show_disable_banner_if_needed() -> void:
	if touch_enabled or _disable_banner:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_disable_banner = Label.new()
	_disable_banner.name = "DisabledBanner"
	_disable_banner.text = "Touch controls OFF — tap the ✎ key, then ENABLE"
	_disable_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_disable_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_disable_banner.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 0.95))
	_disable_banner.add_theme_font_size_override("font_size", maxi(int(vp.y * 0.022), 12))
	_disable_banner.mouse_filter = MOUSE_FILTER_IGNORE
	_disable_banner.position = Vector2(vp.x * 0.02, vp.y * 0.015)
	_disable_banner.size = Vector2(vp.x * 0.9, vp.y * 0.05)
	add_child(_disable_banner)
	var tw := _disable_banner.create_tween().set_loops(4)
	tw.tween_property(_disable_banner, "modulate:a", 0.15, 0.35)
	tw.tween_property(_disable_banner, "modulate:a", 1.0, 0.35)

## Show touch controls (overrides auto-hide)
func show_touch_controls() -> void:
	touch_enabled = true
	is_visible_override = true
	_update_visibility()

## Hide touch controls programmatically (fully — layer hidden)
func hide_touch_controls() -> void:
	is_visible_override = false
	_force_release_all()
	visible = false

## Make only the ✎ Edit key reachable (soft disable — see set_touch_enabled)
func disable_touch_controls() -> void:
	set_touch_enabled(false)

## Enable/disable touch controls entirely (saves to disk)
func set_touch_enabled(enabled: bool) -> void:
	self.touch_enabled = enabled
	_save_enabled_state()

## Toggle touch on/off
func toggle_touch_enabled() -> void:
	set_touch_enabled(not touch_enabled)

func is_touch_active() -> bool:
	return visible and _initialized and touch_enabled

func get_performance_manager() -> MobilePerformanceManager:
	return _perf

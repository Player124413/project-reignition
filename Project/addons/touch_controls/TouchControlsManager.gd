extends CanvasLayer
## Main touch controls overlay manager for Android.
##
## Creates and manages virtual joystick + buttons that simulate
## the game's existing Input actions. Automatically hides when
## a physical controller/keyboard is detected.
##
## Usage: Add as an autoload in Project Settings.

class_name TouchControlsManager

# ─── Exported Settings ───────────────────────────────────────────────

## Enable touch controls (auto-detected on mobile, force for desktop testing)
@export var force_enabled: bool = false
## Automatically hide controls when a physical gamepad is connected
@export var auto_hide_on_controller: bool = true
## Show debug overlay for touch regions
@export var debug_mode: bool = false

# ─── Internal State ──────────────────────────────────────────────────

var is_visible_override: bool = true
var _physical_input_active: bool = false
var _initialized: bool = false

# References to control nodes
var _joystick: VirtualJoystick
var _buttons: Array[VirtualButton] = []

# Button configuration: [action_name, label, toggle, pos_x_norm, pos_y_norm, size_norm]
const BUTTON_CONFIG := [
	# Right side — main action buttons (bottom to top)
	["button_jump",        "A",   false,  0.82, 0.85, 1.2],   # Jump (big)
	["button_action",      "B",   false,  0.72, 0.78, 0.9],   # Action
	["button_attack",      "X",   false,  0.88, 0.72, 0.9],   # Attack
	
	# Middle-right — special abilities
	["button_speedbreak",  "SB",  true,   0.78, 0.55, 0.7],   # Speed Break (toggle)
	["button_timebreak",   "TB",  true,   0.88, 0.45, 0.7],   # Time Break (toggle)
	["button_light_dash",  "LD",  false,  0.72, 0.35, 0.7],   # Light Dash
	["button_brake",       "BR",  false,  0.65, 0.65, 0.7],   # Brake
	
	# Top row — step/pause
	["button_step_left",   "◀",   false,  0.75, 0.12, 0.6],   # Step Left
	["button_step_right",  "▶",   false,  0.85, 0.12, 0.6],   # Step Right
]

func _ready() -> void:
	layer = 128  # Very high layer, above everything
	
	# Only enable on mobile or when forced
	if not force_enabled and not _is_mobile():
		visible = false
		set_process_input(false)
		return
	
	# Wait one frame for the viewport to be ready
	await get_tree().process_frame
	
	_build_layout()
	_initialized = true
	
	# Listen for controller connections
	if auto_hide_on_controller:
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
		_check_physical_input()

func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")

func _build_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	
	# ─── Create Joystick (Left Side) ──────────────────────────────
	var joystick_scene := preload("res://addons/touch_controls/VirtualJoystick.tscn")
	if joystick_scene:
		_joystick = joystick_scene.instantiate()
		add_child(_joystick)
	else:
		_joystick = VirtualJoystick.new()
		add_child(_joystick)
	
	# Position joystick at bottom-left
	var joystick_size := viewport_size.y * 0.22  # 22% of screen height
	_joystick.max_radius = joystick_size * 0.45
	_joystick.position = Vector2(viewport_size.x * 0.08, viewport_size.y * 0.62)
	_joystick.custom_minimum_size = Vector2(joystick_size, joystick_size)
	
	# ─── Create Buttons ───────────────────────────────────────────
	var btn_size := viewport_size.y * 0.085  # Base button size
	
	for cfg in BUTTON_CONFIG:
		var btn := VirtualButton.new()
		btn.action_name = cfg[0]
		btn.button_label = cfg[1]
		btn.toggle_mode = cfg[2]
		btn.button_scale = cfg[5]
		
		# Build the button's visual tree
		var bg := NinePatchRect.new()
		bg.name = "Background"
		bg.custom_minimum_size = Vector2(btn_size, btn_size) * cfg[5]
		bg.color = Color(1, 1, 1, 0.25)
		bg.size = bg.custom_minimum_size
		bg.position = Vector2.ZERO
		# Rounded corners via a simple approach
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.2)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = Color(1, 1, 1, 0.4)
		bg.set("theme_override_styles/panel", style)
		btn.add_child(bg)
		
		var lbl := Label.new()
		lbl.name = "Label"
		lbl.text = cfg[1]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = bg.custom_minimum_size
		lbl.position = Vector2.ZERO
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		lbl.add_theme_font_size_override("font_size", 18 * cfg[5])
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		btn.add_child(lbl)
		
		# Position button
		btn.custom_minimum_size = bg.custom_minimum_size
		btn.size = bg.custom_minimum_size
		var bx := viewport_size.x * cfg[3] - btn.size.x * 0.5
		var by := viewport_size.y * cfg[4] - btn.size.y * 0.5
		btn.position = Vector2(bx, by)
		
		add_child(btn)
		_buttons.append(btn)
	
	# ─── Pause / Menu Button (Top-Left) ───────────────────────────
	var pause_btn := VirtualButton.new()
	pause_btn.action_name = "sys_pause"
	pause_btn.button_label = "≡"
	pause_btn.toggle_mode = false
	pause_btn.idle_alpha = 0.25
	pause_btn.pressed_alpha = 0.7
	
	var pause_bg := NinePatchRect.new()
	pause_bg.name = "Background"
	var p_size := viewport_size.y * 0.055
	pause_bg.custom_minimum_size = Vector2(p_size, p_size)
	pause_bg.color = Color(1, 1, 1, 0.2)
	pause_bg.size = pause_bg.custom_minimum_size
	pause_bg.position = Vector2.ZERO
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(1, 1, 1, 0.15)
	pstyle.corner_radius_top_left = 10
	pstyle.corner_radius_top_right = 10
	pstyle.corner_radius_bottom_left = 10
	pstyle.corner_radius_bottom_right = 10
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.border_color = Color(1, 1, 1, 0.3)
	pause_bg.set("theme_override_styles/panel", pstyle)
	pause_btn.add_child(pause_bg)
	
	var pause_lbl := Label.new()
	pause_lbl.name = "Label"
	pause_lbl.text = "≡"
	pause_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_lbl.size = pause_bg.custom_minimum_size
	pause_lbl.position = Vector2.ZERO
	pause_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	pause_lbl.add_theme_font_size_override("font_size", 24)
	pause_btn.add_child(pause_lbl)
	
	pause_btn.custom_minimum_size = pause_bg.custom_minimum_size
	pause_btn.size = pause_bg.custom_minimum_size
	pause_btn.position = Vector2(viewport_size.x * 0.02, viewport_size.y * 0.02)
	add_child(pause_btn)
	_buttons.append(pause_btn)
	
	# ─── Debug overlay ────────────────────────────────────────────
	if debug_mode:
		var debug_lbl := Label.new()
		debug_lbl.name = "DebugLabel"
		debug_lbl.text = "Touch Controls Active"
		debug_lbl.position = Vector2(viewport_size.x * 0.35, viewport_size.y * 0.01)
		debug_lbl.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		debug_lbl.add_theme_font_size_override("font_size", 14)
		add_child(debug_lbl)

func _check_physical_input() -> void:
	# Check if any gamepad is connected
	for i in range(Input.get_connected_joypads().size()):
		_physical_input_active = true
		_update_visibility()
		return
	
	# Check if keyboard is being used (desktop testing)
	_physical_input_active = false
	_update_visibility()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_physical_input_active = connected
	_update_visibility()

func _update_visibility() -> void:
	if not is_visible_override:
		visible = false
		return
	
	if auto_hide_on_controller and _physical_input_active:
		visible = false
		# Release all inputs when hiding
		_force_release_all()
	else:
		visible = true

func _force_release_all() -> void:
	if _joystick:
		_joystick.force_release()
	for btn in _buttons:
		btn.force_release()

## Toggle touch controls visibility programmatically
func show_touch_controls() -> void:
	is_visible_override = true
	_update_visibility()

func hide_touch_controls() -> void:
	is_visible_override = false
	_force_release_all()
	visible = false

func is_touch_active() -> bool:
	return visible and _initialized
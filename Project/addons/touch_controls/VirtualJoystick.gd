extends Control
## Virtual analog joystick for touch input.
##
## Emulates move_left/right/up/down input actions based on touch position.
## Supports dynamic positioning (first touch shows joystick at touch point).

class_name TouchVirtualJoystick

signal joystick_activated
signal joystick_released

## Maximum distance the knob can move from center (in pixels)
@export var max_radius: float = 100.0
## Dead zone as fraction of radius (0.0 - 1.0)
@export var dead_zone: float = 0.15
## Whether joystick appears where you touch (dynamic) or is fixed
@export var dynamic_mode: bool = false
## Joystick opacity when idle
@export var idle_alpha: float = 0.35
## Joystick opacity when active
@export var active_alpha: float = 0.7

var _touch_index: int = -1
var _is_active: bool = false
var _knob_offset: Vector2 = Vector2.ZERO
var _base_position: Vector2 = Vector2.ZERO

var _knob: Control
var _base: Control
var _base_tex: TextureRect
var _knob_tex: TextureRect

## Builds Base/Knob children programmatically. (The optional
## VirtualJoystick.tscn is NOT required anymore — a scene whose root lacked
## its script used to abort the whole overlay build at runtime.)
func _ensure_children() -> void:
	_base = get_node_or_null("Base") as Control
	if _base == null:
		_base = Control.new()
		_base.name = "Base"
		_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_base)
	_base_tex = _base.get_node_or_null("BaseTexture") as TextureRect
	if _base_tex == null:
		_base_tex = TextureRect.new()
		_base_tex.name = "BaseTexture"
		_base_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_base_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_base_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_base.add_child(_base_tex)
	_knob = get_node_or_null("Knob") as Control
	if _knob == null:
		_knob = Control.new()
		_knob.name = "Knob"
		_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_knob)
	_knob_tex = _knob.get_node_or_null("KnobTexture") as TextureRect
	if _knob_tex == null:
		_knob_tex = TextureRect.new()
		_knob_tex.name = "KnobTexture"
		_knob_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_knob_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_knob_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_knob.add_child(_knob_tex)

func _ready() -> void:
	_ensure_children()
	modulate.a = idle_alpha
	
	# Generate smooth circular textures
	_generate_textures()
	
	_set_knob_position(Vector2.ZERO)
	
	if dynamic_mode:
		mouse_filter = MOUSE_FILTER_IGNORE
	else:
		_base_position = position + size * 0.5
		position = Vector2.ZERO
		_center_control(_base)
		_center_control(_knob)

func _generate_textures() -> void:
	var base_rad := max_radius * 1.0
	var knob_rad := max_radius * 0.3
	
	if _base_tex and _base_tex.texture == null:
		var img_base := Image.create(int(base_rad * 2), int(base_rad * 2), false, Image.FORMAT_RGBA8)
		img_base.fill(Color(0, 0, 0, 0))
		_draw_circle_into_image(img_base, Vector2(base_rad, base_rad), base_rad, Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.08))
		_base_tex.texture = ImageTexture.create_from_image(img_base)
		_base_tex.size = Vector2(base_rad * 2, base_rad * 2)
	
	if _knob_tex and _knob_tex.texture == null:
		var img_knob := Image.create(int(knob_rad * 2), int(knob_rad * 2), false, Image.FORMAT_RGBA8)
		img_knob.fill(Color(0, 0, 0, 0))
		_draw_circle_into_image(img_knob, Vector2(knob_rad, knob_rad), knob_rad, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.35))
		_knob_tex.texture = ImageTexture.create_from_image(img_knob)
		_knob_tex.size = Vector2(knob_rad * 2, knob_rad * 2)

func _draw_circle_into_image(img: Image, center: Vector2, radius: float, fill_color: Color, edge_color: Color, center_highlight: Color) -> void:
	for x in img.get_width():
		for y in img.get_height():
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			var t := dist / radius
			
			if t <= 1.0:
				var color: Color
				if t < 0.25:
					color = center_highlight.lerp(fill_color, t / 0.25)
				elif t < 0.85:
					color = fill_color
				else:
					color = fill_color.lerp(edge_color, (t - 0.85) / 0.15)
				
				# Smooth edge fade
				if t > 0.92:
					color.a *= (1.0 - t) / 0.08
				
				img.set_pixel(x, y, color)

func _center_control(ctrl: Control) -> void:
	ctrl.position = _base_position - ctrl.size * 0.5

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var mouse_in_editor: bool = OS.has_feature("editor") and event is InputEventMouseButton
	if mouse_in_editor:
		_process_touch(event)
		return
	if OS.has_feature("editor") and not _is_mobile() and not DisplayServer.is_touchscreen_available():
		return
	
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_process_touch(event)

func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")

func _process_touch(event: InputEvent) -> void:
	var pos: Vector2
	var is_press: bool
	var touch_idx: int
	
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		pos = te.position
		is_press = te.pressed
		touch_idx = te.index
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		pos = de.position
		is_press = true
		touch_idx = de.index
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = mb.position
		is_press = mb.pressed
		touch_idx = 0
	else:
		return
	
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var is_left_side: bool = pos.x < viewport_size.x * 0.45
	
	if not _is_active and is_press and is_left_side:
		_touch_index = touch_idx
		_is_active = true
		modulate.a = active_alpha
		
		if dynamic_mode:
			_base_position = pos
			_center_control(_base)
			_center_control(_knob)
		
		joystick_activated.emit()
		_update_joystick_from_touch(pos)
		get_viewport().set_input_as_handled()
		
	elif _is_active and touch_idx == _touch_index:
		if is_press:
			_update_joystick_from_touch(pos)
			get_viewport().set_input_as_handled()
		else:
			_release_joystick()

func _update_joystick_from_touch(touch_pos: Vector2) -> void:
	_knob_offset = touch_pos - _base_position
	var distance: float = _knob_offset.length()
	
	if distance > max_radius:
		_knob_offset = _knob_offset.normalized() * max_radius
	
	_set_knob_position(_knob_offset)
	_emit_input_actions()

func _set_knob_position(offset: Vector2) -> void:
	_knob.position = _base_position + offset - _knob.size * 0.5

func _release_joystick() -> void:
	_touch_index = -1
	_is_active = false
	modulate.a = idle_alpha
	_knob_offset = Vector2.ZERO
	_set_knob_position(Vector2.ZERO)
	_emit_input_actions()  # releases all inputs
	joystick_released.emit()

func _emit_input_actions() -> void:
	var normalized: Vector2 = _get_normalized_output()
	
	if normalized.x < -dead_zone:
		Input.action_press("move_left", absf(normalized.x))
		Input.action_release("move_right")
	elif normalized.x > dead_zone:
		Input.action_press("move_right", normalized.x)
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")
	
	if normalized.y < -dead_zone:
		Input.action_press("move_up", absf(normalized.y))
		Input.action_release("move_down")
	elif normalized.y > dead_zone:
		Input.action_press("move_down", normalized.y)
		Input.action_release("move_up")
	else:
		Input.action_release("move_up")
		Input.action_release("move_down")

func _get_normalized_output() -> Vector2:
	var output: Vector2 = _knob_offset
	if output.length() > max_radius:
		output = output.normalized() * max_radius
	
	var normalized: Vector2 = output / max_radius
	var len: float = normalized.length()
	
	if len < dead_zone:
		return Vector2.ZERO
	
	# Map [dead_zone..1] → [0..1]
	var scaled: float = (len - dead_zone) / (1.0 - dead_zone)
	return normalized.normalized() * scaled

func is_joystick_active() -> bool:
	return _is_active

func force_release() -> void:
	if _is_active:
		_release_joystick()
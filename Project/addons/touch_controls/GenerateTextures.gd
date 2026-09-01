## Generates touch control textures at runtime.
## Called by TouchControlsManager to create smooth circular visuals.

static func generate_joystick_base_texture(radius: float) -> ImageTexture:
	var diameter := int(radius * 2)
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	var center := Vector2(radius, radius)
	var outer_radius := radius - 2.0
	
	for x in diameter:
		for y in diameter:
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			
			if dist <= outer_radius:
				var alpha := 0.0
				if dist <= outer_radius * 0.95:
					alpha = 0.15  # Fill
				else:
					alpha = 0.3  # Edge
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	return ImageTexture.create_from_image(image)

static func generate_joystick_knob_texture(radius: float) -> ImageTexture:
	var diameter := int(radius * 2)
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	var center := Vector2(radius, radius)
	var outer_radius := radius - 2.0
	
	for x in diameter:
		for y in diameter:
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			
			if dist <= outer_radius:
				var alpha := 0.35
				if dist > outer_radius * 0.85:
					alpha = 0.5  # Edge highlight
				elif dist < outer_radius * 0.3:
					alpha = 0.5  # Center highlight
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	return ImageTexture.create_from_image(image)
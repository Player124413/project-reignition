extends MeshInstance3D

func _ready():
	var mesh_data = mesh
	if mesh_data and mesh_data.get_surface_count() > 0:
		# Get the actual vertex color data
		var surface_data = mesh_data.surface_get_arrays(0)
		var colors = surface_data[Mesh.ARRAY_COLOR]
		
		if colors:
			print("Color count: ", colors.size())
			print("First 144 colors:")
			for i in min(144, colors.size()):
				print("Color ", i, ": ", colors[i])
		else:
			print("No color array found")

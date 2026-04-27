### Manages the trails on the rolling ball.
### Original script by thomason1005 on GitHub.
extends MeshInstance3D

@export var target : Node3D

## Max number of vertices. Must be a multiple of 6, as we write 6 each frame.
var max_length : int = 6 * 100
## The distance at which to create new vertices.
@export var dist_interval : float = 1
### The width of the trail.
@export var width : float = 10.0
var i = 0 # this is used to loop through the vertices array

var vertices : PackedVector3Array = PackedVector3Array()
var uvs : PackedVector2Array = PackedVector2Array()
var vertex_colors : PackedColorArray = PackedColorArray()
var arrays = []

# Remember where we did the last traingles, so we can connect to them
var lastStart : Vector3 = Vector3.ZERO
var oldPos : Vector3 = Vector3.ZERO
var oldPosA : Vector3 = Vector3.ZERO
var oldPosB : Vector3 = Vector3.ZERO

@export var fade_length : float = 50.0
# How many meters of trail equals one texture wrap:
@export var texture_length: float = 20.0
var total_v : float = 0.0

func _ready():
	vertices.resize(max_length)
	uvs.resize(max_length)
	vertex_colors.resize(max_length)
	for j in vertex_colors.size():
		vertex_colors[j] = Color.WHITE
	
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Move mesh instance to global space
	global_position = Vector3.ZERO
	global_rotation = Vector3.ZERO
	top_level = true

func _process(_delta : float) -> void:
	var pos = (target.global_position - global_position) - Vector3(0,.25,0)
	#make our second corner perpendicular to the last direction
	var tangent : Vector3 = ((pos - oldPos).cross(Vector3.UP)).normalized() * width
	var posB : Vector3 = pos - tangent * 0.5
	var posA : Vector3 = pos + tangent * 0.5
	
	# make a new mark if we are above the threshold distance
	if (pos - lastStart).length() > dist_interval:
		# only make skidmarks if wheels are below treshold
		if i >= max_length - 6:
			i = 0
		vertices[i + 0] = oldPosB
		vertices[i + 1] = posA
		vertices[i + 2] = oldPosA
		vertices[i + 3] = oldPosB
		vertices[i + 4] = posB
		vertices[i + 5] = posA
		
		# UVs
		var segment_dist = (pos - lastStart).length()
		var v_delta = segment_dist / texture_length
		var old_v = total_v
		total_v += v_delta
		uvs[i + 0] = Vector2(0, old_v)
		uvs[i + 1] = Vector2(1, total_v)
		uvs[i + 2] = Vector2(1, old_v)
		uvs[i + 3] = Vector2(0, old_v)
		uvs[i + 4] = Vector2(0, total_v)
		uvs[i + 5] = Vector2(1, total_v)
		
		for j in range(vertex_colors.size()):
			var age_in_indices = (i - j + vertex_colors.size()) % vertex_colors.size()
			var tail_threshold : float = vertex_colors.size() - fade_length
			if age_in_indices >= tail_threshold:
				var fade_factor : float = (age_in_indices - tail_threshold) / fade_length
				vertex_colors[j].a = clamp(1.0 - fade_factor, 0, 1)
		
		for j in range(6): # New segment
			vertex_colors[i + j] = Color.WHITE
		i += 6
		
		# always progress location, even when not skidding
		lastStart = pos
		oldPos = pos
		oldPosA = posA
		oldPosB = posB
	else: # extend the old mark if we are below the treshold
		var lastI : int = i - 6
		if lastI < 0:
			lastI += max_length
			
		# Calculate how much we've stretched since the start of this segment
		var stretch_dist = (pos - lastStart).length()
		var current_v = (total_v - (dist_interval / texture_length)) + (stretch_dist / texture_length)
		
		# update our last position with the new coords
		vertices[lastI + 1] = posA
		vertices[lastI + 4] = posB
		vertices[lastI + 5] = posA
		
		# Update the leading edge UVs
		uvs[lastI + 1] = Vector2(1, current_v)
		uvs[lastI + 4] = Vector2(0, current_v)
		uvs[lastI + 5] = Vector2(1, current_v)
		
		vertex_colors[lastI + 1].a = 1.0
		vertex_colors[lastI + 4].a = 1.0
		vertex_colors[lastI + 5].a = 1.0
		
		oldPosA = posA
		oldPosB = posB
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = vertex_colors

	# Create the Mesh
	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = arr_mesh

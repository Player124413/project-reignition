shader_type canvas_item;

uniform float wave_amplitude = 30.0;
uniform float wave_frequency = 140.0;

void vertex() {
	float pos = VERTEX.x * 0.5;
	VERTEX.y += cos((pos / wave_frequency)) * wave_amplitude;
}
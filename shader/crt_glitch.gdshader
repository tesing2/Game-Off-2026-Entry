shader_type canvas_item;

uniform float scanline_count : hint_range(0.0, 1000.0) = 400.0;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;

// Simple pseudo-random generator for glitch offsets
float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	
	// Apply horizontal screen glitch displacement lines
	if (glitch_intensity > 0.0) {
		float shaky = random(vec2(TIME * 0.1, uv.y * 10.0));
		if (shaky < glitch_intensity * 0.3) {
			uv.x += (random(vec2(TIME, uv.y)) - 0.5) * glitch_intensity * 0.2;
		}
	}
	
	// Scanlines effect
	float s = sin(uv.y * scanline_count * 3.14159 * 2.0);
	s = (s * 0.5 + 0.5) * 0.9 + 0.1; // Darken slightly along scanlines
	
	// Vignette & dark color styling for CRT screen
	vec4 col = vec4(vec3(0.05, 0.1, 0.08) * s, 1.0);
	
	// Combine with screen texture if desired, or make it a dark scanline overlay
	COLOR = col;
	COLOR.a = glitch_intensity; // Fade in based on glitch intensity
}
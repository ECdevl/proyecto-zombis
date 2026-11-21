shader_type sky;

// Mezcla dos panoramas equirectangulares en el cielo.
// SKY_COORDS es la UV esférica que Godot usa para los mapas panorámicos.
// source_color es obligatorio en Mobile/Forward+ para texturas sRGB.
uniform sampler2D sky_from : source_color, hint_default_black;
uniform sampler2D sky_to : source_color, hint_default_black;
uniform float sky_blend : hint_range(0.0, 1.0) = 0.0;

void sky() {
	vec3 color_from = texture(sky_from, SKY_COORDS).rgb;
	vec3 color_to = texture(sky_to, SKY_COORDS).rgb;
	COLOR = mix(color_from, color_to, clamp(sky_blend, 0.0, 1.0));
}

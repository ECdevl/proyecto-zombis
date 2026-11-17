shader_type canvas_item;

// Viñeta de pantalla reutilizable (poca vida / muerte).
// Se aplica a un ColorRect a pantalla completa con este ShaderMaterial.
// La distancia se mide en UV: 0.0 en el centro, 1.0 en las esquinas y
// ~0.707 en el centro de cada borde.
//
// La opacidad final es: mascara * intensity * pulso * vignette_color.a * COLOR.a.
// El color del ColorRect debe quedar en blanco con alpha 1; la visibilidad se
// controla con "intensity", no con la propiedad color del nodo.

// Color de la viñeta (rojo sangre por defecto).
uniform vec4 vignette_color : source_color = vec4(0.45, 0.02, 0.02, 1.0);

// Opacidad global. 0.0 = invisible, 1.0 = máxima.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// Radio normalizado donde empieza el oscurecimiento.
uniform float inner_radius : hint_range(0.0, 1.4) = 0.35;

// Ancho del degradado desde inner_radius hasta el borde.
uniform float softness : hint_range(0.001, 1.4) = 0.65;

// 0.0 = solo viñeta en los bordes; 1.0 = tinte plano en toda la pantalla
// (útil para la muerte).
uniform float screen_tint : hint_range(0.0, 1.0) = 0.0;

// Frecuencia del latido en Hz. 0.0 = sin latido.
uniform float pulse_speed : hint_range(0.0, 10.0) = 0.0;

// Amplitud del latido sumada a intensity. 0.0 = sin pulso.
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Distancia radial normalizada: 0.0 en el centro, 1.0 en las esquinas.
	vec2 centered = UV * 2.0 - 1.0;
	float distance_from_center = length(centered) / 1.41421356;

	// 0.0 dentro del radio interior, 1.0 al final del degradado.
	float edge = smoothstep(inner_radius, inner_radius + softness, distance_from_center);
	float mask = mix(edge, 1.0, screen_tint);

	// Latido: solo el lóbulo positivo del seno, con el pico marcado.
	float beat = pow(max(sin(TIME * TAU * pulse_speed), 0.0), 3.0);
	float pulse = 1.0 + pulse_strength * beat;

	float alpha = clamp(mask * intensity * pulse, 0.0, 1.0) * vignette_color.a * COLOR.a;
	COLOR = vec4(vignette_color.rgb, alpha);
}

shader_type sky;

uniform sampler2D source_panorama : filter_linear, source_color;

void sky() {
    // Sample the sky texture using sky coordinates
    COLOR = texture(source_panorama, SKY_COORDS).rgb;
}   
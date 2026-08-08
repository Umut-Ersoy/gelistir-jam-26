shader_type canvas_item;

// Godot 4 ekran dokusu örnekleyicisi (screen texture sampler)
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Piksel blok boyutu (Pikselleşme şiddeti: 1.0 = Normal, yükseltildikçe pikseller büyür)
uniform float pixel_size : hint_range(1.0, 128.0, 1.0) = 8.0;

// Efektin karıştırma yoğunluğu (0.0 = Orijinal ekran görüntüsü, 1.0 = Tam pikselleşme)
uniform float intensity : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	// Piksel ızgarasının ekran üzerindeki boyutunu hesapla
	vec2 grid = SCREEN_PIXEL_SIZE * pixel_size;
	
	// SCREEN_UV koordinatlarını piksel ızgarasının merkezine oturt
	vec2 pixelated_uv = floor(SCREEN_UV / grid) * grid + (grid * 0.5);
	
	// Intensity parametresine göre normal UV ile pikselleşmiş UV arasında geçiş sağla
	vec2 final_uv = mix(SCREEN_UV, pixelated_uv, intensity);
	
	// Alt katmandan gelen görüntüyü pikselleşmiş UV ile örnekle
	COLOR = texture(screen_texture, final_uv);
}

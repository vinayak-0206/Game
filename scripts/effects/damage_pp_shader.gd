extends ColorRect
class_name DamagePostProcess

## Chromatic aberration + vignette shader on damage
## Controlled by a `damage_intensity` value (0.0 = off, 1.0 = max)

var damage_intensity := 0.0

const SHADER_CODE := "
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);

	// Chromatic aberration — offset red and blue channels
	float aberration = intensity * 0.012;
	vec2 dir = normalize(uv - center) * aberration;
	float r = texture(TEXTURE, uv + dir).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - dir).b;

	// Vignette — darken edges, red-tinted
	float vignette = smoothstep(0.2, 0.9, dist);
	float vignette_strength = intensity * 0.7;

	vec3 col = vec3(r, g, b);
	col = mix(col, vec3(0.8, 0.0, 0.0), vignette * vignette_strength);

	// Overall red tint pulse
	float pulse = intensity * 0.15;
	col += vec3(pulse, 0.0, 0.0);

	float alpha = max(vignette * vignette_strength, aberration * 10.0);
	alpha = clamp(alpha, 0.0, 0.8);
	COLOR = vec4(col, alpha * intensity);
}
"

var _shader_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material = _shader_material


func _process(_delta: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("intensity", damage_intensity)
	visible = damage_intensity > 0.01

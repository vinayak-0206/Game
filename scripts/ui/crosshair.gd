extends Control
class_name DynamicCrosshair

## Dynamic crosshair with expanding lines, hit marker, and kill marker

var spread := 0.0  # Current weapon spread (0.0 to 1.0 normalized)
var base_gap := 6.0
var line_length := 10.0
var line_width := 2.0
var dot_radius := 2.0

# Hit marker state
var hit_marker_timer := 0.0
var hit_marker_duration := 0.25
var hit_marker_color := Color.WHITE
var is_kill := false
var kill_marker_timer := 0.0
var kill_marker_duration := 0.33


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if hit_marker_timer > 0:
		hit_marker_timer -= delta
	if kill_marker_timer > 0:
		kill_marker_timer -= delta
	queue_redraw()


func show_hit_marker() -> void:
	hit_marker_timer = hit_marker_duration
	hit_marker_color = Color.WHITE


func show_kill_marker() -> void:
	kill_marker_timer = kill_marker_duration
	hit_marker_timer = 0.0  # Kill overrides hit


func set_spread(weapon_spread: float, max_spread: float) -> void:
	if max_spread > 0:
		spread = clampf(weapon_spread / max_spread, 0.0, 1.0)
	else:
		spread = 0.0


func _draw() -> void:
	var center := size / 2.0
	var gap := base_gap + spread * 20.0

	# Center dot
	draw_circle(center, dot_radius, Color(1, 1, 1, 0.8))

	# Crosshair lines (top, bottom, left, right)
	var col := Color(1, 1, 1, 0.7)
	# Top
	draw_rect(Rect2(center.x - line_width / 2, center.y - gap - line_length, line_width, line_length), col)
	# Bottom
	draw_rect(Rect2(center.x - line_width / 2, center.y + gap, line_width, line_length), col)
	# Left
	draw_rect(Rect2(center.x - gap - line_length, center.y - line_width / 2, line_length, line_width), col)
	# Right
	draw_rect(Rect2(center.x + gap, center.y - line_width / 2, line_length, line_width), col)

	# Kill marker (red X)
	if kill_marker_timer > 0:
		var alpha := kill_marker_timer / kill_marker_duration
		var kill_col := Color(1.0, 0.15, 0.1, alpha)
		var marker_size := 10.0
		_draw_x(center, marker_size, 3.0, kill_col)
	# Hit marker (white X)
	elif hit_marker_timer > 0:
		var alpha := hit_marker_timer / hit_marker_duration
		var hit_col := Color(1.0, 1.0, 1.0, alpha)
		var marker_size := 8.0
		_draw_x(center, marker_size, 2.0, hit_col)


func _draw_x(center: Vector2, arm_size: float, width: float, color: Color) -> void:
	# Draw X shape with 4 lines from center
	# Top-left to bottom-right
	draw_line(center + Vector2(-arm_size, -arm_size), center + Vector2(arm_size, arm_size), color, width)
	# Top-right to bottom-left
	draw_line(center + Vector2(arm_size, -arm_size), center + Vector2(-arm_size, arm_size), color, width)

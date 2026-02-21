extends Control

## Multiplayer lobby — host/join, player list, start game

var ip_input: LineEdit
var status_label: Label
var player_list: VBoxContainer
var start_btn: Button
var host_btn: Button
var join_btn: Button
var back_btn: Button


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()
	NetworkManager.player_connected.connect(_refresh_player_list)
	NetworkManager.player_disconnected.connect(func(_id): _refresh_player_list(0, {}))
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.connection_failed.connect(_on_connection_failed)


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.custom_minimum_size = Vector2(400, 0)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "MULTIPLAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	# IP input
	var ip_label := Label.new()
	ip_label.text = "Server IP:"
	ip_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(ip_label)

	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.custom_minimum_size = Vector2(350, 40)
	ip_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(ip_input)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	host_btn = Button.new()
	host_btn.text = "HOST GAME"
	host_btn.custom_minimum_size = Vector2(170, 45)
	host_btn.add_theme_font_size_override("font_size", 18)
	host_btn.pressed.connect(_on_host)
	btn_row.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "JOIN GAME"
	join_btn.custom_minimum_size = Vector2(170, 45)
	join_btn.add_theme_font_size_override("font_size", 18)
	join_btn.pressed.connect(_on_join)
	btn_row.add_child(join_btn)

	# Status
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.modulate = Color(0.5, 0.8, 1.0)
	vbox.add_child(status_label)

	# Player list
	var list_title := Label.new()
	list_title.text = "PLAYERS:"
	list_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(list_title)

	player_list = VBoxContainer.new()
	player_list.add_theme_constant_override("separation", 5)
	vbox.add_child(player_list)

	# Start button (host only)
	start_btn = Button.new()
	start_btn.text = "START GAME"
	start_btn.custom_minimum_size = Vector2(350, 50)
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.visible = false
	start_btn.pressed.connect(_on_start_game)
	vbox.add_child(start_btn)

	# Back
	back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(350, 40)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_on_back)
	vbox.add_child(back_btn)


func _on_host() -> void:
	var err := NetworkManager.create_server()
	if err == OK:
		status_label.text = "Server started! Waiting for players..."
		host_btn.disabled = true
		join_btn.disabled = true
	else:
		status_label.text = "Failed to create server (error %d)" % err
		status_label.modulate = Color(1, 0.3, 0.3)


func _on_join() -> void:
	var ip := ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	status_label.text = "Connecting to %s..." % ip
	var err := NetworkManager.join_server(ip)
	if err != OK:
		status_label.text = "Failed to connect (error %d)" % err
		status_label.modulate = Color(1, 0.3, 0.3)
	else:
		host_btn.disabled = true
		join_btn.disabled = true


func _on_server_started() -> void:
	start_btn.visible = true
	_refresh_player_list(0, {})


func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"
	status_label.modulate = Color(1, 0.3, 0.3)
	host_btn.disabled = false
	join_btn.disabled = false


func _refresh_player_list(_id: int, _info: Dictionary) -> void:
	for child in player_list.get_children():
		child.queue_free()

	for peer_id in NetworkManager.player_info:
		var info = NetworkManager.player_info[peer_id]
		var lbl := Label.new()
		lbl.text = "  %s (ID: %d)" % [info.get("name", "Player"), peer_id]
		lbl.add_theme_font_size_override("font_size", 16)
		player_list.add_child(lbl)

	status_label.text = "%d player(s) connected" % NetworkManager.get_player_count()


func _on_start_game() -> void:
	if NetworkManager.is_server():
		_start_match.rpc()


@rpc("authority", "call_local", "reliable")
func _start_match() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/arena.tscn")


func _on_back() -> void:
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

extends Control

@export var game_scene_menu := "res://Menu/Menu.tscn"
@onready var clicker: AudioStreamPlayer2D = $Clicker

# Load your custom font
const CUSTOM_FONT = preload("res://Fonts/Bloodstreak - Demo.otf")

func _ready() -> void:
	_build_ui()
	_play_entrance_animation()

func _build_ui() -> void:
	# 1. Centering container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 2. Main Card Panel (Made wider to give text room to breathe)
	var main_panel := PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.custom_minimum_size = Vector2(840, 0)
	main_panel.add_theme_stylebox_override("panel", _create_panel_style(Color("#151926EE"), Color("#2c334d"), 16))
	center.add_child(main_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	main_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# 3. Header (Larger font sizes)
	var header := RichTextLabel.new()
	header.bbcode_enabled = true
	header.fit_content = true
	header.scroll_active = false
	header.text = "[center][font_size=42][b][color=#ffffff]ABOUT US[/color][/b][/font_size]\n[font_size=18][color=#7c88b0]2-PERSON INDIE DUO  •  GAME JAM EDITION[/color][/font_size][/center]"
	_apply_font_to_label(header)
	vbox.add_child(header)

	# 4. Creator Cards (Side by Side with bigger text)
	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(cards_hbox)

	cards_hbox.add_child(_create_creator_card(
		"Asborn",
		"Lead Developer, VFX & Composer",
		"Core programming, game mechanics, particle/VFX systems, and original soundtrack.",
		Color("#00d2ff")
	))

	cards_hbox.add_child(_create_creator_card(
		"Vion",
		"Lead Designer & Head of Graphics",
		"Art direction, character designs, environments, and all UI graphics.",
		Color("#ff6b9d")
	))

	# 5. Project Blurb (Larger readable body text)
	var blurb := RichTextLabel.new()
	blurb.bbcode_enabled = true
	blurb.fit_content = true
	blurb.scroll_active = false
	blurb.text = "[center][color=#a0abc8][font_size=17]Built from scratch under game jam constraints. Every line of code, pixel, and note was crafted specifically for this jam. Thanks for playing![/font_size][/color][/center]"
	_apply_font_to_label(blurb)
	vbox.add_child(blurb)

	# 6. Back Button (Bigger button & text)
	var btn_center := CenterContainer.new()
	vbox.add_child(btn_center)

	var back_btn := Button.new()
	back_btn.text = "  ← Back to Menu  "
	back_btn.custom_minimum_size = Vector2(220, 52)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.add_theme_font_override("font", CUSTOM_FONT)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.add_theme_color_override("font_color", Color("#ffffff"))
	back_btn.add_theme_stylebox_override("normal", _create_panel_style(Color("#252b42"), Color("#3e486e"), 8))
	back_btn.add_theme_stylebox_override("hover", _create_panel_style(Color("#323a59"), Color("#6c7ae0"), 8))
	back_btn.add_theme_stylebox_override("pressed", _create_panel_style(Color("#1b2030"), Color("#6c7ae0"), 8))
	back_btn.pressed.connect(_on_button_pressed)
	btn_center.add_child(back_btn)

func _create_creator_card(creator_name: String, role: String, desc: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_panel_style(Color("#1c2133F8"), accent.darkened(0.45), 12))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	card.add_child(m)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	# Increased font tags for names (24), roles (16), and descriptions (16)
	rtl.text = "[font_size=24][b][color=#ffffff]%s[/color][/b][/font_size]\n[font_size=16][b][color=#%s]%s[/color][/b][/font_size]\n\n[font_size=16][color=#b8c2dc]%s[/color][/font_size]" % [
		creator_name,
		accent.to_html(false),
		role,
		desc
	]
	_apply_font_to_label(rtl)
	m.add_child(rtl)
	return card

func _apply_font_to_label(rtl: RichTextLabel) -> void:
	rtl.add_theme_font_override("normal_font", CUSTOM_FONT)
	rtl.add_theme_font_override("bold_font", CUSTOM_FONT)

func _create_panel_style(bg_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func _play_entrance_animation() -> void:
	modulate.a = 0.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)

func _on_button_pressed() -> void:
	_play_click_and_change_scene(game_scene_menu)

func _play_click_and_change_scene(target_path: String) -> void:
	if clicker and clicker.stream:
		clicker.play()
	await get_tree().create_timer(0.12).timeout
	get_tree().change_scene_to_file(target_path)

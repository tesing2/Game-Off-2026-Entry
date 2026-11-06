extends Control

@export var game_scene_path := "res://MainGame/MonitorScreen.tscn"

@export var intro_textsV2: Array[String] = [
	"[font_size=35][color=#a0a8b0]The monitor hums in the quiet room, casting a [color=#64b5f6]cold blue glow[/color] across your desk...[/color][/font_size]",
	"[font_size=35][color=#e57373]Something isn't right.[/color] [color=#a0a8b0]The system feels hollow... watched.[/color][/font_size]",
	"[font_size=35][color=#a0a8b0]Your eyes drift toward the screen. Only [wave amp=30 freq=3][color=#ffb74d]one pathway[/color][/wave] remains open.[/color][/font_size]",
	"[font_size=35][color=#e53935][shake rate=20 level=8]Initialize the command line.[/shake][/color] Click the [color=#81c784]Terminal[/color]... if you dare.[/font_size]"
]

var current_text_index := 0
var is_typing := false
var game_started := false

@onready var terminal_button: Button = $Panel/TerminalButton
@onready var intro_label: RichTextLabel = $IntroPanel/IntroLabel
@onready var crt_overlay: ColorRect = $CRTOverlay # Reference to your new overlay node

func _ready() -> void:
	intro_label.bbcode_enabled = true
	intro_label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if not intro_label.is_connected("gui_input", _on_intro_label_gui_input):
		intro_label.gui_input.connect(_on_intro_label_gui_input)
	
	if terminal_button and not terminal_button.is_connected("pressed", _on_terminal_pressed):
		terminal_button.pressed.connect(_on_terminal_pressed)

	# Ensure overlay is hidden at start
	if crt_overlay and crt_overlay.material is ShaderMaterial:
		crt_overlay.material.set_shader_parameter("glitch_intensity", 0.0)

	_display_current_text()

func _on_intro_label_gui_input(event: InputEvent) -> void:
	if game_started:
		return
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_touch = (event is InputEventScreenTouch and event.pressed)
	if is_click or is_touch:
		advance_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if game_started:
		return
	if event.is_action_pressed("ui_accept"):
		advance_dialogue()

func advance_dialogue() -> void:
	if is_typing:
		is_typing = false
		intro_label.visible_characters = intro_label.get_total_character_count()
	elif current_text_index < intro_textsV2.size() - 1:
		current_text_index += 1
		_display_current_text()

func _display_current_text() -> void:
	if current_text_index < intro_textsV2.size():
		_typewrite_bbcode(intro_textsV2[current_text_index])

func _typewrite_bbcode(full_text: String) -> void:
	is_typing = true
	intro_label.text = full_text
	intro_label.visible_characters = 0
	
	var total_chars := intro_label.get_total_character_count()
	while intro_label.visible_characters < total_chars:
		if not is_typing:
			break
		intro_label.visible_characters += 1
		await get_tree().create_timer(0.03).timeout
		
	is_typing = false

func _on_terminal_pressed() -> void:
	if game_started:
		return
	game_started = true
	_play_dramatic_transition(game_scene_path)

func _play_dramatic_transition(target_path: String) -> void:
	intro_label.text = "[font_size=22][center][shake rate=30 level=12][color=#ff5252]CONNECTING TO TERMINAL...[/color][/shake][/center][/font_size]"
	intro_label.visible_characters = -1
	
	# Trigger dramatic CRT glitch transition via a Tween
	if crt_overlay and crt_overlay.material is ShaderMaterial:
		var tween = create_tween()
		tween.tween_method(
			func(val): crt_overlay.material.set_shader_parameter("glitch_intensity", val),
			0.0, 1.0, 0.5
		)
	
	await get_tree().create_timer(0.7).timeout
	get_tree().change_scene_to_file(target_path)

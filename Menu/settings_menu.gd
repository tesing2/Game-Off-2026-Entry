extends Control

@onready var master_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/MasterSlider
@onready var sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/SFXSlider
@onready var crt_toggle: CheckButton = $PanelContainer/MarginContainer/VBoxContainer/CRTToggle
@onready var fullscreen_toggle: CheckButton = $PanelContainer/MarginContainer/VBoxContainer/FullscreenToggle
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BackButton
@onready var clicker: AudioStreamPlayer2D = $Clicker

@export var game_scene_menu := "res://Menu/Menu.tscn"

func _ready() -> void:
	# Removed back_button connection here to prevent duplicate connection error (connected via Editor)
	crt_toggle.toggled.connect(_on_crt_toggled)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# Sync toggle state with actual window mode
	fullscreen_toggle.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Sync sliders to current audio bus levels safely
	var master_bus = AudioServer.get_bus_index("Master")
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus))
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))

func _on_master_volume_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	var db = linear_to_db(max(value, 0.0001))
	AudioServer.set_bus_volume_db(bus_idx, db)

func _on_sfx_volume_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		var db = linear_to_db(max(value, 0.0001))
		AudioServer.set_bus_volume_db(bus_idx, db)

func _on_crt_toggled(toggled_on: bool) -> void:
	if get_tree().root.has_node("Main/ScreenGlitchOverlay"):
		get_tree().root.get_node("Main/ScreenGlitchOverlay").visible = toggled_on

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Optional: re-center or reset window size when dropping out of fullscreen
		DisplayServer.window_set_size(Vector2i(1152, 648)) # Change to your preferred resolution width/height
func _on_back_button_pressed() -> void:
	_play_click_and_change_scene(game_scene_menu)

func _play_click_and_change_scene(target_path: String) -> void:
	if clicker and clicker.stream:
		clicker.play()
	await get_tree().create_timer(0.12).timeout
	get_tree().change_scene_to_file(target_path)

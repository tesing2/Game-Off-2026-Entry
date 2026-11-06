extends Control

@export var game_scene_desktop := "res://MainGame/Desktop/Desktop.tscn"
@export var game_scene_path_settings := "res://Menu/Settings.tscn"
@export var game_scene_path_about := "res://Menu/about.tscn"
@onready var clicker: AudioStreamPlayer2D = $Clicker


func _on_texture_button_pressed() -> void:
	_play_click_and_change_scene(game_scene_desktop)


func _play_click_and_change_scene(target_path: String) -> void:
	if clicker.stream:
		clicker.play()
	await get_tree().create_timer(0.12).timeout
	get_tree().change_scene_to_file(target_path)


func _on_texture_button_2_pressed() -> void:
	_play_click_and_change_scene(game_scene_path_settings)


func _on_texture_button_3_pressed() -> void:
	_play_click_and_change_scene(game_scene_path_about)

extends Control

@export var game_scene_path := "res://MainGame/MonitorScreen.tscn"
@export var game_scene_path_settings := "res://Menu/Settings.tscn"
@onready var click_sound_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _on_texture_button_pressed() -> void:
	_play_click_and_change_scene(game_scene_path)



func _play_click_and_change_scene(target_path: String) -> void:
	if click_sound_player.stream:
		click_sound_player.play()
	await get_tree().create_timer(0.12).timeout
	get_tree().change_scene_to_file(target_path)


func _on_texture_button_2_pressed() -> void:
	_play_click_and_change_scene(game_scene_path_settings)

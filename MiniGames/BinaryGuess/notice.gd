extends TextureRect

func _ready() -> void:
	visible = true

func _on_hitbox_pressed() -> void:
	visible = false

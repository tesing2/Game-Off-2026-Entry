extends Control

signal upgrade_purchased(upgrade_type: String, cost: float)

@onready var btn_auto: Button = $Panel/Button_Auto
@onready var btn_multi: Button = $Panel/Button_Multi


func _ready() -> void:
	btn_auto.pressed.connect(func(): emit_signal("upgrade_purchased", "cooling", 900.0))
	btn_multi.pressed.connect(func(): emit_signal("upgrade_purchased", "overclock", 1800.0))

func update_button_states(work_progress: float, cooling_level: float, max_cooling: float, seconds_per_click: float, base_seconds: float) -> void:
	# Liquid Cooling availability
	if cooling_level < max_cooling and work_progress >= 900.0:
		btn_auto.disabled = false
	else:
		btn_auto.disabled = true

	# Overclock availability
	if seconds_per_click <= base_seconds and work_progress >= 1800.0:
		btn_multi.disabled = false
	else:
		btn_multi.disabled = true

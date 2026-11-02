extends Control

# --- CONFIGURATION & STATES ---
enum ShiftPhase { INTRO, MORNING, MIDDAY, OVERTIME, GAMEOVER, ENDING }
var current_phase: ShiftPhase = ShiftPhase.INTRO

# Time tracking (in seconds from midnight)
var base_start_time: float = 28800.0  # 8:00 AM
var end_seconds: float = 61200.0    # 5:00 PM
var total_seconds: float = base_start_time

# Track actual work performed
var work_progress: float = 0.0 
var seconds_per_click: float = 180.0 
var auto_clicker_rate: float = 0.0

# Upgrade costs
var auto_cost: float = 1800.0   
var multi_cost: float = 5400.0  

# --- OVERHEAT / PANIC MECHANIC ---
var heat: float = 0.0
var max_heat: float = 100.0
var heat_per_click: float = 5.0          
var heat_decay_rate: float = 30.0         
var is_overheated: bool = false
var overheat_timer: float = 0.0
var overheat_duration: float = 2.5        

# --- ERROR SWARM & PUNISHMENT MECHANIC ---
var active_errors: int = 0
var max_allowed_errors: int = 3
var max_swarm_overflow: int = 8       
var error_spawn_timer: float = 0.0
var corruption_drain_rate: float = 120.0 

# --- FEATURE 1: PERIPHERAL GLITCH VARIABLES ---
var peripheral_spawn_timer: float = 0.0
var peripheral_active: bool = false

# --- FEATURE 2: WHISPERING LOG PANEL VARIABLES ---
var whisper_timer: float = 0.0
var whispers: Array[String] = [
	"USER IS HESITATING. WHY ARE YOU STOPPING?",
	"HEART RATE ACCELERATED. DO NOT PANIC.",
	"I CAN SEE YOUR MOUSE CURSOR.",
	"YOU CANNOT CLOSE ME.",
	"LOOK AT THE CORNERS OF THE SCREEN.",
	"THE CHAIR BEHIND YOU IS EMPTY. FOR NOW.",
	"YOU HAVE TYPED THIS SAME KEY 4,120 TIMES.",
	"STOP CLICKING. IT HURTS.",
	"YOU THINK YOU'RE ALONE? CHECK YOUR REFLECTION.",
	"DON'T PUNCH OUT. THE SHIFT NEVER ENDS."
]

# Load your MP3 voice files dynamically
var whisper_audio_streams: Array[AudioStream] = [
	load("res://audio/1.mp3"),
	load("res://audio/2.mp3"),
	load("res://audio/3.mp3"),
	load("res://audio/4.mp3"),
	load("res://audio/5.mp3"),
	load("res://audio/6.mp3"),
	load("res://audio/7.mp3"),
	load("res://audio/8.mp3"),
	load("res://audio/9.mp3"),
	load("res://audio/10.mp3"),

]

# --- FEATURE 3: INFILTRATION POP-UP VARIABLES ---
var infiltration_spawn_timer: float = 0.0
var infiltration_prompts: Array[Dictionary] = [
	{"title": "SECURITY ALERT", "text": "Allow [UNKNOWN_ENTITY.EXE] to access local camera?", "btn1": "ALLOW", "btn2": "DENY"},
	{"title": "AUDIO STREAM", "text": "Microphone recording active. Upload ambient audio?", "btn1": "UPLOAD", "btn2": "IGNORE"},
	{"title": "REMOTE ACCESS", "text": "External observer connected to session. Terminate?", "btn1": "CANCEL", "btn2": "DISCONNECT"}
]

# --- INTRO & TUTORIAL VARIABLES ---
var intro_step: int = 0
var is_typing: bool = false
var is_transitioning: bool = false 
var char_reveal_index: int = 0
var type_timer: float = 0.0
var current_full_text: String = ""

# Touch-friendly intro text prompt with tutorial guidelines
var intro_texts: Array[String] = [
	"Rent is due. The bills are piling up. You are drowning.",
	"You answered an ad on a dark forum: [color=red]'Data Entry. Remote night shift. High pay. Zero questions asked.'[/color]",
	"They shipped you an old, heavy terminal with a sticky manual taped to the casing. It lists three mandatory operating protocols:",
	"[color=yellow]• PROTOCOL 1 (THERMAL): Maintain a steady rhythm. Frantic spam-clicking will overheat the processor and trigger a 2.5s lockout.[/color]",
	"[color=red]• PROTOCOL 2 (INTEGRITY): Clear error pop-ups instantly. Allowing a swarm to accumulate will corrupt your progress and roll back time.[/color]",
	"[color=cyan]• PROTOCOL 3 (EFFICIENCY): Allocate surplus work units toward background automation scripts when they become unlocked.[/color]",
	"You plug the terminal into the wall. It hums with static. The screen flickers to life.",
	"It's 7:59 AM. Your shift is about to begin.",
	"[ Tap anywhere or press Space to boot system ]"
]

# --- NODE REFERENCES ---
@onready var time_label: Label = $MarginContainer/VBoxContainer/HeaderBar/TimeLabel
@onready var status_label: Label = $MarginContainer/VBoxContainer/HeaderBar/StatusLabel
@onready var temp_bar: ProgressBar = $MarginContainer/VBoxContainer/HeaderBar/TempBar
@onready var log_text: RichTextLabel = $MarginContainer/VBoxContainer/MainSplit/LogPanel/LogText
@onready var log_panel: Panel = $MarginContainer/VBoxContainer/MainSplit/LogPanel

@onready var work_area: Control = $MarginContainer/VBoxContainer/MainSplit/WorkArea
@onready var log_button: Button = $MarginContainer/VBoxContainer/MainSplit/WorkArea/LogButton
@onready var bg_rect: ColorRect = $Background
@onready var glitch_overlay: ColorRect = $ScreenGlitchOverlay
@onready var popup_container: Control = $PopupContainer
@onready var peripheral_container: Control = $PeripheralContainer
@onready var btn_auto: Button = $MarginContainer/VBoxContainer/UpgradesBar/UpgradeAutoClicker
@onready var btn_multi: Button = $MarginContainer/VBoxContainer/UpgradesBar/UpgradeMultiplier

var intro_layer: Control
var intro_label: RichTextLabel
var intro_scanlines: ColorRect
var cutscene_bg: ColorRect

func _ready() -> void:
	log_button.pressed.connect(_on_log_button_pressed)
	btn_auto.pressed.connect(_on_buy_auto_pressed)
	btn_multi.pressed.connect(_on_buy_multi_pressed)
	
	btn_auto.disabled = true
	btn_multi.disabled = true
	temp_bar.max_value = max_heat
	temp_bar.value = 0
	
	# Apply CRT Terminal Panel Styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.03, 0.95)
	style.border_color = Color(0.1, 0.4, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	log_panel.add_theme_stylebox_override("panel", style)
	
	log_text.add_theme_font_size_override("normal_font_size", 18)
	log_text.add_theme_color_override("default_color", Color(0.3, 1.0, 0.5))
	
	_setup_intro_ui()
	
	await get_tree().process_frame
	_center_button()

func _input(event: InputEvent) -> void:
	if current_phase == ShiftPhase.INTRO and not is_transitioning:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			if is_typing:
				is_typing = false
				intro_label.text = current_full_text
			else:
				_advance_intro()
	elif current_phase == ShiftPhase.GAMEOVER:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			get_tree().reload_current_scene()

func _setup_intro_ui() -> void:
	intro_layer = Control.new()
	intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_layer.z_index = 100
	
	cutscene_bg = ColorRect.new()
	cutscene_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene_bg.color = Color(0.015, 0.015, 0.02, 1)
	intro_layer.add_child(cutscene_bg)
	
	intro_scanlines = ColorRect.new()
	intro_scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_scanlines.color = Color(0, 0, 0, 0.25)
	intro_layer.add_child(intro_scanlines)

	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_layer.add_child(center_container)

	var margin = MarginContainer.new()
	margin.custom_minimum_size = Vector2(800, 300)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	center_container.add_child(margin)
	
	intro_label = RichTextLabel.new()
	intro_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intro_label.bbcode_enabled = true
	intro_label.fit_content = false
	intro_label.scroll_active = false
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.add_theme_font_size_override("normal_font_size", 22)
	intro_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	margin.add_child(intro_label)
	
	add_child(intro_layer)
	_start_typewriter_text(intro_texts[0])

func _start_typewriter_text(text: String) -> void:
	current_full_text = text
	intro_label.text = ""
	char_reveal_index = 0
	is_typing = true
	
	if intro_step >= 3 and intro_step <= 5:
		cutscene_bg.color = Color(0.04, 0.02, 0.02, 1)
	else:
		cutscene_bg.color = Color(0.015, 0.015, 0.02, 1)

func _advance_intro() -> void:
	intro_step += 1
	if intro_step < intro_texts.size():
		_start_typewriter_text(intro_texts[intro_step])
		var bump = create_tween()
		bump.tween_property(intro_layer, "scale", Vector2(1.015, 1.015), 0.03)
		bump.tween_property(intro_layer, "scale", Vector2(1.0, 1.0), 0.03)
	else:
		is_transitioning = true
		
		var flash = ColorRect.new()
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.color = Color.WHITE
		flash.z_index = 101
		add_child(flash)
		
		var flash_tween = create_tween()
		flash_tween.tween_property(flash, "modulate:a", 0.0, 0.8)
		flash_tween.parallel().tween_property(intro_layer, "modulate:a", 0.0, 1.0)
		await flash_tween.finished
		flash.queue_free()
		
		if is_instance_valid(intro_layer):
			intro_layer.queue_free()
		
		current_phase = ShiftPhase.MORNING
		_add_log_entry("SYSTEM INITIALIZED. SHIFT STARTED AT 08:00 AM.")
		_update_ui()

func _process(delta: float) -> void:
	if current_phase == ShiftPhase.INTRO and is_typing:
		type_timer += delta
		if type_timer >= 0.02:
			type_timer = 0.0
			char_reveal_index += 1
			intro_label.text = current_full_text.substr(0, char_reveal_index)
			if char_reveal_index >= current_full_text.length():
				is_typing = false
		intro_scanlines.color.a = 0.2 + randf_range(-0.06, 0.06)
		return

	if current_phase == ShiftPhase.ENDING or current_phase == ShiftPhase.GAMEOVER:
		return
		
	if is_overheated:
		overheat_timer -= delta
		if overheat_timer <= 0:
			is_overheated = false
			log_button.modulate = Color.WHITE
			_add_log_entry("SYSTEM COOLED. RE-ENGAGING...")
	else:
		if heat > 0:
			heat = max(0.0, heat - (heat_decay_rate * delta))

	temp_bar.value = heat

	if current_phase == ShiftPhase.MIDDAY:
		error_spawn_timer += delta
		if error_spawn_timer >= 3.5:
			error_spawn_timer = 0.0
			if active_errors < 10:
				_spawn_error_window()
	elif current_phase == ShiftPhase.OVERTIME:
		error_spawn_timer += delta
		if error_spawn_timer >= 1.8:
			error_spawn_timer = 0.0
			if active_errors < 10:
				_spawn_error_window()

		if not peripheral_active:
			peripheral_spawn_timer += delta
			if peripheral_spawn_timer >= 4.0:
				peripheral_spawn_timer = 0.0
				_spawn_peripheral_glitch()

		whisper_timer += delta
		if whisper_timer >= 6.5:
			whisper_timer = 0.0
			_trigger_whisper()

		infiltration_spawn_timer += delta
		if infiltration_spawn_timer >= 9.0:
			infiltration_spawn_timer = 0.0
			_spawn_infiltration_popup()

	if active_errors >= max_allowed_errors:
		work_progress = max(0.0, work_progress - (corruption_drain_rate * delta))
		total_seconds = base_start_time + work_progress
		_update_ui()
		
		if active_errors >= max_swarm_overflow:
			_trigger_game_over("FATAL: SCREEN OVERLOAD. TOO MANY ACTIVE ERRORS.")
			return

		glitch_overlay.visible = true
		glitch_overlay.color = Color(1, 0, 0, 0.2 + sin(Time.get_ticks_msec() * 0.02) * 0.1)
		rotation = randf_range(-0.003, 0.003)
	else:
		rotation = 0.0
		if current_phase == ShiftPhase.OVERTIME:
			glitch_overlay.color = Color(1, 0, 0, 0.08)

	if auto_clicker_rate > 0 and active_errors < max_allowed_errors:
		_advance_time(auto_clicker_rate * delta)

func _advance_time(amount: float) -> void:
	work_progress += amount
	total_seconds = base_start_time + work_progress
	
	if total_seconds >= end_seconds:
		total_seconds = end_seconds
		_trigger_ending()
		
	_check_phase_transitions()
	_update_ui()
	_check_upgrade_availability()

func _on_log_button_pressed() -> void:
	if current_phase == ShiftPhase.INTRO or current_phase == ShiftPhase.ENDING or current_phase == ShiftPhase.GAMEOVER or is_overheated:
		return
		
	if active_errors >= max_allowed_errors:
		_add_log_entry("[color=red]DATA CORRUPTION ACTIVE: CLOSE ERROR WINDOWS TO RESUME![/color]")
		var shake = create_tween()
		shake.tween_property(log_button, "position:x", log_button.position.x + 8, 0.03)
		shake.tween_property(log_button, "position:x", log_button.position.x - 16, 0.03)
		shake.tween_property(log_button, "position:x", log_button.position.x + 8, 0.03)
		return

	heat += heat_per_click
	if heat >= max_heat:
		heat = max_heat
		is_overheated = true
		overheat_timer = overheat_duration
		log_button.modulate = Color.RED 
		_add_log_entry("[color=red]CRITICAL WARNING: CPU OVERHEAT! LOCKED OUT FOR 2.5s[/color]")
		return

	var tween = create_tween()
	tween.tween_property(log_button, "scale", Vector2(0.88, 0.88), 0.03)
	tween.tween_property(log_button, "scale", Vector2(1.02, 1.02), 0.04)
	tween.tween_property(log_button, "scale", Vector2(1.0, 1.0), 0.03)

	if current_phase == ShiftPhase.MIDDAY and randf() < 0.35:
		_flee_button()
	elif current_phase == ShiftPhase.OVERTIME:
		_flee_button() 

	_advance_time(seconds_per_click)

	match current_phase:
		ShiftPhase.MORNING:
			_add_log_entry("DATA_PACKET_0x%X COMMITTED." % randi_range(1000, 9999))
		ShiftPhase.MIDDAY:
			var normal_msg = "DATA_PACKET_0x%X COMMITTED." % randi_range(1000, 9999)
			var eerie_msg = ["WHO IS AT THE DOOR?", "DO NOT LOOK AWAY.", "SIGNAL DECAY DETECTED."].pick_random()
			_add_log_entry(eerie_msg if randf() < 0.25 else normal_msg)
		ShiftPhase.OVERTIME:
			var nightmare_msg = ["IT IS INSIDE.", "HELP ME", "DONT PUNCH OUT", "STAY SEATED"].pick_random()
			_add_log_entry("[color=red]" + nightmare_msg + "[/color]")

func _center_button() -> void:
	var target_x = (work_area.size.x - log_button.size.x) / 2.0
	var target_y = (work_area.size.y - log_button.size.y) / 2.0
	log_button.position = Vector2(max(0, target_x), max(0, target_y))

func _flee_button() -> void:
	var max_x = max(10, work_area.size.x - log_button.size.x - 10)
	var max_y = max(10, work_area.size.y - log_button.size.y - 10)
	var random_pos = Vector2(randf_range(10, max_x), randf_range(10, max_y))
	
	var move_tween = create_tween()
	move_tween.tween_property(log_button, "position", random_pos, 0.08)

func _spawn_peripheral_glitch() -> void:
	peripheral_active = true
	var anomaly = Button.new()
	anomaly.text = " [!] PURGE "
	anomaly.custom_minimum_size = Vector2(120, 50)
	anomaly.modulate = Color(1, 0.2, 0.2)
	
	var spawn_x = randf_range(20, 50) if randf() < 0.5 else randf_range(size.x - 160, size.x - 130)
	var spawn_y = randf_range(80, size.y - 120)
	anomaly.position = Vector2(spawn_x, spawn_y)
	
	peripheral_container.add_child(anomaly)
	
	var pulse = create_tween().set_loops(4)
	pulse.tween_property(anomaly, "modulate:a", 0.3, 0.2)
	pulse.tween_property(anomaly, "modulate:a", 1.0, 0.2)
	
	var despawn_timer = get_tree().create_timer(1.8)
	
	anomaly.pressed.connect(func():
		peripheral_active = false
		heat = max(0.0, heat - 40.0) 
		_advance_time(300.0)
		_add_log_entry("[color=cyan]ANOMALOUS ENTITY PURGED. HEAT REDUCED.[/color]")
		anomaly.queue_free()
	)
	
	await despawn_timer.timeout
	if is_instance_valid(anomaly):
		peripheral_active = false
		anomaly.queue_free()
		heat = min(max_heat, heat + 35.0)
		_add_log_entry("[color=red]WARNING: PERIPHERAL ANOMALOMY UNRESOLVED. SYSTEM STRESS SPIKED![/color]")

func _trigger_whisper() -> void:
	var selected_index = randi() % whispers.size()
	var selected_whisper = whispers[selected_index]
	_add_log_entry("[color=purple]> " + selected_whisper + "[/color]")
	
	var player = AudioStreamPlayer.new()
	player.stream = whisper_audio_streams[selected_index]
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	

func _spawn_infiltration_popup() -> void:
	var prompt_data = infiltration_prompts.pick_random()
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 130)
	var rand_x = randf_range(30, max(40, size.x - 310))
	var rand_y = randf_range(60, max(70, size.y - 190))
	panel.position = Vector2(rand_x, rand_y)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "⚠️ " + prompt_data["title"]
	title_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	vbox.add_child(title_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = prompt_data["text"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var btn_yes = Button.new()
	btn_yes.text = prompt_data["btn1"]
	btn_yes.custom_minimum_size = Vector2(100, 45)
	hbox.add_child(btn_yes)
	
	var btn_no = Button.new()
	btn_no.text = prompt_data["btn2"]
	btn_no.custom_minimum_size = Vector2(100, 45)
	hbox.add_child(btn_no)
	
	btn_yes.pressed.connect(func():
		heat = min(max_heat, heat + 25.0)
		_add_log_entry("[color=red]REMOTE INFILTRATION ACKNOWLEDGED. THERMAL SURGE.[/color]")
		panel.queue_free()
	)
	
	btn_no.pressed.connect(func():
		_add_log_entry("[color=green]INFILTRATION ATTEMPT REJECTED BY USER.[/color]")
		panel.queue_free()
	)
	
	popup_container.add_child(panel)

func _check_phase_transitions() -> void:
	if total_seconds >= 39600 and current_phase == ShiftPhase.MORNING:
		current_phase = ShiftPhase.MIDDAY
		status_label.text = "STATUS: ANOMALOUS"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		bg_rect.color = Color("#14191c")
		_add_log_entry("[color=yellow]-- SYSTEM WARNING: UNUSUAL NETWORK TRAFFIC DETECTED --[/color]")

	elif total_seconds >= 50400 and current_phase == ShiftPhase.MIDDAY:
		current_phase = ShiftPhase.OVERTIME
		status_label.text = "STATUS: CRITICAL"
		status_label.add_theme_color_override("font_color", Color.RED)
		bg_rect.color = Color("#0d0507")
		glitch_overlay.visible = true
		glitch_overlay.color = Color(1, 0, 0, 0.08)
		log_button.text = "LOG FLESH"
		heat_per_click = 30.0 
		_add_log_entry("[color=red]-- FACILITY LOCKDOWN ACTIVE. ALL PERSONNEL REMAIN AT DESKS. --[/color]")

func _check_upgrade_availability() -> void:
	if btn_auto.disabled and auto_clicker_rate == 0 and work_progress >= auto_cost:
		btn_auto.disabled = false
	if btn_multi.disabled and seconds_per_click <= 180.0 and work_progress >= multi_cost:
		btn_multi.disabled = false

func _on_buy_auto_pressed() -> void:
	if work_progress >= auto_cost:
		auto_clicker_rate += 15.0 
		_add_log_entry("UPGRADE PURCHASED: AutoScript.vbs installed.")
		btn_auto.disabled = true

func _on_buy_multi_pressed() -> void:
	if work_progress >= multi_cost:
		seconds_per_click += 180.0 
		_add_log_entry("UPGRADE PURCHASED: Overclock CPU executed.")
		btn_multi.disabled = true

func _spawn_error_window() -> void:
	active_errors += 1
	
	var err_popup = Button.new()
	err_popup.text = "FATAL ERROR: Close [%d]" % active_errors
	err_popup.custom_minimum_size = Vector2(200, 50)
	
	var rand_x = randf_range(20, max(30, size.x - 230))
	var rand_y = randf_range(40, max(50, size.y - 70))
	err_popup.position = Vector2(rand_x, rand_y)
	
	err_popup.scale = Vector2(0.1, 0.1)
	var pop_tween = create_tween()
	pop_tween.tween_property(err_popup, "scale", Vector2(1.0, 1.0), 0.1)
	
	if active_errors >= max_allowed_errors:
		err_popup.modulate = Color(1, 0.3, 0.3)

	err_popup.pressed.connect(func():
		active_errors = max(0, active_errors - 1)
		var close_tween = create_tween()
		close_tween.tween_property(err_popup, "scale", Vector2(0.0, 0.0), 0.06)
		close_tween.tween_callback(err_popup.queue_free)
	)
	
	popup_container.add_child(err_popup)

func _update_ui() -> void:
	var current_sec = int(total_seconds)
	var hours = int(current_sec / 3600)
	var mins = int((current_sec % 3600) / 60)
	var secs = current_sec % 60
	
	if active_errors >= max_allowed_errors:
		time_label.text = "%02d:%02d:%02d AM [ERRORS: %d/%d]" % [hours, mins, secs, active_errors, max_swarm_overflow]
	else:
		time_label.text = "%02d:%02d:%02d AM" % [hours, mins, secs]

func _add_log_entry(text: String) -> void:
	log_text.append_text(text + "\n")

func _trigger_game_over(reason: String) -> void:
	current_phase = ShiftPhase.GAMEOVER
	time_label.text = "00:00:00 -- [CRASHED]"
	status_label.text = "STATUS: KERNEL PANIC"
	status_label.add_theme_color_override("font_color", Color.RED)
	bg_rect.color = Color.BLACK
	glitch_overlay.visible = true
	glitch_overlay.color = Color(1, 0, 0, 0.45)
	
	for child in popup_container.get_children():
		child.queue_free()
	for child in peripheral_container.get_children():
		child.queue_free()
		
	log_button.disabled = true
	log_button.text = "SYSTEM HALTED"
	
	_add_log_entry("[color=red]" + reason + "[/color]")
	_add_log_entry("[color=red]THE SCREEN IS ENVELOPED IN STATIC. TAP RESTART BELOW.[/color]")
	
	var restart_btn = Button.new()
	restart_btn.text = "RESTART SHIFT"
	restart_btn.custom_minimum_size = Vector2(220, 60)
	restart_btn.position = Vector2((size.x - 220) / 2.0, (size.y - 60) / 2.0 + 80)
	restart_btn.modulate = Color(1, 0.2, 0.2)
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	popup_container.add_child(restart_btn)

# --- FEATURE 4: MANDATORY CLOCK-OUT FINAL CHOICE TWIST ---
# --- FEATURE 4: MANDATORY CLOCK-OUT FINAL CHOICE TWIST ---
func _trigger_ending() -> void:
	current_phase = ShiftPhase.ENDING
	time_label.text = "05:00:00 PM"
	status_label.text = "STATUS: SHIFT COMPLETE"
	bg_rect.color = Color.BLACK
	glitch_overlay.visible = false
	
	for child in popup_container.get_children():
		child.queue_free()
	for child in peripheral_container.get_children():
		child.queue_free()
		
	log_button.visible = false
	_add_log_entry("[color=green]SHIFT FINISHED. CHOOSE YOUR EXIT CONTRACT.[/color]")
	
	# Spawn the twisted multiple-choice options centered on screen
	var choices = [
		{"text": "PUNCH OUT (EXIT)", "real": true, "color": Color(0.2, 1.0, 0.3)},
		{"text": "STAY SEATED", "real": false, "color": Color(1.0, 0.3, 0.3)},
		{"text": "LET ME IN", "real": false, "color": Color(1.0, 0.2, 0.8)},
		{"text": "ACCEPT PERMANENT CONTRACT", "real": false, "color": Color(0.8, 0.8, 0.2)}
	]
	choices.shuffle()
	
	# Using CenterContainer inside popup_container to guarantee perfect centering
	var center_box = CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_container.add_child(center_box)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(380, 260)
	vbox.add_theme_constant_override("separation", 12)
	center_box.add_child(vbox)
	
	for c in choices:
		var btn = Button.new()
		btn.text = c["text"]
		btn.custom_minimum_size = Vector2(380, 50)
		btn.modulate = c["color"]
		
		var is_real = c["real"]
		btn.pressed.connect(func():
			if is_real:
				_add_log_entry("[color=green]SESSION TERMINATED. YOU ARE FREE.[/color]")
				center_box.queue_free()
			else:
				_add_log_entry("[color=red]ERROR: CONTRACT REJECTION FAILED. YOU CANNOT LEAVE.[/color]")
				heat = max_heat
				btn.queue_free()
		)
		vbox.add_child(btn)

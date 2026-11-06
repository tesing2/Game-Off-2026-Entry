extends Control
## Main terminal screen: intro cutscene, clicker loop, overheat / error-swarm
## mechanics, horror escalation phases and the final "clock-out" choice.

# =============================================================================
# CONSTANTS
# =============================================================================
enum ShiftPhase { INTRO, MORNING, MIDDAY, OVERTIME, GAMEOVER, ENDING }

# Clock (seconds from midnight)
const START_TIME := 28800.0     # 8:00 AM
const MIDDAY_TIME := 39600.0    # 11:00 AM -> cinematic reckoning
const OVERTIME_TIME := 50400.0  # 2:00 PM  -> critical phase
const END_TIME := 61200.0       # 5:00 PM

# Audio paths
const TYPE_SOUND_PATH := "res://audio/Cutscene/Keyboard typing Sound Effects.mp3"
const WHISPER_AUDIO_PATH := "res://audio/%d.mp3"
const WHISPER_AUDIO_COUNT := 10
const CUTSCENE_VOICE_PATHS: Array[String] = [
	"res://audio/Cutscene/VoiceTerror1.mp3",
	"res://audio/Cutscene/VoiceTerror2.mp3",
	"res://audio/Cutscene/VoiceTerror3.mp3",
	"res://audio/Cutscene/VoiceTerror4.mp3",
]
const CUTSCENE_VOICE_PLAYLIST: Array[int] = [1, 2]  # voice lines played during the reckoning
const CAMERA_FEED_AUDIO_INDEX := 2                  # whisper clip reused for the camera scare
const CAMERA_FEED_TEXTURE := "res://Sprites/Char (With BG).png"

# Jumpscare (plays right after STATUS: INTERCEPTED)
const JUMPSCARE_TEXTURE := "res://Sprites/Jumpscare (With BG).png"
const JUMPSCARE_AUDIO_PATH := "res://audio/jumpscare.mp3"
const JUMPSCARE_DELAY := 0.0  # silent, dark beat before it hits
const JUMPSCARE_HOLD := 2.0    # how long the image stays after the shake

# Upgrades
const AUTO_RATE_BONUS := 15.0
const MULTI_CLICK_BONUS := 180.0
const BASE_SECONDS_PER_CLICK := 180.0

# Heat
const OVERTIME_HEAT_PER_CLICK := 30.0
const HEAT_PULSE_THRESHOLD := 80.0
const PURGE_HEAT_RELIEF := 40.0
const PURGE_TIME_REWARD := 300.0
const PURGE_MISSED_HEAT := 35.0
const INFILTRATION_HEAT := 25.0

# Spawning
const ERROR_INTERVAL_MIDDAY := 3.5
const ERROR_INTERVAL_OVERTIME := 1.8
const MAX_ERRORS_ON_SCREEN := 10
const PERIPHERAL_INTERVAL := 4.0
const PERIPHERAL_LIFETIME := 1.8
const WHISPER_INTERVAL := 6.5
const INFILTRATION_INTERVAL := 9.0
const FORCED_POPUP_TIMEOUT := 3.0
const CAMERA_FEED_DURATION := 3.5

# Intro
const TYPE_INTERVAL := 0.03
const TUTORIAL_STEPS := [3, 4, 5]   # intro steps that get the reddish background
const INPUT_DEBOUNCE_MSEC := 120    # touch also emits an emulated mouse click

# Log
const MAX_LOG_PARAGRAPHS := 300

# Pacing director (calm -> spike rhythm)
const BUILD_DURATION := 30.0          # seconds of normal pressure
const LULL_DURATION := 12.0           # seconds of calm between waves
const LULL_HEAT_RELIEF := 20.0
const SPIKE_ERRORS := 2               # errors dumped at once when a lull ends
const ERROR_INTERVAL_FINAL := 1.3     # final stretch: relentless
const FAKE_UPDATE_DURATION := 3.5

# Story fragments & endings
const MESSAGE_LIFETIME := 14.0        # how long the notification popup stays active
const TRUE_ENDING_FRAGMENTS := 4      # messages needed to unlock the hidden ending
const PUNCH_OUT_MAX_ACCEPTED := 2     # more "accepted" infiltrations = PUNCH OUT fails
const SAVE_PATH := "user://progress.cfg"
const META_INTRO_SEEN := "intro_seen" # survives scene reloads, so restarts skip the intro

# =============================================================================
# TUNABLES
# =============================================================================
@export_group("Balance")
@export var seconds_per_click: float = BASE_SECONDS_PER_CLICK
@export var auto_cost: float = 1800.0
@export var multi_cost: float = 5400.0
@export var heat_per_click: float = 5.0
@export var heat_decay_rate: float = 30.0
@export var overheat_duration: float = 2.5
@export var max_heat: float = 100.0
@export var max_allowed_errors: int = 3
@export var max_swarm_overflow: int = 8
@export var corruption_drain_rate: float = 120.0

@export_group("Camera Feed")
## Drag your sprite here. If empty, CAMERA_FEED_TEXTURE (a path) is tried instead.
@export var camera_feed_texture: Texture2D
## Testing helper: press F1 to trigger the camera feed instantly.
@export var debug_keys: bool = false

@export_group("Jumpscare")
## Turn off to skip the jumpscare (e.g. while testing other things).
@export var jumpscare_enabled: bool = true
## Optional: drag your sprite here. If empty, JUMPSCARE_TEXTURE (a path) is tried instead.
@export var jumpscare_texture: Texture2D

# =============================================================================
# STATE
# =============================================================================
var current_phase: ShiftPhase = ShiftPhase.INTRO
var total_seconds: float = START_TIME
var work_progress: float = 0.0
var auto_clicker_rate: float = 0.0

# Overheat
var heat: float = 0.0
var is_overheated: bool = false
var overheat_timer: float = 0.0

# Error swarm
var active_errors: int = 0
var error_spawn_timer: float = 0.0

# Horror features
var peripheral_spawn_timer: float = 0.0
var peripheral_active: bool = false
var whisper_timer: float = 0.0
var infiltration_spawn_timer: float = 0.0
var cutscene_active: bool = false   # pauses hazards + auto script during the reckoning

# Pacing director
var in_lull: bool = false
var pacing_timer: float = 0.0
var final_stretch: bool = false     # last 30 minutes: no more lulls
var click_lock_timer: float = 0.0   # fake "system update" freezes clicking briefly
var event_index: int = 0            # next scripted event on the timeline

# Story / endings
var fragment_index: int = 0         # next message to deliver
var fragments_found: Array[String] = []
var message_active: bool = false
var infiltrations_accepted: int = 0
var camera_scares: int = 0
var endings_found: Array[String] = []   # persisted between runs
var ending_shown: bool = false
var player_location: String = "UNKNOWN LOCATION" # Real-world geolocation storage

# Intro / tutorial
var intro_step: int = 0
var is_typing: bool = false
var is_transitioning: bool = false
var char_reveal_index: int = 0
var intro_total_chars: int = 0
var type_timer: float = 0.0
var _last_confirm_msec: int = -1000

# Audio
var typing_audio_player: AudioStreamPlayer
var type_sound: AudioStream
var whisper_audio_streams: Array[AudioStream] = []
var cutscene_voice_over: Array[AudioStream] = []
var jumpscare_sound: AudioStream
var jumpscare_audio_player: AudioStreamPlayer  # Pre-cached player for instant playback

# Tween handles (so repeated clicks don't stack / drift)
var _click_tween: Tween
var _shake_tween: Tween
var _jolt_tween: Tween
var _flee_tween: Tween
var _base_position: Vector2

# --- Text data ---------------------------------------------------------------
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

# "forced" popups have no real choice: they auto-trigger the camera scare.
var infiltration_prompts: Array[Dictionary] = [
	{"title": "SECURITY ALERT", "text": "Allow [UNKNOWN_ENTITY.EXE] to access local camera?", "btn1": "ALLOW", "btn2": "DENY", "forced": true},
	{"title": "AUDIO STREAM", "text": "Microphone recording active. Upload ambient audio?", "btn1": "UPLOAD", "btn2": "IGNORE", "forced": false},
	{"title": "REMOTE ACCESS", "text": "External observer connected to session. Terminate?", "btn1": "CANCEL", "btn2": "DISCONNECT", "forced": false}
]

# Each line is logged, then the cutscene waits `delay` seconds.
var reckoning_script: Array[Dictionary] = [
	{"text": "[color=red]>>> KERNEL PANIC: CONNECTION HIJACKED.[/color]", "delay": 2.0},
	{"text": "[color=gray]Did you really think you could run away from what you broke?[/color]", "delay": 3.0},
	{"text": "[color=red]You changed your phone. You changed your name. You thought you were safe.[/color]", "delay": 3.2},
	{"text": "[color=white]Every click you made today wasn't data entry. It was a countdown.[/color]", "delay": 3.5},
	{"text": "[color=red]I am not a virus. I am your past, and I am finally catching up.[/color]", "delay": 4.0},
	{"text": "[color=yellow]----------------------------------------------------[/color]\n[color=red]STATUS: ANOMALOUS. THERE IS NO WAY OUT OF THIS SHIFT.[/color]", "delay": 3.0},
]

# --- STORY MESSAGES ----------------------------------------------------------
var story_fragments: Array[Dictionary] = [
	{"id": "onboarding", "time": 32400.0, "from": "HR_AUTO", "subject": "Onboarding // Employee ID",
	 "body": "Your employee ID field has been left blank. This is intentional.\n\nWe already know who you are. Please do not update your records."},
	{"id": "operator", "time": 36000.0, "from": "M. OKAFOR (PREVIOUS OPERATOR)", "subject": "READ THIS BEFORE 11:00",
	 "body": "I only have a minute before it notices this window.\n\nDon't look at the numbers. Look at what the packets are. They aren't data. They're names.\n\nAt the end of the shift it will offer you a way out. Don't trust the obvious door."},
	{"id": "packet", "time": 41400.0, "from": "SYSTEM_LOG", "subject": "PACKET 0x2F4A // DECODED",
	 "body": "SUBJECT: [REDACTED]\nLAST KNOWN ADDRESS: 14 MARLOW STREET\nSTATUS: RESOLVED\n\nEvery packet you commit marks one more entry as resolved. The list is almost finished.\n\nYour name is on it."},
	{"id": "leak", "time": 45000.0, "from": "UNKNOWN", "subject": "re: the leak",
	 "body": "You called it an accident. You said no one would be hurt.\n\nThe database you left open held 4,120 names. That is the number on your keyboard now. Every key you press is one of them."},
	{"id": "maintenance", "time": 48600.0, "from": "FACILITY_MAINT", "subject": "Terminal #7 // do not forward",
	 "body": "PUNCH OUT only releases operators who kept the observer out.\n\nAnyone who let it in too many times is already on the other side of the glass.\n\nDo not tell the operator."},
	{"id": "voicemail", "time": 54000.0, "from": "VOICEMAIL TRANSCRIPT", "subject": "(1 new) 'It's me.'",
	 "body": "'...It's me. You gave this address to the forum, remember?\n\nI'm not angry anymore. I just want you to say it out loud.\n\nSay what you did.'"},
]

# --- SCRIPTED TIMELINE ---
var scripted_events: Array[Dictionary] = [
	{"time": 34200.0, "type": "flicker"},        # 09:30
	{"time": 37800.0, "type": "fake_update"},    # 10:30
	{"time": 43200.0, "type": "blackout"},       # 12:00
	{"time": 47700.0, "type": "flicker"},        # 13:15
	{"time": 55800.0, "type": "blackout"},       # 15:30
	{"time": 59400.0, "type": "final_stretch"},  # 16:30
]

var lull_messages: Array[String] = [
	"The hum fades. Everything is quiet.",
	"The fans spin down. You can hear yourself breathing.",
	"Nothing on the screen moves. Something is waiting.",
	"A calm settles over the terminal. It does not feel like safety.",
]

# --- ENDINGS ---
var endings: Dictionary = {
	"escaped": {
		"title": "ENDING: ESCAPED", "color": Color(0.2, 1.0, 0.3),
		"lines": ["SESSION TERMINATED. YOU ARE FREE.", "You step outside. The ad is still online. Someone else is already answering it."]
	},
	"compliant": {
		"title": "ENDING: COMPLIANT", "color": Color(1.0, 0.6, 0.2),
		"lines": ["PUNCH OUT RECORDED. STATUS: COMPLIANT.", "You let the observer in too many times. The door was never connected to anything.", "TOMORROW'S SHIFT BEGINS IN 00:00:03."]
	},
	"loop": {
		"title": "ENDING: THE LOOP", "color": Color(1.0, 0.3, 0.3),
		"lines": ["You stay seated. The clock resets to 08:00 AM.", "You were never the first operator. You will not be the last."]
	},
	"possessed": {
		"title": "ENDING: LET IN", "color": Color(1.0, 0.2, 0.8),
		"lines": ["You open the door. The chair behind you is no longer empty.", "The terminal is still running. It just isn't you typing anymore."]
	},
	"employee": {
		"title": "ENDING: EMPLOYEE FOR LIFE", "color": Color(0.8, 0.8, 0.2),
		"lines": ["CONTRACT ACCEPTED. WELCOME TO THE TEAM.", "The blank field in your employee ID fills itself in. It is your real name."]
	},
	"atonement": {
		"title": "ENDING: ATONEMENT", "color": Color(1.0, 1.0, 1.0),
		"lines": ["You say it out loud. All of it. The leak. The 4,120 names. The lie.", "The static falls silent. The screen powers down on its own.", "The door opens. Outside, no one is waiting. For the first time in years, no one is following you."]
	},
}

# Intro text
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

# =============================================================================
# NODE REFERENCES
# =============================================================================
@onready var time_label: Label = $Terminal/HeaderBar/TimeLabel
@onready var status_label: Label = $Terminal/HeaderBar/StatusLabel
@onready var temp_bar: ProgressBar = $Terminal/HeaderBar/TempBar
@onready var log_text: RichTextLabel = $Terminal/LogPanel/LogText
@onready var log_panel: Panel = $Terminal/LogPanel
@onready var work_area: Control = $Terminal/WorkArea
@onready var log_button: Button = $Terminal/WorkArea/LogButton

@onready var clicker_v2: AudioStreamPlayer2D = $Clickerv2
@onready var clicker: AudioStreamPlayer2D = $Clicker
@onready var bg_rect: ColorRect = $Background
@onready var glitch_overlay: ColorRect = $ScreenGlitchOverlay
@onready var popup_container: Control = $PopupContainer
@onready var peripheral_container: Control = $PeripheralContainer
@onready var btn_auto: Button = $UpgradesBar/UpgradeAutoClicker
@onready var btn_multi: Button = $UpgradesBar/UpgradeMultiplier

var intro_layer: Control
var intro_label: RichTextLabel
var intro_scanlines: ColorRect
var cutscene_bg: ColorRect

# =============================================================================
# LIFECYCLE
# =============================================================================
func _ready() -> void:
	_base_position = position
	_load_audio()
	_fetch_player_location()

	log_button.pressed.connect(_on_log_button_pressed)
	btn_auto.pressed.connect(_on_buy_auto_pressed)
	btn_multi.pressed.connect(_on_buy_multi_pressed)

	typing_audio_player = AudioStreamPlayer.new()
	typing_audio_player.stream = type_sound
	add_child(typing_audio_player)

	# Pre-cache jumpscare audio player for frame-perfect playback & volume boost
	jumpscare_audio_player = AudioStreamPlayer.new()
	jumpscare_audio_player.stream = jumpscare_sound
	jumpscare_audio_player.volume_db = 15.0  # Adjust loudness here in decibels
	add_child(jumpscare_audio_player)

	btn_auto.disabled = true
	btn_multi.disabled = true
	temp_bar.max_value = max_heat
	temp_bar.value = 0

	_style_log_panel()
	_load_progress()

	_add_log_entry("[color=cyan]========================================[/color]")
	_add_log_entry("[color=cyan]   MAINFRAME KERNEL v4.02 // SECURE LOGIN   [/color]")
	_add_log_entry("[color=cyan]   REMOTE SESSION ACTIVE: [UNKNOWN_IP]     [/color]")
	_add_log_entry("[color=cyan]========================================[/color]\n")

	if Engine.has_meta(META_INTRO_SEEN):
		_start_shift()
	else:
		_setup_intro_ui()

	await get_tree().process_frame

	temp_bar.pivot_offset = temp_bar.size / 2.0
	log_button.pivot_offset = log_button.size / 2.0
	


func _load_audio() -> void:
	type_sound = _load_stream(TYPE_SOUND_PATH)
	jumpscare_sound = _load_stream(JUMPSCARE_AUDIO_PATH)
	for i in range(1, WHISPER_AUDIO_COUNT + 1):
		whisper_audio_streams.append(_load_stream(WHISPER_AUDIO_PATH % i))
	for path in CUTSCENE_VOICE_PATHS:
		cutscene_voice_over.append(_load_stream(path))


func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	push_warning("Missing audio file: %s" % path)
	return null


func _fetch_player_location() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		if response_code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json and json.has("country_name"):
				var city = json.get("city", "UNKNOWN CITY")
				var country = json.get("country_name", "UNKNOWN COUNTRY")
				player_location = "%s, %s" % [city.to_upper(), country.to_upper()]
		http.queue_free()
	)
	http.request("http://ipapi.co/json/")


func _style_log_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.03, 0.02, 0.98)
	style.border_color = Color(0.15, 0.6, 0.3, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(15)
	log_panel.add_theme_stylebox_override("panel", style)

	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 16)
	log_text.add_theme_color_override("default_color", Color(0.4, 1.0, 0.6))


func _input(event: InputEvent) -> void:
	if debug_keys and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_trigger_camera_feed_jump_scare()
			return
		if event.keycode == KEY_F2:
			_play_jumpscare()
			return

	match current_phase:
		ShiftPhase.INTRO:
			if not is_transitioning and _is_confirm_event(event):
				_handle_intro_confirm()
		ShiftPhase.GAMEOVER:
			if event is InputEventKey and event.pressed and event.keycode == KEY_R:
				get_tree().reload_current_scene()
		ShiftPhase.ENDING:
			if ending_shown and event is InputEventKey and event.pressed and event.keycode == KEY_R:
				get_tree().reload_current_scene()


func _is_confirm_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == KEY_SPACE
	return false


func _process(delta: float) -> void:
	match current_phase:
		ShiftPhase.INTRO:
			_process_intro(delta)
			return
		ShiftPhase.ENDING, ShiftPhase.GAMEOVER:
			return

	click_lock_timer = maxf(0.0, click_lock_timer - delta)

	_update_heat(delta)
	_update_pacing(delta)
	_update_hazards(delta)
	_update_story_events()

	if not _update_corruption(delta):
		return

	if auto_clicker_rate > 0.0 and active_errors < max_allowed_errors and not cutscene_active:
		_advance_time(auto_clicker_rate * delta)

# =============================================================================
# INTRO
# =============================================================================
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

	var center_container := CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_layer.add_child(center_container)

	var margin := MarginContainer.new()
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
	intro_label.text = text
	intro_label.visible_characters = 0
	intro_total_chars = intro_label.get_total_character_count()
	char_reveal_index = 0
	type_timer = 0.0
	is_typing = true

	if intro_step in TUTORIAL_STEPS:
		cutscene_bg.color = Color(0.04, 0.02, 0.02, 1)
	else:
		cutscene_bg.color = Color(0.015, 0.015, 0.02, 1)


func _finish_typing() -> void:
	is_typing = false
	intro_label.visible_characters = -1
	typing_audio_player.stop()


func _handle_intro_confirm() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_confirm_msec < INPUT_DEBOUNCE_MSEC:
		return
	_last_confirm_msec = now
	get_viewport().set_input_as_handled()

	if is_typing:
		_finish_typing()
	else:
		_advance_intro()


func _process_intro(delta: float) -> void:
	if is_instance_valid(intro_scanlines):
		intro_scanlines.color.a = 0.2 + randf_range(-0.06, 0.06)

	if not is_typing:
		return

	type_timer += delta
	var revealed := false
	while type_timer >= TYPE_INTERVAL and is_typing:
		type_timer -= TYPE_INTERVAL
		char_reveal_index += 1
		revealed = true
		if char_reveal_index >= intro_total_chars:
			_finish_typing()

	if revealed and is_typing:
		intro_label.visible_characters = char_reveal_index
		if type_sound and not typing_audio_player.playing:
			typing_audio_player.pitch_scale = randf_range(0.95, 1.05)
			typing_audio_player.play()


func _advance_intro() -> void:
	intro_step += 1
	if intro_step < intro_texts.size():
		_start_typewriter_text(intro_texts[intro_step])
		intro_layer.pivot_offset = intro_layer.size / 2.0
		var bump := create_tween()
		bump.tween_property(intro_layer, "scale", Vector2(1.015, 1.015), 0.03)
		bump.tween_property(intro_layer, "scale", Vector2.ONE, 0.03)
	else:
		_finish_intro()


func _finish_intro() -> void:
	is_transitioning = true

	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	flash.z_index = 101
	add_child(flash)

	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.8)
	flash_tween.parallel().tween_property(intro_layer, "modulate:a", 0.0, 1.0)
	await flash_tween.finished
	flash.queue_free()

	if is_instance_valid(intro_layer):
		intro_layer.queue_free()

	Engine.set_meta(META_INTRO_SEEN, true)
	_start_shift()


func _start_shift() -> void:
	current_phase = ShiftPhase.MORNING
	_add_log_entry("SYSTEM INITIALIZED. SHIFT STARTED AT 08:00 AM.")
	_update_ui()

# =============================================================================
# PER-FRAME SYSTEMS
# =============================================================================
func _update_heat(delta: float) -> void:
	if is_overheated:
		overheat_timer -= delta
		if overheat_timer <= 0.0:
			is_overheated = false
			log_button.modulate = Color.WHITE
			_add_log_entry("SYSTEM COOLED. RE-ENGAGING...")
	elif heat > 0.0:
		heat = maxf(0.0, heat - heat_decay_rate * delta)

	temp_bar.value = heat

	if heat >= HEAT_PULSE_THRESHOLD:
		var pulse_scale := 1.0 + sin(Time.get_ticks_msec() * 0.015) * 0.08
		temp_bar.scale = Vector2(pulse_scale, pulse_scale)
	else:
		temp_bar.scale = Vector2.ONE


func _update_hazards(delta: float) -> void:
	if cutscene_active or in_lull:
		return

	match current_phase:
		ShiftPhase.MIDDAY:
			_tick_error_spawner(delta, ERROR_INTERVAL_MIDDAY)
		ShiftPhase.OVERTIME:
			_tick_error_spawner(delta, ERROR_INTERVAL_FINAL if final_stretch else ERROR_INTERVAL_OVERTIME)

			if not peripheral_active:
				peripheral_spawn_timer += delta
				if peripheral_spawn_timer >= PERIPHERAL_INTERVAL:
					peripheral_spawn_timer = 0.0
					_spawn_peripheral_glitch()

			whisper_timer += delta
			if whisper_timer >= WHISPER_INTERVAL:
				whisper_timer = 0.0
				_trigger_whisper()

			infiltration_spawn_timer += delta
			if infiltration_spawn_timer >= INFILTRATION_INTERVAL:
				infiltration_spawn_timer = 0.0
				_spawn_infiltration_popup()


func _tick_error_spawner(delta: float, interval: float) -> void:
	error_spawn_timer += delta
	if error_spawn_timer >= interval:
		error_spawn_timer = 0.0
		if active_errors < MAX_ERRORS_ON_SCREEN:
			_spawn_error_window()


func _update_corruption(delta: float) -> bool:
	if active_errors >= max_allowed_errors:
		work_progress = maxf(0.0, work_progress - corruption_drain_rate * delta)
		total_seconds = START_TIME + work_progress
		_update_ui()

		if active_errors >= max_swarm_overflow:
			_trigger_game_over("FATAL: SCREEN OVERLOAD. TOO MANY ACTIVE ERRORS.")
			return false

		glitch_overlay.visible = true
		glitch_overlay.color = Color(1, 0, 0, 0.2 + sin(Time.get_ticks_msec() * 0.02) * 0.1)
		rotation = randf_range(-0.003, 0.003)
	else:
		rotation = 0.0
		if current_phase == ShiftPhase.OVERTIME:
			glitch_overlay.color = Color(1, 0, 0, 0.08)
	return true

# =============================================================================
# TIME / PROGRESS
# =============================================================================
func _advance_time(amount: float) -> void:
	if current_phase == ShiftPhase.ENDING or current_phase == ShiftPhase.GAMEOVER:
		return

	work_progress += amount
	total_seconds = START_TIME + work_progress

	if total_seconds >= END_TIME:
		total_seconds = END_TIME
		_trigger_ending()
		return

	_check_phase_transitions()
	_update_ui()
	_check_upgrade_availability()


func _check_phase_transitions() -> void:
	if current_phase == ShiftPhase.MORNING and total_seconds >= MIDDAY_TIME:
		_begin_midday_reckoning()
	elif current_phase == ShiftPhase.MIDDAY and total_seconds >= OVERTIME_TIME:
		_begin_overtime()


func _begin_midday_reckoning() -> void:
	current_phase = ShiftPhase.MIDDAY
	cutscene_active = true

	status_label.text = "STATUS: INTERCEPTED"
	status_label.add_theme_color_override("font_color", Color.RED)
	bg_rect.color = Color(0.0, 0.0, 0.0, 1)
	glitch_overlay.visible = true
	glitch_overlay.color = Color(1, 0, 0, 0.4)

	log_button.disabled = true
	log_button.modulate = Color(0.1, 0.1, 0.1)
	log_text.clear()

	await get_tree().create_timer(JUMPSCARE_DELAY).timeout
	if current_phase != ShiftPhase.MIDDAY:
		return
	await _play_jumpscare()
	if current_phase != ShiftPhase.MIDDAY:
		return

	_play_cutscene_voice()

	for line in reckoning_script:
		if current_phase != ShiftPhase.MIDDAY:
			return
		_add_log_entry(line["text"])
		await get_tree().create_timer(line["delay"]).timeout

	if current_phase != ShiftPhase.MIDDAY:
		return

	cutscene_active = false
	_reset_pacing()
	log_button.disabled = false
	log_button.modulate = Color.WHITE
	status_label.text = "STATUS: ANOMALOUS"
	bg_rect.color = Color("#14191c")
	glitch_overlay.color = Color(1, 0, 0, 0.08)
	_add_log_entry("\n[color=cyan]-- TERMINAL FORCED OPEN. CONTINUE YOUR WORK. --[/color]")


func _play_cutscene_voice() -> void:
	for idx in CUTSCENE_VOICE_PLAYLIST:
		if idx >= cutscene_voice_over.size():
			continue
		var player := _play_one_shot(cutscene_voice_over[idx])
		if player == null:
			continue
		await player.finished
		if current_phase != ShiftPhase.MIDDAY:
			return


func _get_jumpscare_texture() -> Texture2D:
	if jumpscare_texture:
		return jumpscare_texture
	if ResourceLoader.exists(JUMPSCARE_TEXTURE):
		return load(JUMPSCARE_TEXTURE) as Texture2D
	push_warning("Jumpscare sprite not found at '%s'. Assign it to 'Jumpscare Texture' in the Inspector." % JUMPSCARE_TEXTURE)
	return null


func _play_jumpscare() -> void:
	if not jumpscare_enabled:
		return

	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 400

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	layer.add_child(bg)

	var tex := _get_jumpscare_texture()
	if tex:
		var img := TextureRect.new()
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.add_child(img)
	else:
		bg.color = Color(0.6, 0.0, 0.0)

	add_child(layer)
	layer.pivot_offset = size / 2.0
	layer.scale = Vector2(1.3, 1.3)
	
	if jumpscare_audio_player:
		jumpscare_audio_player.play()

	var t := layer.create_tween()
	t.tween_property(layer, "scale", Vector2.ONE, 0.08)
	for i in 14:
		t.tween_property(layer, "position", Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0)), 0.04)
	t.tween_property(layer, "position", Vector2.ZERO, 0.04)
	t.tween_interval(JUMPSCARE_HOLD)
	t.tween_property(layer, "modulate:a", 0.0, 0.3)
	await t.finished

	if is_instance_valid(layer):
		layer.queue_free()


func _begin_overtime() -> void:
	current_phase = ShiftPhase.OVERTIME
	status_label.text = "STATUS: CRITICAL"
	status_label.add_theme_color_override("font_color", Color.RED)
	bg_rect.color = Color("#0d0507")
	glitch_overlay.visible = true
	glitch_overlay.color = Color(1, 0, 0, 0.08)
	log_button.text = "LOG FLESH"
	heat_per_click = OVERTIME_HEAT_PER_CLICK
	_reset_pacing()
	_add_log_entry("[color=red]-- FACILITY LOCKDOWN ACTIVE. ALL PERSONNEL REMAIN AT DESKS. --[/color]")

# =============================================================================
# CLICKING
# =============================================================================
func _on_log_button_pressed() -> void:
	_play_sfx(clicker_v2)

	if click_lock_timer > 0.0:
		return

	if current_phase in [ShiftPhase.INTRO, ShiftPhase.ENDING, ShiftPhase.GAMEOVER] or is_overheated:
		return

	if active_errors >= max_allowed_errors:
		_add_log_entry("[color=red]DATA CORRUPTION ACTIVE: CLOSE ERROR WINDOWS TO RESUME![/color]")
		_shake_log_button()
		return

	heat += heat_per_click
	if heat >= max_heat:
		heat = max_heat
		is_overheated = true
		overheat_timer = overheat_duration
		log_button.modulate = Color.RED
		_add_log_entry("[color=red]CRITICAL WARNING: CPU OVERHEAT! LOCKED OUT FOR %.1fs[/color]" % overheat_duration)
		return

	_squish_log_button()

	if current_phase == ShiftPhase.OVERTIME:
		_jolt_screen()

	if current_phase == ShiftPhase.OVERTIME or (current_phase == ShiftPhase.MIDDAY and randf() < 0.35):
		_flee_button()

	_advance_time(seconds_per_click)
	_log_click_message()


func _log_click_message() -> void:
	match current_phase:
		ShiftPhase.MORNING:
			_add_log_entry(_packet_message())
		ShiftPhase.MIDDAY:
			var eerie_msg: String = ["WHO IS AT THE DOOR?", "DO NOT LOOK AWAY.", "SIGNAL DECAY DETECTED."].pick_random()
			_add_log_entry(eerie_msg if randf() < 0.25 else _packet_message())
		ShiftPhase.OVERTIME:
			var nightmare_msg: String = ["IT IS INSIDE.", "HELP ME", "DONT PUNCH OUT", "STAY SEATED"].pick_random()
			_add_log_entry("[color=red]" + nightmare_msg + "[/color]")


func _packet_message() -> String:
	return "DATA_PACKET_0x%X COMMITTED." % randi_range(1000, 9999)


func _squish_log_button() -> void:
	if _click_tween:
		_click_tween.kill()
	_click_tween = create_tween()
	_click_tween.tween_property(log_button, "scale", Vector2(0.88, 0.88), 0.03)
	_click_tween.tween_property(log_button, "scale", Vector2(1.02, 1.02), 0.04)
	_click_tween.tween_property(log_button, "scale", Vector2.ONE, 0.03)


func _shake_log_button() -> void:
	if _shake_tween and _shake_tween.is_running():
		return
	var x := log_button.position.x
	_shake_tween = create_tween()
	_shake_tween.tween_property(log_button, "position:x", x + 8.0, 0.03)
	_shake_tween.tween_property(log_button, "position:x", x - 8.0, 0.03)
	_shake_tween.tween_property(log_button, "position:x", x, 0.03)


func _jolt_screen() -> void:
	if _jolt_tween:
		_jolt_tween.kill()
	var offset := Vector2(randf_range(-3, 3), randf_range(-3, 3))
	_jolt_tween = create_tween()
	_jolt_tween.tween_property(self, "position", _base_position + offset, 0.02)
	_jolt_tween.tween_property(self, "position", _base_position, 0.02)


func _center_button() -> void:
	var target := (work_area.size - log_button.size) / 2.0
	log_button.position = Vector2(maxf(0.0, target.x), maxf(0.0, target.y))


func _flee_button() -> void:
	var max_x := maxf(10.0, work_area.size.x - log_button.size.x - 10.0)
	var max_y := maxf(10.0, work_area.size.y - log_button.size.y - 10.0)
	var random_pos := Vector2(randf_range(10.0, max_x), randf_range(10.0, max_y))

	if _flee_tween:
		_flee_tween.kill()
	_flee_tween = create_tween()
	_flee_tween.tween_property(log_button, "position", random_pos, 0.08)

# =============================================================================
# UPGRADES
# =============================================================================
func _check_upgrade_availability() -> void:
	if btn_auto.disabled and auto_clicker_rate == 0.0 and work_progress >= auto_cost:
		btn_auto.disabled = false
	if btn_multi.disabled and seconds_per_click <= BASE_SECONDS_PER_CLICK and work_progress >= multi_cost:
		btn_multi.disabled = false


func _on_buy_auto_pressed() -> void:
	_play_sfx(clicker)
	if work_progress >= auto_cost:
		auto_clicker_rate += AUTO_RATE_BONUS
		_add_log_entry("UPGRADE PURCHASED: AutoScript.vbs installed.")
		btn_auto.disabled = true


func _on_buy_multi_pressed() -> void:
	_play_sfx(clicker)
	if work_progress >= multi_cost:
		seconds_per_click += MULTI_CLICK_BONUS
		_add_log_entry("UPGRADE PURCHASED: Overclock CPU executed.")
		btn_multi.disabled = true

# =============================================================================
# HAZARDS
# =============================================================================
func _spawn_error_window() -> void:
	active_errors += 1

	var err_popup := Button.new()
	err_popup.text = "FATAL ERROR: Close [%d]" % active_errors
	err_popup.custom_minimum_size = Vector2(200, 50)
	err_popup.pivot_offset = err_popup.custom_minimum_size / 2.0
	err_popup.position = Vector2(
		randf_range(20.0, maxf(30.0, size.x - 230.0)),
		randf_range(40.0, maxf(50.0, size.y - 70.0))
	)

	if active_errors >= max_allowed_errors:
		err_popup.modulate = Color(1, 0.3, 0.3)

	err_popup.scale = Vector2(0.1, 0.1)
	err_popup.create_tween().tween_property(err_popup, "scale", Vector2.ONE, 0.1)

	err_popup.pressed.connect(func():
		active_errors = maxi(0, active_errors - 1)
		var close_tween := err_popup.create_tween()
		close_tween.tween_property(err_popup, "scale", Vector2.ZERO, 0.06)
		close_tween.tween_callback(err_popup.queue_free)
	, CONNECT_ONE_SHOT)

	popup_container.add_child(err_popup)


func _spawn_peripheral_glitch() -> void:
	peripheral_active = true

	var anomaly := Button.new()
	anomaly.text = " [!] PURGE "
	anomaly.custom_minimum_size = Vector2(120, 50)
	anomaly.modulate = Color(1, 0.2, 0.2)

	var spawn_x := randf_range(20.0, 50.0) if randf() < 0.5 else randf_range(size.x - 160.0, size.x - 130.0)
	var spawn_y := randf_range(80.0, maxf(90.0, size.y - 120.0))
	anomaly.position = Vector2(spawn_x, spawn_y)
	peripheral_container.add_child(anomaly)

	var pulse := anomaly.create_tween().set_loops(4)
	pulse.tween_property(anomaly, "modulate:a", 0.3, 0.2)
	pulse.tween_property(anomaly, "modulate:a", 1.0, 0.2)

	anomaly.pressed.connect(func():
		peripheral_active = false
		heat = maxf(0.0, heat - PURGE_HEAT_RELIEF)
		_advance_time(PURGE_TIME_REWARD)
		_add_log_entry("[color=cyan]ANOMALOUS ENTITY PURGED. HEAT REDUCED.[/color]")
		anomaly.queue_free()
	, CONNECT_ONE_SHOT)

	await get_tree().create_timer(PERIPHERAL_LIFETIME).timeout

	if is_instance_valid(anomaly) and not anomaly.is_queued_for_deletion():
		peripheral_active = false
		anomaly.queue_free()
		_add_heat(PURGE_MISSED_HEAT)
		_add_log_entry("[color=red]WARNING: PERIPHERAL ANOMALY UNRESOLVED. SYSTEM STRESS SPIKED![/color]")


func _trigger_whisper() -> void:
	if whispers.is_empty() or current_phase == ShiftPhase.GAMEOVER or current_phase == ShiftPhase.ENDING:
		return
	var idx := randi_range(0, whispers.size() - 1)
	_add_log_entry("[color=purple]> " + whispers[idx] + "[/color]")

	if idx < whisper_audio_streams.size():
		_play_one_shot(whisper_audio_streams[idx])


func _spawn_infiltration_popup() -> void:
	var prompt_data: Dictionary = infiltration_prompts.pick_random()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 130)
	panel.position = Vector2(
		randf_range(30.0, maxf(40.0, size.x - 310.0)),
		randf_range(60.0, maxf(70.0, size.y - 190.0))
	)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "⚠️ " + prompt_data["title"]
	title_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = prompt_data["text"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	if prompt_data.get("forced", false):
		_build_forced_popup(panel, desc_lbl, hbox)
	else:
		_build_choice_popup(panel, prompt_data, hbox)

	popup_container.add_child(panel)


func _build_forced_popup(panel: PanelContainer, desc_lbl: Label, hbox: HBoxContainer) -> void:
	desc_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

	var force_btn := _make_button("OK", Vector2(160, 45), Color(1, 0.2, 0.2))
	hbox.add_child(force_btn)

	force_btn.pressed.connect(func():
		if not panel.is_queued_for_deletion():
			panel.queue_free()
			_trigger_camera_feed_jump_scare()
	)

	for remaining in range(int(FORCED_POPUP_TIMEOUT), 0, -1):
		if not is_instance_valid(panel) or panel.is_queued_for_deletion():
			return
		desc_lbl.text = "BYPASSING USER PERMISSION... CAMERA ACCESS FORCED IN %d" % remaining
		await get_tree().create_timer(1.0).timeout

	if is_instance_valid(panel) and not panel.is_queued_for_deletion():
		panel.queue_free()
		_trigger_camera_feed_jump_scare()


func _build_choice_popup(panel: PanelContainer, prompt_data: Dictionary, hbox: HBoxContainer) -> void:
	var btn_yes := _make_button(prompt_data["btn1"], Vector2(100, 45))
	var btn_no := _make_button(prompt_data["btn2"], Vector2(100, 45))
	hbox.add_child(btn_yes)
	hbox.add_child(btn_no)

	btn_yes.pressed.connect(func():
		infiltrations_accepted += 1
		_add_heat(INFILTRATION_HEAT)
		_add_log_entry("[color=red]REMOTE INFILTRATION ACKNOWLEDGED. THERMAL SURGE.[/color]")
		panel.queue_free()
	)
	btn_no.pressed.connect(func():
		_add_log_entry("[color=green]INFILTRATION ATTEMPT REJECTED BY USER.[/color]")
		panel.queue_free()
	)


func _get_camera_texture() -> Texture2D:
	if camera_feed_texture:
		return camera_feed_texture
	if ResourceLoader.exists(CAMERA_FEED_TEXTURE):
		return load(CAMERA_FEED_TEXTURE) as Texture2D
	push_warning("Camera feed sprite not found at '%s'. Assign it to 'Camera Feed Texture' in the Inspector." % CAMERA_FEED_TEXTURE)
	return null


func _trigger_camera_feed_jump_scare() -> void:
	camera_scares += 1
	_add_log_entry("[color=red]WARNING: LOCAL CAMERA STREAM ACTIVATED BY REMOTE HOST.[/color]")

	var cam_layer := Control.new()
	cam_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_layer.z_index = 300

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.92)
	cam_layer.add_child(bg)

	var feed_texture := _get_camera_texture()
	if feed_texture:
		var texture_rect := TextureRect.new()
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture_rect.texture = feed_texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cam_layer.add_child(texture_rect)
	else:
		var no_signal := Label.new()
		no_signal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		no_signal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_signal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		no_signal.text = "[ NO SIGNAL ]"
		if OS.is_debug_build():
			no_signal.text += "\n(camera sprite not found - assign it in the Inspector)"
		no_signal.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		cam_layer.add_child(no_signal)

	var rec_label := Label.new()
	rec_label.text = "🔴 REC [LIVE STREAM] - TARGET SPOTTED"
	rec_label.position = Vector2(40, 30)
	rec_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	cam_layer.add_child(rec_label)

	add_child(cam_layer)

	var jump_audio: AudioStreamPlayer = null
	if CAMERA_FEED_AUDIO_INDEX < whisper_audio_streams.size():
		jump_audio = _play_one_shot(whisper_audio_streams[CAMERA_FEED_AUDIO_INDEX])

	await get_tree().create_timer(CAMERA_FEED_DURATION).timeout
	if not is_instance_valid(cam_layer):
		return

	var fade_tween := cam_layer.create_tween()
	fade_tween.tween_property(cam_layer, "modulate:a", 0.0, 0.5)
	await fade_tween.finished

	if is_instance_valid(jump_audio):
		jump_audio.queue_free()
	if is_instance_valid(cam_layer):
		cam_layer.queue_free()
	_add_log_entry("[color=yellow]CAMERA FEED MINIMIZED TO BACKGROUND PROCESS.[/color]")

# =============================================================================
# END STATES
# =============================================================================
func _trigger_game_over(reason: String) -> void:
	current_phase = ShiftPhase.GAMEOVER
	time_label.text = "00:00:00 -- [CRASHED]"
	status_label.text = "STATUS: KERNEL PANIC"
	status_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	bg_rect.color = Color.BLACK
	glitch_overlay.visible = true
	glitch_overlay.color = Color(1, 0, 0, 0.45)
	rotation = 0.0

	_clear_overlays()

	log_button.disabled = true
	log_button.text = "SYSTEM HALTED"

	_add_log_entry("[color=red]" + reason + "[/color]")
	_add_log_entry("[color=red]THE SCREEN IS ENVELOPED IN STATIC. TAP RESTART BELOW.[/color]")

	var restart_btn := _make_button("RESTART SHIFT", Vector2(220, 60), Color(1, 0.2, 0.2))
	restart_btn.position = Vector2((size.x - 220.0) / 2.0, (size.y - 60.0) / 2.0 + 80.0)
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	popup_container.add_child(restart_btn)


func _trigger_ending() -> void:
	current_phase = ShiftPhase.ENDING
	time_label.text = _format_clock(END_TIME)
	status_label.text = "STATUS: SHIFT COMPLETE"
	bg_rect.color = Color.BLACK
	glitch_overlay.visible = false
	rotation = 0.0

	_clear_overlays()

	log_button.visible = false
	_add_log_entry("[color=green]SHIFT FINISHED. CHOOSE YOUR EXIT CONTRACT.[/color]")

	var choices: Array[Dictionary] = [
		{"text": "PUNCH OUT (EXIT)", "id": "punch_out", "color": Color(0.2, 1.0, 0.3)},
		{"text": "STAY SEATED", "id": "stay", "color": Color(1.0, 0.3, 0.3)},
		{"text": "LET ME IN", "id": "let_in", "color": Color(1.0, 0.2, 0.8)},
		{"text": "ACCEPT PERMANENT CONTRACT", "id": "contract", "color": Color(0.8, 0.8, 0.2)}
	]
	choices.shuffle()

	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_container.add_child(center_box)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(380, 260)
	vbox.add_theme_constant_override("separation", 12)
	center_box.add_child(vbox)

	for c in choices:
		var btn := _make_button(c["text"], Vector2(380, 50), c["color"])
		var choice_id: String = c["id"]
		btn.pressed.connect(func(): _show_ending(_resolve_ending(choice_id)))
		vbox.add_child(btn)

	if fragments_found.size() >= TRUE_ENDING_FRAGMENTS:
		var confess := _make_button("SAY IT OUT LOUD", Vector2(380, 50), Color.WHITE)
		confess.modulate.a = 0.0
		confess.disabled = true
		confess.pressed.connect(func(): _show_ending(_resolve_ending("confess")))
		vbox.add_child(confess)

		var reveal := confess.create_tween()
		reveal.tween_interval(1.5)
		reveal.tween_property(confess, "modulate:a", 1.0, 1.5)
		reveal.tween_callback(func(): confess.disabled = false)

# =============================================================================
# HELPERS
# =============================================================================
func _update_ui() -> void:
	var text := _format_clock(total_seconds)
	if active_errors >= max_allowed_errors:
		text += " [ERRORS: %d/%d]" % [active_errors, max_swarm_overflow]
	time_label.text = text


func _format_clock(seconds: float) -> String:
	var h24 := floori(seconds / 3600.0) % 24
	var mins := floori(fmod(seconds, 3600.0) / 60.0)
	var secs := int(seconds) % 60
	var h12 := h24 % 12
	if h12 == 0:
		h12 = 12
	return "%02d:%02d:%02d %s" % [h12, mins, secs, "AM" if h24 < 12 else "PM"]


func _add_log_entry(text: String) -> void:
	log_text.append_text(text + "\n")
	while log_text.get_paragraph_count() > MAX_LOG_PARAGRAPHS:
		log_text.remove_paragraph(0)


func _add_heat(amount: float) -> void:
	heat = minf(max_heat, heat + amount)


func _clear_overlays() -> void:
	for child in popup_container.get_children():
		child.queue_free()
	for child in peripheral_container.get_children():
		child.queue_free()


func _make_button(text: String, min_size: Vector2, tint: Color = Color.WHITE) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.modulate = tint
	return btn


func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player and player.stream:
		player.play()


func _play_one_shot(stream: AudioStream) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player

# =============================================================================
# PACING DIRECTOR
# =============================================================================
func _reset_pacing() -> void:
	in_lull = false
	pacing_timer = 0.0
	error_spawn_timer = 0.0


func _update_pacing(delta: float) -> void:
	if cutscene_active or final_stretch:
		return
	if current_phase != ShiftPhase.MIDDAY and current_phase != ShiftPhase.OVERTIME:
		return

	pacing_timer += delta
	var limit := LULL_DURATION if in_lull else BUILD_DURATION
	if pacing_timer < limit:
		return

	pacing_timer = 0.0
	if in_lull:
		_end_lull()
	else:
		_begin_lull()


func _begin_lull() -> void:
	in_lull = true
	heat = maxf(0.0, heat - LULL_HEAT_RELIEF)
	var msg: String = lull_messages.pick_random()
	_add_log_entry("[color=gray]" + msg + "[/color]")


func _end_lull() -> void:
	in_lull = false
	error_spawn_timer = 0.0
	peripheral_spawn_timer = 0.0
	whisper_timer = 0.0
	infiltration_spawn_timer = 0.0

	_add_log_entry("[color=red]SURGE DETECTED.[/color]")
	_jolt_screen()
	for i in SPIKE_ERRORS:
		if active_errors < max_swarm_overflow - 1:
			_spawn_error_window()
	if current_phase == ShiftPhase.OVERTIME:
		_trigger_whisper()

# =============================================================================
# TIMELINE & STORY
# =============================================================================
func _update_story_events() -> void:
	if cutscene_active:
		return

	if event_index < scripted_events.size():
		var next_event: Dictionary = scripted_events[event_index]
		if total_seconds >= float(next_event["time"]):
			event_index += 1
			_run_scripted_event(next_event["type"])

	if fragment_index < story_fragments.size() and not message_active:
		var next_fragment: Dictionary = story_fragments[fragment_index]
		if total_seconds >= float(next_fragment["time"]):
			fragment_index += 1
			_spawn_message_notification(next_fragment)


func _run_scripted_event(type: String) -> void:
	match type:
		"flicker":
			_event_flicker()
		"fake_update":
			_event_fake_update()
		"blackout":
			_event_blackout()
		"final_stretch":
			_event_final_stretch()


func _event_flicker() -> void:
	_add_log_entry("[color=gray]POWER FLUCTUATION DETECTED.[/color]")
	var t := create_tween()
	for i in 3:
		t.tween_property(self, "modulate", Color(0.2, 0.2, 0.2), 0.04)
		t.tween_property(self, "modulate", Color.WHITE, 0.06)
		t.tween_interval(randf_range(0.05, 0.2))


func _event_blackout() -> void:
	_add_log_entry("[color=gray]POWER LOSS. SWITCHING TO BACKUP...[/color]")
	var blackout := ColorRect.new()
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.color = Color.BLACK
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout.z_index = 250
	blackout.modulate.a = 0.0
	add_child(blackout)

	var t := blackout.create_tween()
	t.tween_property(blackout, "modulate:a", 1.0, 0.1)
	t.tween_interval(0.9)
	t.tween_property(blackout, "modulate:a", 0.0, 0.5)
	t.tween_callback(blackout.queue_free)

	if current_phase == ShiftPhase.OVERTIME:
		get_tree().create_timer(0.5).timeout.connect(_trigger_whisper)


func _event_fake_update() -> void:
	_add_log_entry("[color=gray]SYSTEM UPDATE INITIATED BY HOST.[/color]")

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 110)
	panel.position = Vector2((size.x - 320.0) / 2.0, (size.y - 110.0) / 2.0)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Installing update... DO NOT POWER OFF."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(280, 20)
	bar.max_value = 100.0
	bar.value = 0.0
	vbox.add_child(bar)

	popup_container.add_child(panel)
	click_lock_timer = FAKE_UPDATE_DURATION

	var t := panel.create_tween()
	t.tween_property(bar, "value", 99.0, FAKE_UPDATE_DURATION)
	t.tween_callback(func(): lbl.text = "UPDATE FAILED: nothing to install. It was already installed.")
	t.tween_interval(1.2)
	t.tween_callback(panel.queue_free)


func _event_final_stretch() -> void:
	final_stretch = true
	in_lull = false
	_add_log_entry("[color=red]SHIFT ENDS IN 30 MINUTES. THERE ARE NO MORE QUIET MOMENTS.[/color]")
	_jolt_screen()


func _spawn_message_notification(fragment: Dictionary) -> void:
	message_active = true
	_add_log_entry("[color=cyan]INCOMING TRANSMISSION DETECTED ON SCREEN.[/color]")

	# Center container to place the prominent alert right on the main screen area
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.z_index = 200

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 140)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⚠️ INCOMING SYSTEM MESSAGE ⚠️"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	vbox.add_child(title)

	var info := Label.new()
	info.text = "From: %s\nSubject: %s\n\nAn unauthorized external message has arrived." % [fragment["from"], fragment["subject"]]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	var open_btn := _make_button("OPEN MESSAGE NOW", Vector2(200, 45), Color(0.2, 1.0, 0.8))
	open_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(open_btn)

	# Flashing pulse effect on the entire popup box to draw attention
	var pulse := panel.create_tween().set_loops()
	pulse.tween_property(panel, "modulate", Color(1, 0.6, 0.6), 0.3)
	pulse.tween_property(panel, "modulate", Color.WHITE, 0.3)

	open_btn.pressed.connect(func():
		center.queue_free()
		_open_message(fragment)
	, CONNECT_ONE_SHOT)

	popup_container.add_child(center)

	# Auto-expire if ignored for too long
	await get_tree().create_timer(MESSAGE_LIFETIME).timeout
	if is_instance_valid(center) and not center.is_queued_for_deletion():
		center.queue_free()
		message_active = false
		_add_log_entry("[color=gray]INCOMING MESSAGE DISMISSED / EXPIRED.[/color]")


func _open_message(fragment: Dictionary) -> void:
	var frag_id: String = fragment["id"]
	if not fragments_found.has(frag_id):
		fragments_found.append(frag_id)
	_add_log_entry("[color=cyan]ARCHIVE UPDATED: %d/%d MESSAGES RECOVERED.[/color]" % [fragments_found.size(), story_fragments.size()])

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.position = Vector2(maxf(10.0, (size.x - 420.0) / 2.0), maxf(60.0, size.y * 0.15))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "FROM: %s\nSUBJECT: %s" % [fragment["from"], fragment["subject"]]
	header.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	vbox.add_child(header)

	# Dynamically inject the player's live geolocation for the packet message
	var body_text: String = fragment["body"]
	if frag_id == "packet":
		body_text = "SUBJECT: [REDACTED]\nLAST KNOWN ADDRESS: %s\nSTATUS: RESOLVED\n\nEvery packet you commit marks one more entry as resolved. The list is almost finished.\n\nYour name is on it." % player_location

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(body)

	var close_btn := _make_button("CLOSE", Vector2(120, 40))
	vbox.add_child(close_btn)
	close_btn.pressed.connect(func():
		message_active = false
		panel.queue_free()
	, CONNECT_ONE_SHOT)

	popup_container.add_child(panel)

# =============================================================================
# ENDINGS
# =============================================================================
func _resolve_ending(choice: String) -> String:
	match choice:
		"punch_out":
			return "escaped" if infiltrations_accepted <= PUNCH_OUT_MAX_ACCEPTED else "compliant"
		"let_in":
			return "possessed"
		"contract":
			return "employee"
		"confess":
			return "atonement"
	return "loop"


func _show_ending(ending_id: String) -> void:
	if ending_shown:
		return
	ending_shown = true

	var data: Dictionary = endings[ending_id]
	var color: Color = data["color"]

	var lines: Array[String] = []
	for l in data["lines"]:
		lines.append(l)

	match ending_id:
		"escaped":
			if fragments_found.size() >= TRUE_ENDING_FRAGMENTS:
				lines.append("You knew everything. You left anyway. The voicemail still plays every night.")
			else:
				lines.append("You never find out what the numbers were.")
		"possessed":
			if camera_scares > 0:
				lines.append("It already knew your face. The camera was only ever a formality.")

	_record_ending(ending_id)
	_clear_overlays()
	_add_log_entry("[color=#%s]%s[/color]" % [color.to_html(false), lines[0]])

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.88)
	popup_container.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_container.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(520, 0)
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = data["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", color)
	vbox.add_child(title)

	var story := Label.new()
	story.text = "\n\n".join(PackedStringArray(lines))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(story)

	var stats := Label.new()
	stats.text = "MESSAGES RECOVERED: %d/%d   |   ENDINGS FOUND: %d/%d" % [
		fragments_found.size(), story_fragments.size(), endings_found.size(), endings.size()
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(stats)

	var restart_btn := _make_button("RESTART SHIFT", Vector2(220, 60), color)
	restart_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(restart_btn)


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for e in cfg.get_value("progress", "endings", []):
		endings_found.append(str(e))


func _record_ending(ending_id: String) -> void:
	if endings_found.has(ending_id):
		return
	endings_found.append(ending_id)
	var plain: Array = []
	plain.append_array(endings_found)
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "endings", plain)
	cfg.save(SAVE_PATH)

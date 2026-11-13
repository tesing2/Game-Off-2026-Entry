extends Control

var Goal: int = 0
var BinGuess: int = 0
var rng: Array = [1, 2, 4, 8, 16, 32, 64]
var rlevel: int = 4

signal puzzle_solved

# Store button references in an array for easy iteration
@onready var bin_buttons: Array = [
	$HBoxContainer/Bin1,
	$HBoxContainer/Bin2,
	$HBoxContainer/Bin3,
	$HBoxContainer/Bin4,
	$HBoxContainer/Bin5,
	$HBoxContainer/Bin6,
	$HBoxContainer/Bin7
]

var bin_values: Array = [0, 0, 0, 0, 0, 0, 0]

func _ready() -> void:
	rlevel = 4 # Set 7 for maximum (all 7 buttons)
	
	# Shuffle the master pool
	rng.shuffle()
	
	# Assign values and hide unused buttons cleanly
	for i in range(bin_buttons.size()):
		if i < rlevel:
			bin_buttons[i].show()
			bin_values[i] = rng[i]
		else:
			bin_buttons[i].hide()
			bin_values[i] = 0

	# HARDER: Generate a Goal that *must* combine at least 2 active buttons
	# to avoid overly trivial 1-button solutions.
	while Goal == 0:
		Goal = 0
		var active_count = 0
		for i in range(rlevel):
			if randf() > 0.4: # Slightly lower chance to force more active toggles
				Goal += bin_values[i]
				active_count += 1
		
		# If it only picked 1 button, re-roll to keep the puzzle challenging
		if active_count < 2:
			Goal = 0
		
	$Goal.text = str(Goal)
	
func _ChangeBin() -> void:
	if BinGuess == Goal:
		$Indicator.text = "Your Answer is Correct!"
		puzzle_solved.emit()
		
		await get_tree().create_timer(0.6).timeout
		queue_free()
	elif BinGuess < Goal:
		$Indicator.text = "Your Guess is < " + str(Goal)
	else:
		$Indicator.text = "Your Guess is > " + str(Goal)
		
# Generic toggle handler to clean up individual button functions
func _update_guess(button_index: int) -> void:
	var val = bin_values[button_index]
	if bin_buttons[button_index].button_pressed:
		BinGuess += val
	else:
		BinGuess -= val
	_ChangeBin()

func _on_bin_1_pressed() -> void: _update_guess(0)
func _on_bin_2_pressed() -> void: _update_guess(1)
func _on_bin_3_pressed() -> void: _update_guess(2)
func _on_bin_4_pressed() -> void: _update_guess(3)
func _on_bin_5_pressed() -> void: _update_guess(4)
func _on_bin_6_pressed() -> void: _update_guess(5)
func _on_bin_7_pressed() -> void: _update_guess(6)

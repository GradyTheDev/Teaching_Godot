class_name RhythmGame
extends Control

# CC0 1.0
# Author: GradyTheDev

## (Simple) Rhythm Game Script
##
## Usage [br]
## 1. Put this script in a node [br]
## 2. assign the exported node's  [br]
## 3. Option A: put [member SONG_EXAMPLE] into [method load_song] [br]
## 4. Option B: [method load_script_from_file] then put that into [method load_song] [br]
##
## Example Song file (Remove the [ br]) [br]
## 2 first [br]
## 3 second. [br]
## 4.3 last [br]

signal health_changed(old, new)

## true if user's health hit 0
signal song_ended(failed: bool) 

signal progress_changed(old, new)

## example song format [br]
## dot means clear text on next line [br]
const SONG_EXAMPLE = [
	[1, "First"],
	[4, "line"],
	[8, "of."], # the decimal here, clears the text, when the next line is written
	[12, "music"],
	#[show at time, caption text] key to hit is the first letter in the text
	# add a decimal '.' to a line, and that will clear the text on the screen
]

@export_node_path("ProgressBar") var nodepath_health_bar
@export_node_path("RichTextLabel") var nodepath_text
@export_node_path("ProgressBar") var nodepath_song_progress

@onready var ui_text: RichTextLabel = null # don't set these manually, use the ^ above node_xyz export
@onready var ui_health: ProgressBar =  null # don't set these manually, use the ^ above node_xyz export
@onready var ui_song_progress: ProgressBar = null # don't set these manually, use the ^ above node_xyz export

@export var HEALTH_COLOR_DEFAULT: Color = Color.GREEN
@export var HEALTH_COLOR_HURT: Color = Color.RED

## how long you are given to hit the correct key
## in seconds
@export var hitkey_timer_limit: float = 2

## music, caption display, and key prompt timer
var timer: float

var caption_index: int = 0
var captions: Array = []

## total text to be displayed
var total_text: String

## how much time has passed that you have not hit a key
## in seconds
## starts at the limit, then counts down, ends at a negitive
var hitkey_timer: float = 0

## actually just a single character
## set to '' (empty), this indicates that the player should NOT hit a character
var hitkey_key: String = ''

## 0 between captions
## 1 asking for key input
var phase: int = 0

var player_hit_key: bool = false

@export var health: int = 100:  set = _set_health, get = _get_health
@export var max_health: int = 100

func _ready():
	assert(nodepath_health_bar != null, "nodepath_health_bar HAS to be assigned in the editor!")
	assert(nodepath_song_progress != null, "nodepath_song_progress HAS to be assigned in the editor!")
	assert(nodepath_text != null, "nodepath_text HAS to be assigned in the editor!")

	ui_song_progress = get_node(nodepath_song_progress)
	ui_text = get_node(nodepath_text)
	ui_health = get_node(nodepath_health_bar)

	_set_health(health)

	if captions.size() == 0:
		load_song(SONG_EXAMPLE)
	
	# load_song(load_script_from_file('rhythm_game/song.txt'))


func _process(delta):
	if caption_index >= captions.size(): 
		return # song over, return
	
	timer += delta

	if phase == 0: # between captions
		if timer >= captions[caption_index][0]:
			# caption reached

			# reset hitkey timer
			hitkey_timer = hitkey_timer_limit
			
			# add caption text to total text

			var arr = []

			for c in captions[caption_index][1]:
				arr.append(c)
			
			var start_char = arr.slice(0, 1)[0]
			var rest = ''.join(arr.slice(1))
			
			print(start_char)
			print(rest)
			total_text += ' [b]{0}[/b]{1}'.format([start_char, rest])
			ui_text.text = total_text

			# clear text at end of line
			if rest.contains('.'):
				total_text = ''
			
			# get required key
			hitkey_key = captions[caption_index][1][0].to_upper() ## to_upper required when comparing with KEY_XYZ

			# set phase
			phase = 1

			player_hit_key = false
			
			# debug
			print('Asking for key: ', hitkey_key)
			
	elif phase == 1: # asking for key input
		if hitkey_timer > 0:
			# asking player to hit a key
			hitkey_timer -= delta
			if hitkey_timer <= 0:
				print('hitkey timeout')
				hitkey_key = ''
				caption_index += 1
				
				var old = ui_song_progress.value
				ui_song_progress.value = clamp(float(caption_index) / captions.size(), 0, 1) * 100
				progress_changed.emit(old, ui_song_progress.value)
				
				phase = 0
				if caption_index >= captions.size():
					song_over()
					return # song over, return
				if not player_hit_key:
					player_didnt_hit_key_in_time()


func _input(event: InputEvent):
	# todo: handle opening the pause menu.
	# if you open pause menu, return before the below code is executed

	if event is InputEventKey and not event.is_pressed():
		event = event as InputEventKey # not nessary, just to help the editor's code completion feature work
				
		if hitkey_key.is_empty() or phase == 0:
			# not asking for a key, but player hit a key anyway
			hitkey_key = ''
			player_hit_key = true
			player_hit_incorrect_key()
			return
		else:
			var got_key = event.as_text_keycode()

			if hitkey_key == got_key:
				hitkey_key = ''
				player_hit_key = true
				player_hit_correct_key()
			else:
				hitkey_key = ''
				player_hit_key = true
				player_hit_incorrect_key()

func hurt_player():
	health -= 10

	var tween = ui_health.create_tween()
	tween.tween_property(ui_health, 'modulate', HEALTH_COLOR_HURT, 0.5) # go red
	tween.tween_property(ui_health, 'modulate', HEALTH_COLOR_DEFAULT, 0.5) # reset color
	tween.play()


func player_hit_correct_key():
	print("RIGHT KEY")


func player_hit_incorrect_key():
	print("WRONG KEY")
	hurt_player()


func player_didnt_hit_key_in_time():
	print("Didn't hit key in time")
	hurt_player()


func song_over():
	print("Song Over")
	song_ended.emit(health <= 0)
	ui_text.text += ' - Song Over'


## see [member SONG_EXAMPLE]
func load_song(new_captions: Array):
	phase = 0
	hitkey_key = ''
	hitkey_timer = 0
	player_hit_key = false
	caption_index = 0
	captions = new_captions
	health = max_health
	timer = 0
	ui_song_progress.value = 0


func stop_song():
	captions = []
	caption_index = 0
	print("Song Stopped")
	song_over()


func _set_health(new_health: int):
	var old_health = health
	health = new_health
	ui_health.value = health
	health_changed.emit(old_health, health)

	if old_health > 0 and new_health <= 0:
		stop_song()


func _get_health() -> int:
	return health


## Returns the script from the file
## format [br]
## float space text (newline \n) [br]
## leave a dot "." to indicate the end of a sentace, to clear the text [br]
## example [br]
## 10 first
## 12.2 second
## 16.6 third.
## 18.4 next
func load_script_from_file(path: String) -> Array:
	assert(FileAccess.file_exists(path), "FILE DOESNT EXIST: " + path)

	var song = []

	var text = FileAccess.get_file_as_string(path)
	var lines = text.split('\n')
	print(lines)

	var line_index = 0
	for line in lines:
		if line.is_empty(): 
			continue
		var arr = line.split(' ', true, 1)
		assert(arr.size() == 2, 'Song File is formatted wrong, on line ' + str(line_index) + ' ! : ' + line)
		assert(arr[0].is_valid_float(), 'Error left side is not a float, on line ' + str(line_index) + '! : ' + line)
		
		song.append( [ float(arr[0]), arr[1] ] )
	
	return song

	

extends Node
## GameState — global save/load and story flags.
##
## Autoloaded as `GameState`. Holds the narrative flags set by dialogue
## choices, puzzle state, the journal and the player's place in any open
## conversation, and persists them to user://save.json so "Continue" works.
##
## Save format (SAVE_VERSION 2):
##   version   int         SAVE_VERSION at time of writing
##   scene     String      scene path to resume into
##   flags     Dictionary  story flags, e.g. {"trusted_edith": true}
##   puzzle    Dictionary  puzzle state, e.g. {"lens_aligned": true}
##   journal   Array       discovered journal entry ids, in discovery order
##   dialogue  Dictionary  {"path": graph file, "node": node id} or {} if none
## Version 1 saves (flags + scene only) still load; the missing keys default.

signal state_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

## Story flags set during play, e.g. {"trusted_edith": true}.
var flags: Dictionary = {}
## Puzzle state kept apart from story flags, e.g. {"lens_aligned": true}.
var puzzle: Dictionary = {}
## Path of the scene the player should resume into.
var current_scene: String = "res://scenes/game.tscn"
## Conversation to re-enter once the scene is ready (see take_pending_dialogue()).
var _pending_dialogue: Dictionary = {}


func set_flag(name: String, value: Variant) -> void:
	flags[name] = value
	state_changed.emit()


func get_flag(name: String, default: Variant = false) -> Variant:
	return flags.get(name, default)


func set_puzzle_state(name: String, value: Variant) -> void:
	puzzle[name] = value
	state_changed.emit()


func get_puzzle_state(name: String, default: Variant = false) -> Variant:
	return puzzle.get(name, default)


## Hand over a conversation restored by load_game(), exactly once. The gameplay
## scene calls this from _ready() and passes the result to DialogueManager.resume().
func take_pending_dialogue() -> Dictionary:
	var pending := _pending_dialogue
	_pending_dialogue = {}
	return pending


func new_game() -> void:
	flags.clear()
	puzzle.clear()
	_pending_dialogue = {}
	var journal: Variant = _journal()
	if journal != null:
		journal.clear()
	current_scene = "res://scenes/game.tscn"
	state_changed.emit()


## The Journal autoload, or null if it is not registered. Typed loosely so this
## file does not hard-depend on the Journal script being present.
func _journal() -> Variant:
	return get_node_or_null("/root/Journal")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var journal: Variant = _journal()
	var payload := {
		"version": SAVE_VERSION,
		"scene": current_scene,
		"flags": flags,
		"puzzle": puzzle,
		"journal": journal.entries() if journal != null else [],
		"dialogue": DialogueManager.get_position(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: could not open save file for reading.")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: save file is corrupt.")
		return false

	var data: Dictionary = parsed
	var version := int(data.get("version", 1))
	if version > SAVE_VERSION:
		push_error("GameState: save version %d is newer than this build (%d)." % [version, SAVE_VERSION])
		return false
	# Version 1 saves carry only scene + flags; every key below defaults when
	# missing, so no explicit migration step is needed yet.

	current_scene = str(data.get("scene", "res://scenes/game.tscn"))
	flags = _dict_or_empty(data.get("flags", {}))
	puzzle = _dict_or_empty(data.get("puzzle", {}))

	var saved_journal: Variant = data.get("journal", [])
	var journal: Variant = _journal()
	if journal != null:
		journal.restore(saved_journal if typeof(saved_journal) == TYPE_ARRAY else [])

	_pending_dialogue = _dict_or_empty(data.get("dialogue", {}))
	state_changed.emit()
	return true


func _dict_or_empty(value: Variant) -> Dictionary:
	return (value as Dictionary) if typeof(value) == TYPE_DICTIONARY else {}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

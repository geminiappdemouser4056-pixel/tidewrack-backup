extends Node
## DialogueManager — plays JSON-driven branching dialogue graphs.
##
## Autoloaded as `DialogueManager`. A graph is a dictionary of node id -> node.
## Each node:
##   { "speaker": String, "text": String,
##     "next": String|null,                     # linear node; null ends the graph
##     "choices": [ {"text": String, "next": String, "set_flag": {..}} ],
##     "set_flag": { "flag_name": value } }      # applied when the node is entered
##
## UI (dialogue_box.gd) listens to these signals; it does not read the graph.

signal dialogue_started
signal line_shown(speaker: String, text: String, choices: Array)
signal dialogue_finished

var _graph: Dictionary = {}
var _graph_path: String = ""
var _current_id: String = ""
var is_active: bool = false


func start(path: String, start_id: String = "start") -> bool:
	var graph := _load_graph(path)
	if graph.is_empty():
		return false
	_graph = graph
	_graph_path = path
	is_active = true
	dialogue_started.emit()
	_goto(start_id)
	return true


## Where the player is in a conversation, for GameState.save_game().
## Returns {} when no dialogue is active.
func get_position() -> Dictionary:
	if not is_active or _graph_path == "":
		return {}
	return {"path": _graph_path, "node": _current_id}


## Re-enter a conversation at a saved node (see get_position()). Returns false
## and leaves no dialogue active if the file or node no longer exists.
func resume(position: Dictionary) -> bool:
	var path := str(position.get("path", ""))
	var node := str(position.get("node", ""))
	if path == "" or node == "":
		return false
	var graph := _load_graph(path)
	if graph.is_empty() or not graph.has(node):
		push_warning("DialogueManager: cannot resume '%s' at node '%s'." % [path, node])
		return false
	return start(path, node)


## Advance a linear node (no choices). Ignored while choices are pending.
func advance() -> void:
	if not is_active:
		return
	var node: Dictionary = _graph.get(_current_id, {})
	if node.has("choices") and not (node["choices"] as Array).is_empty():
		return  # waiting on choose()
	var next: Variant = node.get("next", null)
	if next == null:
		_finish()
	else:
		_goto(str(next))


## Pick choice `index` on a choice node.
func choose(index: int) -> void:
	if not is_active:
		return
	var node: Dictionary = _graph.get(_current_id, {})
	var choices: Array = node.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	_apply_flags(choice.get("set_flag", {}))
	var next: Variant = choice.get("next", null)
	if next == null:
		_finish()
	else:
		_goto(str(next))


func _goto(id: String) -> void:
	if not _graph.has(id):
		push_error("DialogueManager: missing node '%s'." % id)
		_finish()
		return
	_current_id = id
	var node: Dictionary = _graph[id]
	_apply_flags(node.get("set_flag", {}))
	line_shown.emit(
		str(node.get("speaker", "")),
		str(node.get("text", "")),
		node.get("choices", [])
	)


func _apply_flags(dict: Dictionary) -> void:
	for key in dict:
		GameState.set_flag(str(key), dict[key])


func _finish() -> void:
	is_active = false
	_graph = {}
	_graph_path = ""
	_current_id = ""
	dialogue_finished.emit()


func _load_graph(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueManager: dialogue file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueManager: dialogue file is not a JSON object: %s" % path)
		return {}
	return parsed

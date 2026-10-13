extends Node
## Journal — discovered-logs system (Public Demo scaffold).
##
## Meant to be autoloaded as `Journal`. As the player examines objects, the
## dialogue "set_flag" hooks will record discovered entries here; the journal
## screen renders them. Scaffold only: storage + a couple of helpers, no UI yet.

signal entry_added(id: String)

var _entries: Array[String] = []


func discover(id: String) -> void:
	if id in _entries:
		return
	_entries.append(id)
	entry_added.emit(id)


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	return id in _entries


## Forget everything (new game).
func clear() -> void:
	_entries.clear()


## Replace the discovered set from a saved list (see GameState.load_game()).
## Entries are re-announced so any reader UI can rebuild itself.
func restore(ids: Array) -> void:
	_entries.clear()
	for id in ids:
		var entry := str(id)
		if entry != "" and not (entry in _entries):
			_entries.append(entry)
			entry_added.emit(entry)
# TODO(demo): add the reader UI.

extends Node
# game_mode.gd — autoload "GameMode"
# Holds the run mode picked on the title screen. Survives scene changes.

enum Mode { SOLO, VERSUS }

var mode : Mode = Mode.SOLO

func set_mode(new_mode: int) -> void:
	mode = new_mode as Mode

func is_versus() -> bool:
	return mode == Mode.VERSUS

func is_solo() -> bool:
	return mode == Mode.SOLO

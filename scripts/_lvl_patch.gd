func _play_level_up_effect() -> void:
	var effect := Node2D.new()
	effect.set_script(load("res://scripts/level_up_effect.gd"))
	get_tree().current_scene.add_child(effect)
	effect.play(global_position)

extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/VBoxContainer/Resume.pressed.connect(_on_resume)
	$Panel/VBoxContainer/Quit.pressed.connect(_on_quit)

func _on_resume() -> void:
	GameManager.resume()

func _on_quit() -> void:
	get_tree().quit()

class_name Melee extends ItemDescriptor
@export var damage: float = 25.0
@export var swing_count: int = 2  # cuántas animaciones swing tiene
@export var range: float = 1.0
@export var hitbox_radius: float = 0.15
@export var fire_rate: float = 0.4
@export var viewmodel_model : PackedScene
@export var hit_start_pct: float = 0.3  # % de la animación donde arranca el hitbox
@export var hit_end_pct: float = 0.5    # % donde se apaga

func get_actions() -> Array[String]:
	var lines = super.get_actions()
	lines.append_array(["equipar"])
	return lines

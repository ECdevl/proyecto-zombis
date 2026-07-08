extends Resource
class_name PlayerNeeds

enum Needs {HEALTH,STAMINA,HUNGER,THIRST,SLEEP}

@export_category("Necessary")
@export var max_health : float = 100.0
@export var current_health : float = 100.0

@export var max_stamina : float = 100.0
@export var current_stamina : float = 100.0 : 
	set(new):
		current_stamina = new
		if current_stamina < 0:
			current_stamina = 0
			

@export_category("Survival")
@export var max_hunger : float = 100.0
@export var current_hunger : float = 100.0

@export var max_thirst : float = 100.0
@export var current_thirst : float = 100.0

@export var max_sleep : float = 100.0
@export var current_sleep : float = 100.0

func hurt(damage:float) -> void:
	current_health -= damage

func heal(what:Needs,amount:float) -> void:
	match what:
		Needs.HEALTH:
			current_health += amount
			if current_health > max_health:
				current_health = max_health
		Needs.STAMINA:
			current_stamina += amount
			if current_stamina > max_stamina:
				current_stamina = max_stamina
		Needs.HUNGER:
			current_hunger += amount
			if current_hunger > max_hunger:
				current_hunger = max_hunger
		Needs.THIRST:
			current_thirst += amount
			if current_thirst > max_thirst:
				current_thirst = max_thirst

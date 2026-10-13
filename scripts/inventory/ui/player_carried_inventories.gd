extends Node
class_name PlayerCarriedInventories
## Todo lo que el jugador carga: bolsillos + ropa puesta + mochilas anidadas.
## Única autoridad para "meter un objeto en cualquier lado" y saber qué contenedores hay.

## Cambió el conjunto de contenedores (te pusiste una mochila, la soltaste...).
signal models_changed

var pockets: InventoryModel
var equipment: EquipmentModel
var hands := HandsModel.new()
## Contenedores alcanzables ahora mismo (bolsillos primero).
var models: Array[InventoryModel] = []


func setup(pockets_model: InventoryModel, equipment_model: EquipmentModel) -> void:
	pockets = pockets_model
	equipment = equipment_model
	if pockets.title.is_empty():
		pockets.title = "Bolsillos"
	pockets.setup()
	equipment.changed.connect(_refresh)
	_refresh()


## Primero busca lugar en los contenedores; si no hay, intenta ponérselo.
func pick_up(item: ItemInstance) -> bool:
	return add_anywhere(item) or equipment.equip(item)


func add_anywhere(item: ItemInstance) -> bool:
	for model in models:
		if model.add(item):
			return true
	return false


## Saca el objeto de donde esté: contenedores, manos o ropa puesta.
func remove(item: ItemInstance) -> bool:
	for model in models:
		if model.remove(item):
			return true
	return hands.remove(item) or equipment.remove(item)


## Recalcula qué contenedores existen y (des)conecta sus avisos.
func _refresh() -> void:
	var found: Array[InventoryModel] = []
	_collect(pockets, found)
	for worn: ItemInstance in equipment.items():
		_collect(worn.container, found)

	var added := found.filter(func(m): return m not in models)
	var removed := models.filter(func(m): return m not in found)
	for model: InventoryModel in removed:
		model.changed.disconnect(_refresh)
	for model: InventoryModel in added:
		model.changed.connect(_refresh)

	models = found
	if not added.is_empty() or not removed.is_empty():
		models_changed.emit()


## Suma 'model' y todos los contenedores que lleva adentro (recursivo).
func _collect(model: InventoryModel, into: Array[InventoryModel]) -> void:
	if model == null or model in into:
		return
	into.append(model)
	for item: ItemInstance in model.items():
		_collect(item.container, into)

func _ready() -> void:
	add_to_group("ammo_source")
func debug_ammo() -> void:
	print("contenedores: ", models.size())
	for model in models:
		print(" modelo '", model.title, "' | objetos: ", model.items().size())
		for item: ItemInstance in model.items():
			var d = item.descriptor
			print("   ", d.item_name, " | script: ", d.get_script().resource_path if d.get_script() else "ninguno", " | es AmmoItemDescriptor: ", d is AmmoItemDescriptor)
func count_ammo(type: Weapon.AMMO_TYPE) -> int:
	var total := 0
	for model in models:
		for item in model.items():
			if item is ItemInstance:
				item = item.descriptor
			if item is AmmoItemDescriptor and item.ammo_type == type:
				total += item.rounds
	return total

## Saca hasta `amount` balas. Devuelve cuántas sacó de verdad.
func take_ammo(type: Weapon.AMMO_TYPE, amount: int) -> int:
	var taken := 0
	for model in models:
		for item in model.items():
			var item_instance = item
			if item is ItemInstance:
				item = item_instance.descriptor
			if taken >= amount:
				return taken
			var ammo := item as AmmoItemDescriptor
			if ammo and ammo.ammo_type == type:
				var grab := mini(ammo.rounds, amount - taken)
				ammo.rounds -= grab
				taken += grab
				if ammo.rounds <= 0:
					model.remove(item_instance)  # caja vacía desaparece
	return taken

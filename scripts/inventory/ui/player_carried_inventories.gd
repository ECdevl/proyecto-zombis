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

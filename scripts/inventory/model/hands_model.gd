class_name HandsModel extends Resource
## Qué sostiene el jugador en cada mano.
## Un arma de 2 manos ocupa AMBAS: la misma instancia queda guardada en las dos.
## Avisa con `changed`, y con `main_weapon_changed` cuando cambia el arma que se ve en pantalla.

signal main_weapon_changed(weapon: Weapon)  # null = sin arma

enum Hand { LEFT, RIGHT }

var _held: Dictionary[Hand, ItemInstance] = {}
var _main_weapon: Weapon


func get_held(hand: Hand) -> ItemInstance:
	return _held.get(hand)


## Objetos distintos que se sostienen (un arma de 2 manos cuenta una sola vez).
func items() -> Array:
	var result: Array = []
	for item in _held.values():
		if item not in result:
			result.append(item)
	return result


func can_equip(item: ItemInstance, hand: Hand) -> bool:
	match item.descriptor.get_hands_required():
		1:
			return not _held.has(hand)
		2:
			return _held.is_empty()
		_:
			return false


func equip(item: ItemInstance, hand: Hand) -> bool:
	if not can_equip(item, hand):
		return false
	if item.descriptor.get_hands_required() == 2:
		_held[Hand.LEFT] = item
		_held[Hand.RIGHT] = item
	else:
		_held[hand] = item
	_notify()
	return true


## Pasa un objeto de 1 mano a la otra mano (si está libre).
func move(item: ItemInstance, hand: Hand) -> bool:
	if item.descriptor.get_hands_required() != 1 or _held.has(hand):
		return false
	for old_hand in _held.keys():
		if _held[old_hand] == item:
			_held.erase(old_hand)
	_held[hand] = item
	_notify()
	return true


## Lo saca de la(s) mano(s) donde esté.
func remove(item: ItemInstance) -> bool:
	var removed := false
	for hand in _held.keys():
		if _held[hand] == item:
			_held.erase(hand)
			removed = true
	if removed:
		_notify()
	return removed


func _notify() -> void:
	emit_changed()
	var weapon := _find_main_weapon()
	if weapon != _main_weapon:
		_main_weapon = weapon
		main_weapon_changed.emit(weapon)


## El arma "principal" es la de la mano derecha; si no hay, la de la izquierda.
func _find_main_weapon() -> Weapon:
	for hand in [Hand.RIGHT, Hand.LEFT]:
		var item := get_held(hand)
		if item and item.descriptor is Weapon:
			return item.descriptor as Weapon
	return null

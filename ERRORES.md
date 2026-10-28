# ERRORES.md — Errores encontrados y su corrección

Registro de los problemas que aparecieron durante el desarrollo, con la causa
real y la corrección aplicada. Antes de tocar un tema ya tratado aquí,
consultar este archivo.

---

## E-001 — Una propiedad exportada de tipo `Node` queda en `null` si el `.tscn` no declara `node_paths`

**Síntoma:** `player.inventory` era `null` en runtime aunque estuviera asignado
en el inspector, y `ui.inventory_ui.carried` nunca recibía nada.

**Causa real:** al serializar una escena, Godot 4 guarda una referencia a un
nodo como `NodePath`. Esa ruta **solo se resuelve como nodo** si el bloque
`[node ...]` que la posee la lista en `node_paths=PackedStringArray(...)`.
Sin ese atributo, la propiedad se carga como una ruta sin resolver y queda en
`null`.

**Corrección:** declarar la propiedad en la cabecera del nodo:

```
[node name="player" type="CharacterBody3D" node_paths=PackedStringArray("inventory")]
...
inventory = NodePath("PlayerContainers")
```

Aplicado en `scenes/player.tscn` para `inventory` (nodo `player`) y `player`
(nodo `CanvasLayer/UI`).

---

## E-002 — `%NombreUnico` no cruza los límites de una escena

**Síntoma:** `%PlayerContainers` dejó de resolver al mover el nodo del
inventario de `ui.tscn` a `player.tscn`; además, `InventoryUIController`,
`HandSlotView` y `EquipSlotView` no tenían forma de alcanzar los modelos que
ahora viven en el `Player`.

**Causa real:** los *unique names* (`unique_name_in_owner = true`) tienen
ámbito de **una sola escena**: un nodo instanciado ve los nombres únicos de su
propia escena, no los de la escena que lo instancia.

**Corrección:** inyección explícita en vez de búsqueda por nombre.
`UI._ready()` → `inventory_ui.bind_inventory(player.inventory)`; el
controlador reparte a sus vistas con `bind_equipment()` / `bind_carried()`.

---

## E-003 — Orden de `_ready()`: los hijos se inicializan antes que el padre

**Síntoma:** las ranuras de ropa quedaban sin modelo de equipo; el modelo
llegaba `null`.

**Causa real:** Godot notifica `ready` **de abajo hacia arriba**: los hijos
antes que el padre. `UI._ready()` (hijo) se ejecuta antes que `Player._ready()`
(padre), así que cuando la UI se enlazaba, `inventory.setup(pockets, equipment)`
todavía no se había ejecutado.

**Corrección (independiente del orden):** los modelos son `@export` de
`PlayerCarriedInventories`, no parámetros de `setup()`. Las propiedades
exportadas se resuelven en la **instanciación**, no en `_ready()`, así que
existen siempre. `setup()` se llama desde el `_ready()` del propio nodo del
inventario, y la UI reacciona a `models_changed`.

Regla general: *no depender del orden entre hermanos ni entre padre e hijo*;
usar exports (instanciación) o señales, no `setup()` ordered por `_ready()`.

---

## E-004 — El modo `--script` de Godot da errores falsos de compilación

**Síntoma:** al correr sondas con `godot --headless --script`, aparecen:

- `Compile Error: Identifier not found: GameManager` (`scripts/zombie/zombie.gd:61`)
- `Failed to load script "res://scripts/weapons/projectile_resource.gd"`
- `Failed to instantiate an autoload ... res://scenes/ui/icon_creator.tscn`
  (inclinación cíclica de recursos)
- `Attempt to connect nonexistent signal 'pushed'`
- `Trying to assign value of type 'CharacterBody3D' to a variable of type 'zombie.gd'`

**Causa real:** en modo `--script`, Godot compila el script principal **antes**
de registrar los autoloads (`Main::start()`). Todo script de la cadena de
dependencias que se compile en ese momento no puede resolver identificadores de
autoload; y si `zombie.gd` no compila, sus señales (`pushed`) no existen.

**Corrección / mitigación:** antes de culpar a un cambio, reproducir el mismo
error en `main` con las **mismas referencias de clase** (con un `git worktree`).
Verificado: el conjunto de errores es idéntico en `main`; son artefactos del
modo `--script`, no del proyecto.

Consecuencia: `signal pushed` **sí existe** (`scripts/zombie/zombie.gd:25`); el
error en runtime es del entorno de prueba.

---

## E-005 — `has_method()` y `get_method_list()` no exponen los virtuales internos del motor

**Síntoma:** la sonda marcaba 91 conexiones "rotas" del tipo
`Control::_size_changed`, `Container::queue_sort`,
`Container::_child_minsize_changed`.

**Causa real:** esas conexiones las crea el propio motor con punteros a método
de C++ (`callable_mp`), no por nombre. No aparecen ni en `has_method()` ni en
`get_method_list()` ni en `ClassDB.class_has_method()`.

**Corrección:** filtrar por el tipo de `Callable`. Una conexión declarada en un
`.tscn` (o en GDScript) siempre guarda el **nombre** del método:

```gdscript
if not callable.is_standard():
    continue   # conexión interna del motor
```

Verificado empíricamente: `is_standard() == true` para las de proyecto,
`is_custom() == true` para las del motor.

---

## E-006 — Godot no avisa al conectar con un método inexistente

**Síntoma:** las conexiones rotas no se ven ni al importar ni al cargar la
escena. Solo fallan cuando la señal se emite.

**Causa real:** `Object::connect()` acepta un `Callable` con un método que no
existe; el error aparece al emitir.

**Corrección:** verificación estática previa con
`tools/check_tscn_connections.py` (recorre todos los `.tscn`, expande las
escenas instanciadas y comprueba método destino y señal origen) y
verificación en runtime con `tools/probe_inventario.gd`.

---

## E-007 — El importador reexporta `assets/models/zombies/zombie_rig.glb`

**Síntoma:** tras `godot --headless --import`, el `.glb` aparece modificado
(544432 → 608376 bytes) y sin motivo aparente.

**Causa real:** el archivo versionado tiene una animación `stun` **duplicada**
dentro de la biblioteca; al reimportar, Godot normaliza el archivo y la
elimina. El error `ERROR: Animation name "stun" already exists in library.`
aparece al importar la versión original.

**Corrección:** es un problema del asset, no del código. Dejar el `.glb`
versionado tal cual y **no incluirlo** en commits ajenos al asset
(`git checkout -- assets/models/zombies/zombie_rig.glb`).
Corregir la animación duplicada es trabajo aparte, sobre el `.glb` o sobre el
`.import`.

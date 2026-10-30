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

---

## E-008 — Al soltar un objeto desde la UI desaparecía en vez de caer al mundo

**Síntoma:** clic derecho sobre un item > "soltar": el item salía del
inventario y **no aparecía en el mundo físico**. Con la tecla G (arma
equipada) sí salía.

**Causa real (varias, encadenadas):**

1. `InventoryUIController.item_dropped` **se emitía pero nadie la escucha**:
   0 conexiones en código y en escenas. Lo mismo le pasaba a `item_used`
   (el menú "usar" también estaba muerto; solo andaba porque la sonda
   `tools/probe_inventario.gd` llama `player.use_item` a mano).
2. El único flujo que andaba (G) dependía de `Player.grabbed_objects_instances`,
   un `Array[PackedScene]` que se llenaba con `PackedScene.pack()` al recoger.
   Ese mecanismo:
   - solo existía para objetos **recogidos del mundo**; un item de un cofre o
     puesto a mano no tenía escena → `object` quedaba `null` → `add_child(null)`
     y el item se perdía;
   - nunca se vaciaba al soltar → **duplicación infinita** del mismo objeto;
   - usaba `object.get_child(0).apply_central_force(...)`, que con el modelo
     importado con `-rigid` apunta al `MeshInstance3D`, no a un cuerpo (error);
     además `apply_central_force` aplicado un solo frame es casi un no-op
     (es una fuerza **por frame de físico**);
   - no restauraba `object.item` → una mochila soltada perdía el contenido;
   - `pack()` solo serializa nodos cuyo `owner` es el nodo empaquetado; los
     hijos de un modelo importado tienen como `owner` la raíz de la escena que
     lo instancia, así que el duplicado podía quedar vacío.

**Corrección (ver `DECISIONES.md` D-006):** se elimina el empaquetado. La
plantilla del mundo es `item.descriptor.item_mesh`; `Player.drop_item()`
instancia esa escena, le pasa el `ItemInstance` antes de agregarla al árbol,
la posiciona frente a la cámara y le fija `linear_velocity`. La UI quedó
conectada al Player (`item_used → use_item`, `item_dropped → drop_item`).
Si la escena no es agarrable o no se puede soltar, el item **se devuelve al
inventario**: nunca se pierde.

**Verificación:** `tools/probe_soltar.gd` → *RESULTADO: TODO OK* (flujo UI,
flujo G y escena no agarrable); `tools/probe_inventario.gd` → *TODO OK*;
`tools/check_tscn_connections.py` → 0 conexiones rotas.

---

## E-009 — El analizador estático de GDScript rechaza `self is RigidBody3D` en un script que declara `extends Node3D`

**Síntoma:** `Parse Error: Expression is of type "PickableItem" so it can't be
of type "RigidBody3D"` (y `Invalid cast` para `as`) en `pickable_object.gd`.

**Causa real:** el analizador asume que una instancia del script tiene
exactamente el tipo nativo que declara (`Node3D`) y no contempla que el
script pueda estar colgado en runtime de un nodo `RigidBody3D` (el caso del
modelo importado con `-rigid`). Entre `PickableItem` y `RigidBody3D` no hay
relación de subtipo en la jerarquía que el analizador conoce, así que
rechaza tanto el test `is` como el cast `as`.

**Corrección:** pasar por una referencia tipada `Node` (un tipo común de la
jerarquía) y hacer el test/cast ahí:

```gdscript
var me: Node = self
if me is RigidBody3D:
    return me as RigidBody3D
```

`Node → RigidBody3D` sí es un downcast válido para el analizador.

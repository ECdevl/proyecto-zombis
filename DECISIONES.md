
## D-006 — Soltar objetos: la plantilla del mundo es `item_mesh`, no el empaquetado del nodo vivo (2026-10-29)

**Contexto:** el flujo de soltado se basaba en `Player.grabbed_objects_instances`
(`Array[PackedScene]`): al recoger un objeto del mundo se hacía
`PackedScene.pack(hit_object.duplicate())` y al soltar se instanciaba esa escena.
El mecanismo solo funcionaba para objetos previamente recogidos del mundo,
duplicaba el objeto infinitamente (la entrada nunca se borraba), asumía
`get_child(0)` como cuerpo físico (con los modelos importados con `-rigid` el
hijo 0 es el `MeshInstance3D`) y perdía el `ItemInstance` (una mochila soltada
se vaciaba). Además `InventoryUIController.item_dropped` e `item_used` no
tenían ningún oyente: "soltar" desde la UI hacía desaparecer el item
(ver `ERRORES.md` E-008).

**Decisión:**

1. **La plantilla de un objeto en el mundo es `item.descriptor.item_mesh`.**
   Cada escena apuntada debe tener en su raíz el script `PickableItem` (y ser
   un `RigidBody3D`, obtenido importando el modelo de Blender con el sufijo
   `-rigid`). `Player.drop_item()` la instancia, le asigna el `ItemInstance`
   **antes** de agregarla al árbol (así conserva contenido y estado) y le fija
   la velocidad de lanzamiento. Se elimina `grabbed_objects_instances` y el
   bloque de empaquetado de `_try_interact`.
2. **El lanzamiento se define por VELOCIDAD, no por fuerza**
   (`linear_velocity = forward * THROW_SPEED`). La velocidad de salida no
   depende de la masa: Δv = J/m, así que un empujón (impulso J) acelera mucho
   más un objeto liviano que uno pesado; fijar la velocidad directamente hace
   que una mochila y una lata salgan igual. Además `apply_central_force`
   aplicado un solo frame es despreciable: es una fuerza que actúa **cada**
   frame de físico.
3. **La UI avisa al Player (D-004):** `UI._ready()` conecta
   `inventory_ui.item_used → player.use_item` e
   `inventory_ui.item_dropped → player.drop_item`.
4. **Nunca se pierde el item:** si no se puede soltar (recargando, escena sin
   script agarrable), `drop_item()` lo devuelve al inventario con
   `add_anywhere()`.
5. **`PickableItem.get_rigid_body()`** busca el `RigidBody3D` (el propio nodo o
   el primer hijo que lo sea) en vez de asumir `get_child(0)`; el `Area3D` de
   interacción se cuelga del cuerpo físico.
6. **`ItemDescriptor.ensure_icon()` tiene guard de reentrada** (`_icon_requesting`):
   como `item_mesh` ahora puede ser la propia escena PickableItem, su `_ready`
   vuelve a llamar a `ensure_icon` y se entraría en recursión infinita.

**Consecuencia / pendiente de datos:** los descriptores deben apuntar con
`item_mesh` a una escena **heredada** del modelo importado (`New Inherited
Scene` sobre el `.glb`/`.fbx`, con el script en la raíz); mientras apunten al
modelo crudo sin script, `drop_item()` emite un warning y devuelve el item al
inventario (ver `TASKS.md` T-007).

Dos caveats del `-rigid` verificados en el código fuente del motor: el sufijo
**se ignora si el mesh es el nodo raíz** de la escena importada (en Blender el
objeto debe quedar bajo una Collection), y el nodo resultante queda en la
**capa de colisión 1** por defecto: hay que ponerle la capa 2 (por ejemplo en
las Advanced Import Settings) para que colisione con lo esperado; el rayo de
interacción del Player alcanza el objeto por el `Area3D` de la capa 2 que
crea `PickableItem._ready()`.

## D-007 — Rework de `PickableItem`: un nodo autocontenido para el modelo importado (2026-10-29)

**Contexto:** el script nació con el proyecto pensando en otra estructura (un
`RigidBody3D` de escena propia con colisión y malla armadas a mano). Con el
flujo nuevo —importar el modelo de Blender con `-rigid`, arrastrarlo a la
escena y pegarle el script— esa lógica quedó repartida entre la escena
`pickable_object.tscn` y un `_ready` que asumía `get_child(0)`.

**Decisión:** `scripts/components/pickable_object.gd` se reescribe desde cero
como nodo **autocontenido**, con la única responsabilidad de adaptar el modelo
importado al juego:

1. **Se cuela donde caiga:** el script declara `extends Node3D`, así que
   funciona pegado tanto a la raíz `-rigid` (que ES un `RigidBody3D`) como a
   un nodo envoltorio; `_find_rigid_body()` busca el cuerpo recursivamente y
   lo cachea (el workaround del analizador estático quedó confinado ahí,
   ver E-009).
2. **Crea lo que el modelo no trae:** el `Area3D` de interacción de la capa 2
   (lo que el rayo del Player mira). Si la escena **ya trae** un área en esa
   capa (ej. `pickup_area.tscn`), la reutiliza: nunca duplica.
3. **Aplica las capas del proyecto** al cuerpo (`body_layer = 2`,
   `body_mask = 7`), exportadas con `@export_flags_3d_physics` para poder
   ajustarlas por objeto desde el inspector. Así no hay que configurear capas
   en cada modelo importado.
4. **Expone una API mínima:** `get_rigid_body()` y `launch(velocidad)`.
   `Player.drop_item()` deja de meterse con el cuerpo: instancia
   `item_descriptor.item_mesh`, asigna el `ItemInstance` antes de agregarlo al
   árbol y llama a `launch()`.
5. **Avisa de todo:** sin `item_descriptor` y sin `item` se descarta con
   warning; sin `RigidBody3D` avisa (olvido del sufijo `-rigid`); `launch()`
   sin cuerpo avisa en vez de fallar en silencio.

**Consecuencia:** `pickable_object.tscn` queda como escena legado (el flujo
nuevo no la necesita, pero la sonda `probe_inventario.gd` la sigue usando sin
duplicar áreas). Verificado con `tools/probe_soltar.gd` → TODO OK
(21 verificaciones, incluida la reutilización del área y la capa del cuerpo).

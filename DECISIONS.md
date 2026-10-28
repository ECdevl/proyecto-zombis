# DECISIONS.md — Registro de decisiones de diseño

## D-001 — Reorganización de la estructura de archivos (2026-10-22)

**Contexto:** el proyecto mezclaba carpetas con nombres inconsistentes (`Assets` con mayúscula
junto a `resources`/`scenes`/`scripts` en minúscula), scripts mal ubicados (`scripts/misc/`,
`scripts/quick_slot.gd`, `scripts/state_machine/death.gd` que es un estado de zombi),
`scripts/zombie/SM/` en mayúsculas, y `Assets/` mezclaba modelos, texturas, sprites, animaciones
y duplicados exactos.

**Decisión:** se normaliza la raíz del proyecto a carpetas en `snake_case` en minúscula y se
adopta la siguiente convención:

| Carpeta | Contenido |
|---|---|
| `assets/` | Todo lo binario: `models/`, `textures/`, `sprites/`, `animations/` |
| `scenes/` | Escenas de Godot: `player/`, `zombies/`, `weapons/`, `ui/`, `components/`, `effects/`, `debug/` |
| `scripts/` | Todo GDScript |
| `resources/` | Recursos `.tres` de datos (descriptores, armas, ropa, consumibles) |
| `materials/`, `themes/` | Recursos de render y de UI |

Reglas aplicadas:

1. Todo `.gd` vive bajo `scripts/`. Cada subcarpeta tiene una responsabilidad única.
2. Los `class_name` no cambian: el `.uid` acompaña al script, así que las referencias
   `uid://` de escenas y autoloads siguen resolviendo sin tocar nada.
3. Los `.tres` de datos viven en `resources/`, nunca en `scenes/`.
4. Los archivos con espacios, mayúsculas o acentos en el nombre se renombran a `snake_case`.
5. Las parejas `.obj`/`.mtl` y `.gltf`/`.bin` se mueven juntas y se renombran juntas; se
   actualiza la referencia interna (`mtllib`, `uri`).
6. Todo archivo `.import` conserva su `uid`; se actualiza `source_file` y
   `save_to_file/fallback_path`.
7. Se borran: scripts vacíos (0 bytes), código muerto (sistema `Item`/`ItemCloth`/
   `ItemConsumable`/`ContainerResource` y el `MeleeHitbox` legacy), duplicados exactos
   (md5 idéntico) y archivos de respaldo (`*~`, `.blend1`).

**Consecuencia:** el `README.md` queda desactualizado respecto de las rutas nuevas; se
actualizará en una tarea aparte.

## D-002 — Cómo se aplicaron los movimientos (2026-10-22)

**Decisión:** los archivos versionados se mueven con `git mv` (el cambio queda en el índice y
es reversible con `git reset`); los no versionados, con `mv`. No se crea ningún commit: la
reorganización queda *staged* a la espera de que el usuario revise y decida.

El renombrado de `Assets/` → `assets/` se hizo a nivel de carpeta y luego archivo a archivo
dentro de ella. Para cada archivo movido se arrastró su `.import` y su `.uid` (los `.uid`
son los que permiten que las referencias `uid://` de escenas, autoloads y recursos sigan
resolviendo sin editar nada más).

**Consecuencia:** 354 rutas renombradas y 32 archivos eliminados. Todas las referencias
`res://` del proyecto fueron reescritas y la verificación final da **0 rutas rotas**.
No se pudo ejecutar Godot (`--headless --import`) porque el binario no está en el `PATH`;
la validación se hizo por análisis estático de referencias.

## D-003 — Referencias colgantes de los `.obj` (2026-10-22)

**Contexto:** `lata.obj`, `botella_de_agua.obj`, `pepas.obj` y `machete.obj` declaran un
`mtllib` a un `.mtl` que **nunca existió** en el repositorio (referencia colgante previa a
esta reorganización; el importador de Godot solo emitía un aviso y cargaba la geometría sin
materiales).

**Decisión:** se elimina la línea `mtllib` de esos cuatro `.obj`. Se conserva en los `.obj`
cuyo `.mtl` sí existe (`desert_eagle`, `glock_17`, `bate`, `cuchillo_de_cocina`), cuya
referencia interna se actualizó al nuevo nombre del `.mtl`.

## D-004 — El Player no referencia a la UI para el juego (2026-10-22)

**Contexto:** `ui.gd` actuaba como concentrador de señales entre nodos de escenas distintas
(`player.tscn`, `ui.tscn`, escenas de armas). Para que la UI supiera qué item se usó o cuál se
soltó, el Player tenía que avisarle a la UI y la UI tenía que avisarle al Player: un viaje de
ida y vuelta de señales cuyo único propósito era transporting un dato que el Player ya tenía.

**Decisión:** la dirección de dependencia queda en un solo sentido: **UI → Player**. El Player es
la autoridad del estado de inventario; la UI es una vista. El Player **no** guarda una referencia
a la UI para la lógica de juego.

Consecuencias concretas:

- `Player.use_item()` y `Player.drop_item()` son la única vía de entrada: la UI se conecta
  directamente a ellos (`InventoryUIController.item_used → Player.use_item`).
- Se elimina el viaje de ida y vuelta `player.grabbed_object → UI → player`: ahora el Player
  gestiona la recogida (`_on_grabbed_object` → `inventory.pick_up` → animación).
- `WeaponController.ammo_source` es `player.inventory`: no hay búsqueda por grupo.
- Se conservan fuera de este alcance los grupos `"muzzle"` (destello del arma) y `"player"`
  (visión del zombi): no pertenecen al dominio del inventario.

**Alternativa descartada:** que el Player referenciara a la UI (`%UI`) para inicializarla.
Se descartó para no invertir la dependencia en el estado de juego. El cableado de arranque se
resuelve con inyección (D-005), no con referencias inversas.

## D-005 — El inventario es del Player; la UI es una vista que se inyecta (2026-10-22)

**Contexto:** el inventario (nodo `PlayerContainers`, modelos `InventoryModel` y
`EquipmentModel`) vivía dentro de `ui.tscn`. Eso obligaba a que la UI fuera dueña del estado de
juego, y a que los nodos que lo necesitan (el arma, los estados de los brazos) la buscaran por
grupo o por `%NombreUnico`, lo cual no cruza los límites de una escena (ver `ERRORES.md` E-002).

**Decisión:** el dominio del inventario se traslada a `player.tscn`. El nodo `PlayerContainers`
pasa a ser hijo del `Player`, junto a los modelos `pockets` y `equipment`. La UI se queda como
vista de un solo sentido y recibe el inventario por inyección:

```
Player.inventory  ──►  UI._ready()  ──►  InventoryUIController.bind_inventory()
                                            ├─► EquipSlotView.bind_equipment(model)
                                            ├─► HandSlotView.bind_carried(carried)
                                            └─► PlayerCarriedInventories.bind_quick_slots(hbox)
```

Reglas que se aplican:

1. **Los modelos son `@export` de `PlayerCarriedInventories`, no parámetros de `setup()`.** Así
   existen desde la instanciación de la escena y el enlace no depende del orden de los
   `_ready()` (los hijos se inicializan antes que el padre; ver `ERRORES.md` E-003).
2. **Nada se busca por grupo ni por `%NombreUnico` para llegar al inventario.** El grupo queda
   solo para lo que es interno de la UI (`equip_slots`, `hand_slots`, `drop_targets`).
3. **La UI no guarda estado del juego.** Si necesita un dato, lo pide al Player; si el Player
   necesita avisar algo, lo hace con su propia señal.

**Consecuencia:** `ui.tscn` ya no tiene conexiones de señal (0) y `player.tscn` conserva 9, de
las cuales 9 tocan a la UI. La sonda `tools/probe_inventario.gd` verifica en runtime que el
inventario es del Player, que la UI queda enlazada, que las 8 ranuras (6 de ropa + 2 de manos)
tienen su modelo y que no queda ninguna conexión rota.

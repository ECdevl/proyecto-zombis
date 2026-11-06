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

**Actualización (D-009):** `PickableItem` ahora declara
`extends RigidBody3D` directamente (la escena es una prefabricada fija), así que
este workaround ya no aplica ahí. La limitación del analizador sigue vigente
para cualquier script colgado en runtime de un tipo distinto al que declara.

---

## E-010 — Los pickables importados con `-rigid` eran inconsistentes entre objetos

**Síntoma:** con el enfoque `-rigid` de Blender, cada objeto importado se
comportaba distinto: unos traían colisión y otros no, y la forma no servía
genérica porque hay objetos circulares y otros no.

**Causa real (varias):**

1. El sufijo `-rigid` **se ignora si el mesh es el nodo raíz** de la escena
   importada (en Blender el objeto debe quedar bajo una Collection): esos
   objetos quedaban como malla simple, sin cuerpo.
2. El `RigidBody3D` generado por el importador queda en la **capa de colisión
   1** por defecto (no en la 2 del proyecto), salvo que se configure en las
   Advanced Import Settings.
3. La colisión convexa que genera el importador **varía por modelo** y no se
   puede controlar finamente; y una forma genérica (caja/esfera) no encaja
   objetos de formas muy distintas.

**Corrección (ver `DECISIONES.md` D-008):** se abandona `-rigid`. El modelo se
importa como **malla `.FBX` cruda** y el script `PickableItem` genera la
física en runtime: crea el `RigidBody3D` hijo con la capa 2, cuelga las mallas
debajo y calcula la colisión **desde la propia malla** con
`Mesh.create_convex_shape()` (un casco convexo real por objeto, no una forma
genérica). `Player.drop_item()` cuelga el script a la malla cruda al soltarla,
así que los descriptores apuntan al `.fbx` directo sin escena heredada.

**Verificación:** `tools/probe_soltar.gd` → *TODO OK* (sección 6: malla cruda →
`PickableItem` con cuerpo hijo y colisión convexa generada).

---

## E-011 — La arquitectura de D-008 no coincidía con el flujo real del proyecto

**Síntoma:** tras el rework de D-008, el usuario señaló dos problemas:
`pickable_object.gd` quedó demasiado grande (289 líneas) y el flujo de soltado
era el equivocado — se instanciaba la escena del descriptor y se le "colgaba"
el script en runtime, cuando la intención es instanciar **la escena
`pickable_object.tscn`** y que el descriptor aporte **solo el mesh** por
`item_mesh`. Además faltaba poder ver ese mesh en el editor para decorarlo
(rotarlo/posicionarlo).

**Causa real:** el diseño de D-008 partió de un supuesto incorrecto: que cada
descriptor traería su propia escena del modelo como plantilla del mundo. El
flujo real del proyecto es **una única escena física reutilizable + el mesh del
recurso**. El script terminó replicando en runtime lo que la escena fija ya
trae armado (cuerpo, área, colisión) y expuso `@export` de más
(`body_layer`, `body_mask`, `body_mass`, `collision_mode`, `interact_resource`)
para configurar valores que pertenecen a la escena.

**Corrección (ver `DECISIONES.md` D-009):** prefabricada fija
`pickable_object.tscn` (raíz `RigidBody3D` + `Malla` + `Colision` +
`AreaInteraccion`), `item_mesh: Mesh` (el `ArrayMesh` del FBX), script mínimo
con `@tool` para ver y decorar el mesh en el editor, y hook `decorar_malla()`
en `ItemDescriptor` para el look por instancia (la ropa sobreescribe para el
color aleatorio, antes mutación en `_init`). `drop_item()` solo instancia la
prefabricada y asigna descriptor + `ItemInstance`.

**Verificación:** `tools/probe_soltar.gd` → *TODO OK* (33 verificaciones);
`--check-only` limpio en los scripts modificados; `tools/probe_inventario.gd` →
flujo OK (su único fallo es una conexión rota de `zombie.tscn` perteneciente al
trabajo en curso sobre zombis, T-008).

## E-012 — Los pickables atravesaban el piso (tunneling) al soltarlos

**Síntoma:** tras validar D-009, el usuario reportó (2026-11-02) que "dentro
del juego los objetos atraviesan el piso o tienen colisiones muy inconsistentes",
y que probando a activar Continuous CD el machete ya no atravesaba el piso al
aparecer, pero al soltarlo sí, "chocando primero el mango". Sospechaba del tipo
de colisión (casco convexo derivado de la malla).

**Causa real (evidencia de `tools/probe_tunel.gd`, no especulación):**

1. **No es el tipo de colisión.** Una `BoxShape3D` del mismo tamaño atraviesa
   el piso igual que el casco convexo (ola V3) y el casco convexo descansa
   sobre un piso de caja sólida en todas las caídas (experimento B).
2. **Es un fallo de contacto con el piso TRIMESH** (`ConcavePolygonShape3D`
   de `test.tscn`, caja de 1,725 m de grosor): cuando la **primera
   penetración de un tick es grande** (≥ ~3 cm; caída ≥ ~0,6 m → impacto
   ≥ ~4,7 m/s con gravedad 20 a 120 Hz ≈ 3,9 cm/tick), Jolt **no genera
   ningún contacto**: la velocidad vertical cambia solo por gravedad mientras
   el objeto se hunde por todo el grosor del piso (traza T1 de la sonda).
   Caídas ≤ 0,30 m quedan bien en todos los pisos. `backface_collision = true`
   no cambia nada (experimento C): no es un problema de caras unidireccionales.
3. **El CCD no estaba en ninguna parte:** antes del fix, `grep continuous_cd`
   no daba ningún resultado en el proyecto. La prueba de CCD del usuario no
   quedó guardada (su estado exacto no es verificable); lo más probable es
   que la hubiera activado solo en la instancia de `test.tscn` — así el objeto
   puesto en la escena no atravesaba pero la copia soltada (instanciada desde
   el prefab, sin CCD) sí, que es exactamente el síntoma reportado.
4. Hallazgos latentes del mismo análisis:
   - Godot **no soporta escalar cuerpos/formas de colisión** (docs oficiales >
     Troubleshooting physics issues) y `_sincronizar_colision()` copiaba
     `malla.transform` **con escala** a `Colision`.
   - El prefab traía un **casco horneado del machete** con `Malla` vacía:
     `_aplicar_descriptor()` hacía `return` sin limpiar nada si el descriptor
     era `null` (y emitía `push_error("NO HAY ITEM")` también en el camino
     normal, cuando los hijos aún no existen) → objeto invisible con colisión
     ajena = "colisiones inconsistentes".

**Corrección (ver `DECISIONES.md` D-010):**

1. `continuous_cd = true` en la raíz de `pickable_object.tscn`: toda
   instancia, incluida la que `drop_item()` crea, hereda CCD.
2. La transformación de `Malla` se **hornea en los puntos** del casco convexo
   y `Colision` queda con transformación identidad (si hay escala, vive en
   los puntos, que sí es soportada).
3. Sin mesh en `Malla`, `Colision.shape` se **borra** (nunca queda un casco
   ajeno); se eliminó el casco horneado del `.tscn` y el `push_error` de
   depuración.

**Verificación:** `tools/probe_tunel.gd` → *RESULTADO: NINGÚN ATRAVIESO*
(olas V2 y V6 —esta última es la instancia real del juego con su descriptor—
5/5 escenarios: spawn plano, soltado a 6 m/s, de canto, mango-primero con giro
y caída de 30 m/s; además aserciones de CCD activo y sin casco horneado en el
prefab). `tools/probe_soltar.gd` → *TODO OK* (assert actualizado al nuevo
contrato: `Colision` en identidad con la transformación horneada);
`--check-only` limpio; `tools/probe_inventario.gd` y
`tools/check_tscn_connections.py` → solo la falla preexistente de T-008
(conexión rota de `zombie.tscn`, trabajo de zombis).

---

## E-013 — `PhysicsRayQueryParameters3D.exclude` no admite `null`

**Síntoma:** en runtime, por cada golpe de arma se imprimen dos errores:

```
ERROR: Attempted to set a variable of type 'Nil' into a TypedArray of type 'RID'.
   at: _internal_validate (./core/variant/container_type_validate.h:73)
ERROR: Condition "!_p->typed.validate(value, "set")" is true.
   at: set (core/variant/array.cpp:520)
```

**Causa:** `Projectile._camera_raycast()` hacía
`query.exclude = [owner, get_parent()]`. `exclude` es `Array[RID]`, y el
`owner` de un proyectil recién instanciado (`PROJECTILE.instantiate()` en
`weapon_controller.gd`, o `.new()` en el melee) es `null` — verificado con
sonda: `root del proyectil instanciado -> owner=<Object#null>`, y sigue en
`null` después de `add_child()`. Meter `null` en un `Array[RID]` es un error
de tipos.

La asignación no se aborta del todo: queda `[RID(0), <rid del padre>]`, así
que el efecto real es **solo el ruido de error** en cada disparo.

**Corrección:** armar el array excluyendo solo lo que aporta un RID:

```gdscript
var excluded: Array[RID] = []
for obj in [owner, get_parent()]:
	if obj is CollisionObject3D:
		excluded.append((obj as CollisionObject3D).get_rid())
query.exclude = excluded
```

`CollisionObject3D.get_rid()` está verificado en Godot 4.7.2 (la sonda imprime
el mismo RID que devuelve la conversión al asignar el cuerpo). Además, en la
práctica no hace falta excluir nada: el jugador está en la capa 8 y el zombi en
la 2, y la máscara es `WORLD_MASK | HITBOX_MASK` (1 | 512), así que ninguno de
los dos se puede golpear.

**Verificación:** `godot --headless --path . res://scenes/debug/test.tscn
--quit-after 90` → sin esos errores (queda solo el fallo de autoload
`icon_creator.tscn`, preexistente y ajeno: reproduce igual en el commit previo).

## E-014 — La dirección del impulso melee no llegaba al ragdoll (2026-11-04)

**Situación (reportada por el usuario):** "el hit direction de las melees no
funciona: el cuerpo se mueve en dirección del golpe pero la dirección no es
relativa al jugador; si lo golpeas de frente el ragdoll va a la izquierda,
pero al golpearlo de atrás va a la misma dirección".

**Investigación: la fórmula de dirección no estaba rota** —
`MeleeProjectile.setup()` ya calculaba
`push_direction = cámara.global_basis * SwingData.direction` (relativa al
jugador, ver D-013). Lo que estaba roto eran los otros dos eslabones de la
cadena `MeleeProjectile → hurt(force) → Zombie.die() → ragdoll_component.start() → pelvis`:

1. **`RagdollComponent` perdió `simulator` y `pelvis`.** El rework de ragdoll
   en curso (sin commitear) sacó los `PhysicalBone3D` de `zombie.tscn` a la
   escena nueva `scenes/zombies/zombie_ragdoll_skelly.tscn`, pero no se
   actualizaron los `NodePath` del componente: `node_paths` quedó solo con
   `"body"`. Resultado: `ZombieRagdoll._ready()` y `start()` truenan con
   `Cannot call method 'physical_bones_add_collision_exception' on a null
   value` / `Invalid assignment of property or key 'influence' ... on a base
   object of type 'Nil'` → el ragdoll no arrancaba y el impulso se perdía.
2. **Impulso con magnitud0.** En el commit `4a08f54`, `Zombie.die()` tenía
   `var force : float = 0.0` hardcodeado (ignoraba `info.force`); el rework lo
   arregló (`info.get("force")`) pero `MeleeProjectile` pasó a enviar
   `"force": knockback`, y `machete.tres` / `cuchillo.tres` no guardan
   `knockback` (queda0; solo `bate.tres` define500) →
   `pelvis.apply_central_impulse(dirección * 0)` = cero: el cadáver caía igual
   siempre, sin importar de dónde viniera el golpe.

**Corrección:**

1. Restaurar en `scenes/zombies/zombie.tscn` los `NodePath` originales (las
   rutas siguen válidas: los huesos ahora viven en la escena instanciada en
   la misma posición del árbol):

   ```tscn
   node_paths=PackedStringArray("body", "simulator", "pelvis")
   simulator = NodePath("../ZombiConRig/rig/Skeleton3D/PhysicalBoneSimulator3D")
   pelvis = NodePath("../ZombiConRig/rig/Skeleton3D/PhysicalBoneSimulator3D/Physical Bone pelvis")
   ```

2. `EquippableDescriptor.knockback` pasa a `@export var knockback: float = 20.0`
   (el valor que antes estaba hardcodeado como `force:20.0` en el `hurt()` del
   melee): machete y cuchillo empujan con20, bate conserva su500. No hay otros
   consumidores de `knockback` en los scripts (verificado con grep).

**Verificación:** `godot --headless --path . res://tools/probe_hitdir.tscn`
→ *RESULTADO: TODO OK* (9 aserciones): `direction = +X` vuela a la derecha
del jugador; girando la cámara180° el vuelo gira en el mundo (dirección
opuesta); `direction = -X` vuela a la izquierda; y el descriptor real
`machete.tres` también da impulso y va a la derecha. `probe_melee.tscn`
sigue en *TODO OK*.

**Nota:** `tools/check_tscn_connections.py` ahora marca además3 conexiones
rotas en `addons/ragdoll_wizard/ragdoll_wizard_panel.tscn`
(`CreateButton`/`ClearSlotsButton`/`CopyBoneNameButton`) — del addon nuevo
del rework, sin tocar (ver T-011); más la preexistente T-008.

## E-015 — `hurted()` y `die()` truenaban con la `info` real que mandan las balas (2026-11-04)

**Síntoma.** `tools/probe_zombie.tscn` (sonda nueva) daba **3 errores de
script reales** al matar/lastimar un zombi con la `info` que el juego
manda de verdad:

```
SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'float'.
SCRIPT ERROR: Invalid access to property or key 'global_position' on a base object of type 'Nil'.  (×2)
```

**Causa raíz.** `Zombie.die()` y `Zombie.hurted()` leían `info` como si
siempre trajera todas las claves, pero **`Projectile._apply_hit()` arma la
bala solo con `who`, `attacker` y `hit_pos`** — no trae `impulse` ni
`force`:

1. `die()`: `var force : float = info.get("force")` → `info.get()` devuelve
   `null` cuando la clave no existe, y asignar `null` a un `float` truena y
   **aborta la función**: el ragdoll no arrancaba.
2. `hurted()`: `info["attacker"].global_position` y `info["who"]...` →
   `Invalid access ... on a base object of type 'Nil'` cuando falta esa
   clave (arañazos, golpes sin atacante registrado).

En Godot un error de script **no detiene la escena**, solo aborta la
función, así que estos errores eran silenciosos en juego: la muerte
perdía el impulso y el sangrado.

**Corrección** (en `scripts/zombie/zombie.gd`, D-014):

- `_vec3(info, key)` / `_num(info, key)` — leen `info` tolerando claves
  ausentes o de tipo equivocado (`Vector3.ZERO` / `0.0` como respaldo).
- `_resolve_hit_pos(info, who)` — usa `hit_pos` si es un `Vector3` finito;
  si no, `who.global_position`; y si no hay `who`, `global_position`.
- `_find_hit_bone(info)` — devuelve `null` si falta el hitbox o el
  simulador, en vez de truenar.
- `hurted()` sale temprano con `info.is_empty()` y solo salpica si hay
  `attacker`; el flinch y el chequeo de piernas se ejecutan igual.

**Verificación:** `godot --headless --path . res://tools/probe_zombie.tscn`
→ *RESULTADO: TODO OK* (7 aserciones, sin `SCRIPT ERROR`), incluido el caso
1) `die()` con la `info` exacta de una bala llega hasta arrancar el
ragdoll.

**Relacionado:** E-014 (la cadena del impulso melee). E-015 es la causa
más profunda de la misma familia: `info` incompleta leída sin guardar.

## E-016 — Se perdió `_on_nav_target_reached()` y con ella el manejo del "objetivo perdido" (2026-11-04)

**Síntoma.** `tools/check_tscn_connections.py` reportó **5** conexiones
rotas cuando `HEAD` tiene **4**:

```
ROTA scenes/zombies/zombie.tscn: Nav.target_reached -> StateMachine/chase._on_nav_target_reached (el metodo no existe en el script)
```

**Investigación.** Comparado contra una copia limpia de `HEAD` con
`git archive` (4 rotas: las 3 de `ragdoll_wizard_panel.tscn` + la T-008),
la quinta era nueva. La función existía en `HEAD` (`chase.gd:137`) y fue
eliminada en el rework en curso, pero **la conexión se mantuvo en
`zombie.tscn`**.

Godot **no avisa en runtime** de esta desconexión: no hay línea de error
en la salida de las sondas, la señal simplemente no hace nada.

**Impacto real.** `_on_vision_target_lost()` crea un `Marker3D` con la
última posición vista del jugador y lo pone como `target`. El método
perdido era **el único sitio que lo liberaba**:

```gdscript
if target is Marker3D:
    target.queue_free()
    finished.emit("idle")
```

Sin él: (1) el `Marker3D` se fuga (nunca se libera), (2) el zombi queda
perseguindo ese marcador para siempre sin volver nunca a `idle`.

**Corrección:** restaurar `_on_nav_target_reached()` en
`scripts/zombie/states/chase.gd`, idéntica a `HEAD`, con un comentario que
explica por qué existe (la conexión vive en la escena y era la única
salida del flujo de objetivo perdido).

**Verificación:** `python3 tools/check_tscn_connections.py` → vuelve a
**4 rotas** (las preexistentes). Regresión completa: `probe_zombie` (7),
`probe_avoidance` (12), `probe_melee` (14) y `probe_hitdir` (9) → todas
*RESULTADO: TODO OK*, sin `SCRIPT ERROR`.

**Lección:** al borrar un handler hay que buscar la conexión en los
`.tscn` — `check_tscn_connections.py` la detecta, pero Godot no la
menciona.

---

## E-017 — `const` con `Engine.physics_ticks_per_second` no compila en GDScript (2026-11-06)

**Síntoma:** `tools/probe_turn.gd` no cargaba:

```
SCRIPT ERROR: Parse Error: Assigned value for constant "PHYSICS_DT" isn't a constant expression.
ERROR: Failed to load script "res://tools/probe_turn.gd" with error "Parse error".
```

**Causa real:** `Engine.physics_ticks_per_second` es una propiedad de runtime,
no una expresión constante; no se puede usar en el inicializador de un `const`.
La sonda se escribió en la sesión anterior y **nunca llegó a ejecutarse**, así
que el error quedó oculto.

**Corrección:** `var _physics_dt : float = 0.0` y asignarlo en `_ready()`:

```gdscript
_physics_dt = 1.0 / float(Engine.physics_ticks_per_second)
```

`_physics_ticks()` ya usaba `Engine.physics_ticks_per_second` directamente;
ese uso sí es válido (se evalúa en runtime).

**Verificación:** `probe_turn` carga y da *RESULTADO: TODO OK* (14 aserciones).

## E-018 — El RVO dejaba que dos zombis que andan en paralelo se solaparan (2026-11-06)

**Síntoma:** `probe_avoidance` fallaba en el escenario C:

```
FALLA nunca se atraviesan (mín 0.39 >= 0.45 m)
```

La caja de colisión del zombi mide `0.507 × 0.458` (escena
`zombie.tscn`), así que a 0.39 m de centros los cuerpos se atraviesan.

**Causa real:** desde D-018 el zombi se mueve en la dirección de su frente. Dos
zombis que van uno al lado del otro hacia el mismo objetivo ya no convergen:
van en paralelo, y el RVO no ve una colisión inminente. El radio de evitación
de la escena era `0.15`, así que el RVO consideraba correcta una separación de
0.30 m (2 × radio), menor que el ancho real del cuerpo. `CharacterBody3D` contra
`CharacterBody3D` **no resuelve la penetración** (`move_and_slide` solo desliza
contra cuerpos que no se mueven), así que la superposición quedaba visible.
En el control ciego (mask 0) el mínimo también era 0.39: no era un fallo del
RVO, era un radio mal dimensionado.

**Corrección:** `Nav.radius` de `0.15` a `0.3` en `scenes/zombies/zombie.tscn`
(el RVO mantiene los centros a ≥ 0.6 m, por encima de los 0.507 m del cuerpo).

**Verificación:** `probe_avoidance` → *RESULTADO: TODO OK* (12 aserciones);
distancia mínima **0.62 m** y desvío del RVO **0.823 m/s** frente a **0.000**
del control ciego. `probe_turn`, `probe_zombie`, `probe_melee` y
`probe_hitdir` siguen verdes.

**Lección:** `NavigationAgent3D.radius` es el círculo de evitación, no el radio
de horneado del navmesh; tiene que cubrir el cuerpo del personaje.

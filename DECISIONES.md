
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

## D-008 — Se abandona `-rigid`: la colisión de los pickables se genera desde la malla (2026-10-30)

**Contexto:** el enfoque `-rigid` resultó **inconsistente entre objetos** (ver
`ERRORES.md` E-010). Además, el flujo real del proyecto es importar el modelo
de Blender como **malla `.FBX` cruda** (sin sufijo) y arrastrarla a la escena;
los descriptores ya apuntan con `item_mesh` a esos `.fbx` crudos (`bate.fbx`,
la escena inline de `agua.tres`, etc.). El bloqueo era la **colisión**: no se
podía usar una forma genérica (caja/esfera) porque hay objetos circulares y
otros no, y cada uno necesita su forma real. El usuario pidió reworkear los
pickables generando el `CollisionShape3D` **desde la propia malla**.

**Decisión:**

1. **El script `PickableItem` (`scripts/components/pickable_object.gd`) arma
   solo toda la física.** Sigue declarando `extends Node3D` (se cuela donde
   caiga) y en `_ready()`:
   - **Cuerpo físico:** si la raíz ES un `RigidBody3D` lo usa; si no, **crea un
     `RigidBody3D` hijo** (capa `body_layer = 2`, mask `body_mask = 7`,
     `body_mass`). Un nodo no puede cambiar de tipo en runtime, por eso el
     cuerpo es un hijo cuando la raíz es la malla.
   - **Adopción de mallas:** cuelga las `MeshInstance3D` del modelo debajo del
     cuerpo (`reparent()` conservando la transformación global) para que sigan
     la física. Caso especial: si la raíz misma es la malla, la copia a un hijo
     del cuerpo y vacía la raíz (mismo dibujo, misma transformación).
   - **Colisión desde la malla:** por cada malla,
     `Mesh.create_convex_shape(true, false)` → un `ConvexPolygonShape3D` con el
     **casco convexo real de ese objeto** (la lata con forma de lata, el bate
     con forma de bate). Se posiciona en el espacio local del cuerpo con
     `_transform_in()` (composición de transformaciones locales, sin depender
     del caché global recién agregado). El convexo es **obligatorio** para un
     cuerpo dinámico; el trimesh (`create_trimesh_shape()`, cóncavo) solo sirve
     bien en cuerpos estáticos, queda como opción (`CollisionMode.TRIMESH`) y
     `CollisionMode.NONE` permite colisión armada a mano.
2. **`Player.drop_item()` convierte la malla cruda en agarrable:** si
   `item_mesh` no tiene el script pero su raíz es un `Node3D`, le cuelga
   `PickableItem` en runtime (`set_script`) y le pasa el `ItemInstance`. Así
   los descriptores pueden apuntar al `.fbx` crudo **sin escena heredada**.
3. **`PickableItem.resolve(n)`** sube del cuerpo físico (hijo) al nodo raíz con
   el script. `ui.gd::_on_item_instruct_body_entered` lo usa porque el cuerpo
   que entra en el `ItemInstruct` (máscara 2) ya no ES el `PickableItem`, sino
   su hijo `RigidBody3D`.

**Consecuencia:** los descriptores **no necesitan** repuntar `item_mesh` a una
escena heredada con el script: basta con que apunten a la malla/FBX del modelo
(T-007 se reduce). El `-rigid` queda descartado. `pickable_object.tscn` sigue
siendo solo legado. Verificado con `tools/probe_soltar.gd` → *TODO OK* (nueva
sección 6: malla cruda → `PickableItem` con cuerpo hijo y colisión convexa
generada desde la malla), `tools/probe_inventario.gd` → *TODO OK*,
`tools/check_tscn_connections.py` → 0 conexiones rotas.

## D-009 — Prefab física fija de pickable + `item_mesh: Mesh` y `@tool` para decorar (2026-11-01)

**Contexto:** el usuario corrigió el rumbo de D-008 (ver E-011): el script
`pickable_object.gd` había quedado demasiado grande (289 líneas) generando en
runtime el cuerpo, la adopción de mallas, la colisión y el área, cuando la
intención es más simple: **al soltar se instancia SIEMPRE la escena
`pickable_object.tscn`** (una prefabricada física fija) y el descriptor solo
aporta el mesh, por `item_mesh`. Además se pidió ver ese mesh en el editor para
poder rotarlo/posicionarlo y decorar así cada objeto.

**Decisión:**

1. **`pickable_object.tscn` es una prefabricada fija** (raíz `RigidBody3D`,
   capa 2 / mask 7, con el script) de hijos fijos: `Malla` (`MeshInstance3D`),
   `Colision` (`CollisionShape3D`) y `AreaInteraccion` (`Area3D` capa 2 con
   esfera de radio 1, inline). `Player.drop_item()` instancia SIEMPRE esta
   escena (`PICKABLE_SCENE`); si el descriptor no tiene `item_mesh`, el item
   vuelve al inventario: nunca se pierde.
2. **`ItemDescriptor.item_mesh` pasa de `PackedScene` a `Mesh`** (el `ArrayMesh`
   del FBX). El script vuelca ese mesh en el hijo `Malla`. El hook
   `decorar_malla()` (no-op en la base) deja que cada tipo decore la malla de
   SU instancia; `WearableItemDescriptor` lo sobreescribe para el color
   aleatorio, que antes mutaba `item_mesh` en `_init` (compartido por todas las
   copias de la prenda).
3. **Script mínimo con `@tool` (~90 líneas, antes 289):** `extends RigidBody3D`
   (elimina el workaround del E-009 y toda la maquinaria de creación de
   cuerpos). Al asignar el descriptor en el editor se ve el mesh en `Malla`
   (rotable/posicionable/escalable para decorar) y `_process` regenera el casco
   convexo (`Mesh.create_convex_shape(true, false)`) SOLO cuando la malla o su
   transformación cambian, copiándole la transformación a `Colision` para que
   el collider quede pegado a lo que se ve. `drop_item()` asigna descriptor e
   `ItemInstance` antes de entrar al árbol; `_ready` los resuelve si faltan.
4. **Íconos:** `ensure_icon()` construye una `MeshInstance3D` temporal con el
   mesh y `decorar_malla()` (mismo look que en el mundo) y `icon_creator.gd`
   la captura: `create_texture()` ahora recibe la malla ya preparada, no una
   escena a instanciar.
5. **`test.tscn`:** el bate, el cuchillo y el machete pasan de
   FBX-con-script-adentro a instancias de `pickable_object.tscn` con
   `item_descriptor` asignado (el flujo de decoración en el mundo).

**Consecuencia (migración de datos, T-007):** los `.tres` con `item_mesh`
apuntando a un `.tscn` quedan con el campo en null y deben repuntar al
`ArrayMesh` del FBX en el editor (10 archivos: remera, pantalon_largo, mochila,
zapatillas, cuchillo, bate, machete, desert_eagle, glock-17, agua).
`pickup_area.tscn` y `new_sphere_shape_3d.tres` quedan huérfanos (el área y la
esfera ahora viven inline en la prefabricada). Verificado con
`tools/probe_soltar.gd` → *TODO OK* (33 verificaciones, incluida la asignación
del descriptor en el árbol y el seguimiento colisión↔malla decorada),
`--check-only` limpio en los scripts modificados y
`tools/probe_inventario.gd` → flujo OK (el único fallo es una conexión rota de
`zombie.tscn` perteneciente al trabajo en curso sobre zombis, no a este
refactor).

## D-010 — Pickables con Continuous CD y colisión sin escala en el nodo (2026-11-02)

**Contexto:** E-012 — los objetos atraviesan el piso. La sonda
`tools/probe_tunel.gd` demostró que la causa es un fallo de contacto con el
piso trimesh cuando la primera penetración por tick supera ~3 cm (no el tipo
de colisión), y que con Continuous CD todos los escenarios quedan.

**Decisión:**

1. **`continuous_cd = true` en la raíz de `pickable_object.tscn`.** Es la
   corrección que la documentación oficial recomienda para tunneling y la
   sonda lo confirma: 5/5 escenarios (hasta 30 m/s) quedan sobre el piso
   trimesh del juego. Al vivir en el prefab, lo hereda toda instancia (spawn
   y `drop_item()`); no hay que tocar cada escena ni el script. Costo: solo
   los cuerpos con CCD hacen el test barrido, y los pickables son pocos.
2. **La transformación de `Malla` se hornea en los puntos del casco** y
   `Colision` queda en identidad. Motivo: Godot no soporta escalar cuerpos
   ni formas de colisión (docs > Troubleshooting physics issues); una escala
   en el nodo era un bug latente. Horneada la escala en los puntos, decorar
   la malla a mano (rotar/posicionar/escalar) sigue funcionando y la colisión
   queda superpuesta al mesh.
3. **Sin mesh no hay colisión:** si `Malla.mesh` queda en `null`,
   `Colision.shape` se borra. El prefab ya no horneaba casco: una instancia
   sin descriptor no puede quedarse con la silueta de otro objeto.
4. **Se descartan como solución única:** engrosar la forma (ola V4: sigue
   atravesando), subir los ticks de física (no hace falta con CCD) y cambiar
   el piso a caja sólida (funciona — experimento B — pero es un arreglo del
   escenario, no del objeto; si algún otro cuerpo rápido atraviesa, considerar
   `BoxShape3D` en el piso: queda anotado como hallazgo).

**Verificación:** ver E-012.

## D-011 — El golpe cuerpo a cuerpo es un rayo fino, no un volumen (2026-11-02)

**Contexto:** `MeleeProjectile` usaba una cápsula de `hitbox_radius`
(0.15–0.75 m) que barría todo lo que tocaba y se quedaba con el hitbox más
cercano de cada zombi: el golpe pegaba en cualquier extremidad que cayera
dentro del volumen y el jugador no podía elegir dónde apuntar.

**Decisión:**

1. **El hitbox del melee es un `intersect_ray` desde la cámara hacia adelante,
   de `weapon_range` metros**, con `collide_with_areas = true`,
   `collide_with_bodies = false` y máscara `HITBOX_MASK` — exactamente los
   parámetros de la cápsula, cambia solo la forma del test. El primer hitbox
   que toca es el único que recibe el golpe: no hay selección "por zombi" ni
   daño múltiple por swing.
2. **Al ser un rayo, apuntar es elegir la extremidad.** La cabeza
   (`zombie_head`) recibe el daño completo y guarda `melee_hit_dir` para el
   ragdoll; cualquier otra hitbox recibe 0.1, que es lo mínimo para que
   `Zombie.hurted()` se ejecute y dispare el stun de pierna
   (`zombie_legs_left` / `zombie_legs_right`). Ese flujo ya existía: lo que
   faltaba era la precisión, y la aporta el rayo.
3. **`Melee.hitbox_radius` queda reservado y sin uso** (el comentario del
   descriptor lo dice explícitamente). El dato se conserva en `bate.tres` y
   `machete.tres` por si el hitbox vuelve a ser un volumen.
4. **Por ahora el mundo no corta el golpe:** la máscara no incluye
   `WORLD_MASK`, así que el melee atraviesa paredes (comportamiento previo de
   la cápsula, que tampoco chocaba con cuerpos). Cambiarlo es sumar
   `WORLD_MASK` a `collision_mask` en `MeleeProjectile.fire()`; queda anotado
   en el comentario del script.

**Alternativa descartada:** cono/cuña de detección (más fiel al arco del arma)
y barrido de varios rayos. Se descartan por ahora: el rayo simple ya habilita
apuntar por extremidad y no hay feedback visual del arco que lo justifique.

**Verificación:** `tools/probe_melee.tscn` → *RESULTADO: TODO OK* (9
aserciones): apuntar a la pierna pega en `thight_left` con 0.1 de daño y deja
al zombi en `stun`; apuntar a la cabeza pega en el hitbox de cabeza con el
daño completo y guarda `melee_hit_dir`; apuntar al vacío no hace nada.

## D-012 — El golpe es un abanico de rayos estático estilo L4D2, con prioridad del rayo central (2026-11-02)

**Contexto:** D-011 dejó un solo rayo de apunte. Un solo rayo es frágil:
con `hit_time` = 0.3 s, el zombi y la cámara se mueven durante el swing, y
cualquier desvío mínimo hace fallar el golpe. En Left 4 Dead 2 el melee tira
muchos rayos durante toda la animación (`melee_show_swing 1` de la guía
comunitaria *Melee weapon detailed analysis v1.5*, hecha con scripts
extraídos del `.vpk`; no hay documentación oficial de Valve). Se analizó su
mecánica y se adopta su **barrido**, no su regla de daño.

**Fuentes:** guía de Steam (id 412007318), foro de Steam/Reddit sobre la
queja *"el golpe pega en otra parte del cuerpo de la que apuntabas"*. Datos
de L4D2: rayo por *tick* desde la posición de los ojos, `melee_range` =
70 HU ≈ 1.78 m, `startdir`/`enddir` por arma, "Already Hit" (un objetivo ya
golpeado recibe 0 de los rayos siguientes) y **gana el primer hitgroup de
todo el barrido**.

**Decisión:**

1. **Etapa 1 (implementada): abanico estático en el instante de `hit_time`.**
   `SwingData` gana `sweep_angle` (0.6 rad ≈ 34°) y `sweep_rays` (7).
   `MeleeProjectile.fire()` tira `N` rayos con separación uniforme dentro
   del cono, con eje `u = normalize(A × S)`, donde `A` es la mira y
   `S = Basis_cámara · SwingData.direction` la dirección del tajo (rotar `A`
   alrededor de `u` barre exactamente el plano del swing; si `u` es
   degenerado se usa un eje de respaldo).
2. **Prioridad al rayo central (a diferencia de L4D2).** El orden de
   disparo es central primero, luego laterales crecientes por |ángulo|
   (`_ray_order`): si dos rayos pegan en el mismo zombi, gana el más cercano
   a la mira, así el rayo central sigue eligiendo la extremidad del zombi
   apuntado (cabeza/pierna de D-011). **No se copia** la regla "gana el
   primer hitgroup de todo el barrido" de L4D2: destruiría el apunte
   deliberado a extremidades, que es la mecánica que diferencia al juego.
3. **Un golpe por zombi por swing** (diccionario `ya_golpeado`, equivalente
   al "Already Hit" de L4D2). Un solo rayo toca como máximo a un zombi;
   varios rayos del mismo swing pueden pegarle a varios zombis (base del
   cleave futuro, cuando exista spawner de hordas).
4. **Los laterales solo agregan:** otros zombis y perdón de puntería; no
   roban la extremidad al zombi apuntado.
5. **Dibujo de debug** con `ImmediateMesh` + `PRIMITIVE_LINES` durante 0.5 s
   (`DRAW_DEBUG_RAYS`, solo en builds de debug), equivalente al
   `melee_show_swing 1` de L4D2, para calibrar `sweep_angle`.
6. **Costo despreciable:** 7 consultas por golpe (µs cada una).

**Alternativas descartadas:** copia literal de L4D2 (barrido por *tick* +
"primer hitgroup gana") — se reserva el barrido temporal para una Etapa 2
futura; cono/cápsula volumétrica — ya descartada en D-011.

**Verificación:** `tools/probe_melee.tscn` ampliado → *RESULTADO: TODO OK*
(14 aserciones, 3 corridas seguidas). Caso nuevo: apuntar a 12 cm de lado
delante de la cabeza hace errar al rayo central pero pega un lateral
(`hurt_count == 1`, sigue siendo un solo golpe por zombi). Detalle de la
sonda: el esqueleto del zombi (brazos) puede interponerse entre la cámara y
la extremidad, así que `_aim` barre 16 ángulos alrededor del eje Y y elige
uno desde el que el rayo central llega limpio al hitbox apuntado
(`_find_clear_dir` / `_reaches`, misma consulta de rayo que el golpe).

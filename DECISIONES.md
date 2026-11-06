
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

## D-013 — La dirección del impulso melee es relativa al jugador, según `SwingData.direction` (2026-11-04)

**Contexto:** el usuario reportó que el ragdoll no respetaba la dirección
relativa al jugador (ver E-014: la fórmula estaba bien, rota estaba la cadena
que lleva el impulso hasta la pelvis).

**Decisión (elegida por el usuario):** la dirección del empuje sale de
`SwingData.direction` interpretado en el espacio de la cámara:

```gdscript
push_direction = cámara.global_basis * swing.direction
```

- `direction = Vector3.LEFT` → el ragdoll sale hacia la **izquierda del jugador**;
- `direction = Vector3.RIGHT` → a la **derecha del jugador**;
- y gira con el jugador: si usted gira180°, la dirección en el mundo se da la
  vuelta (verificado, no es un mundo fijo).

Datos actuales: machete = `Vector3.RIGHT` (default), cuchillo y bate =
`Vector3(-1, 0, 0)`. La fórmula ya existía desde D-011; esta decisión la
fija como regla válida y agrega la sonda que la comprueba.

**Consecuencia explícita (lo definió la regla elegida):** la dirección sigue
al **jugador**, no al zombi. Con la cámara quieta, pegarle por la espalda
manda el ragdoll al mismo lado de la pantalla que pegarle de frente — es
"la izquierda/derecha del jugador" en ambos casos. Si se quisiera que el lado
se invierta con el *facing* del zombi, haría falta otra regla (mezclar con el
`-Z` del zombi); no fue la elegida.

**Verificación:** `tools/probe_hitdir.tscn` (sonda nueva) →
*RESULTADO: TODO OK* (9 aserciones), incluido el descriptor real
`machete.tres`.

## D-014 — La modularidad de `Zombie` se consigue con hooks y guardas, no con una arquitectura nueva (2026-11-04)

**Contexto:** el usuario pidió hacer la clase `Zombie` "más modular para
futuros zombis especiales". Al revisarlo, la arquitectura ya era modular:
`StateMachine` con estados que son **nodos hijos** (se agregan o quitan desde
el editor) + componentes (`HealthComponent`, `ZombieVision`,
`ZombieRagdoll`, `LookAtModifier3D`). Lo que frenaba a un zombi especial no
era la estructura sino tres cosas concretas.

**Decisión:** rework de **limpieza + hooks**, sin cambiar la arquitectura.
Ningún resource-archetype ni sistema de plantillas: sería sobre-ingeniería
para el caso de uso actual (la escena ya es el arquetipo, y se hereda en el
editor).

1. **Dos hooks de personalización** en `Zombie`, al final de `hurted()` y
   `die()`:

   ```gdscript
   func _on_hurted(_damage: float, _info: Dictionary) -> void: pass
   func _on_died(_damage: float, _info: Dictionary) -> void: pass
   ```

   Una subclase `extends Zombie` los sobreescribe y, si quiere conservar lo
   común, llama a `super`. Lo compartido (flinch, sangre, chequeo de piernas,
   ragdoll, cambio a `death`) queda en el base y no se repite.

2. **Guardas contra `info` incompleto** (ver E-015): `hurted()` y `die()`
   ya no truenan si `info` no trae `attacker`, `who`, `hit_pos`, `impulse`
   ni `force`. Helpers nuevos: `_resolve_hit_pos()`, `_find_hit_bone()`,
   `_vec3()`, `_num()`.

3. **Rutas `%` en lugar de rutas hardcodeadas**: `%Nav`, `%Vision`, `%AT`,
   `%StateMachine`, `%LookHead`, `%RagdollComponent`. Antes había una ruta
   hardcodeada `$ZombiConRig/rig/Skeleton3D` que quedó muerta. El contrato
   de escena está documentado en el encabezado de `zombie.gd`.

**Qué NO se tocó:** `zombie.tscn` y los estados. La escena ya define el
zombi; un especial nuevo parte de ella y cambia malla, exportados y estados.

**Verificación:** `tools/probe_zombie.tscn` (sonda nueva) → *RESULTADO:
TODO OK* (7 aserciones): los 6 casos de robustez de `hurted()`/`die()` más
la existencia de los hooks.

## D-015 — La evitación mutua entre zombis usa el RVO que ya traía `NavigationAgent3D`, corregiendo tres defectos (2026-11-04)

**Contexto:** el usuario pidió que los zombis se eviten entre sí. El
avoidance **ya estaba cableado** en `zombie.tscn`
(`avoidance_enabled = true`, señal `velocity_computed →
StateMachine/chase._on_nav_velocity_computed`), pero era defectuoso.

**Decisión:** usar el RVO del motor (ya era el diseño) y corregir:

1. **Doble multiplicación por `speed`.** `chase.gd` hacía
   `set_velocity(dir * speed)` y luego `velocity.x = safe_velocity.x *
   speed`: la velocidad resultante era `speed²`. Con `speed = 1.5` el zombi
   iba a 2.25 m/s; con `speed = 2.0`, a 4.0. `set_velocity()` recibe
   **velocidad deseada en m/s** y `velocity_computed` devuelve **velocidad
   segura en m/s**: no se multiplica otra vez.
2. **`nav.max_speed = speed` en `_ready()`.** El RVO usa `max_speed` como
   tope de su simulación; sin sincronizarlo, calculaba con el default de
   10.0 m/s aunque el zombi fuera a 1.5.
3. **Condición muerta eliminada.** El handler chequeaba
   `zombie.direction != Vector3.ZERO`, variable que **nunca se asignaba**
   en el flujo nuevo. Ahora la única fuente de movimiento en `chase` es el
   callback del RVO, con guarda `state != self` (la señal está cableada en
   la escena y sigue llegando desde `stun`/`death`/`stagger`).

**Parámetros de Nav: sin cambios.** Los defaults están verificados contra
la documentación de Godot 4.7 (`radius = 0.5`, `neighbor_distance = 50.0`,
`max_neighbors = 10`, `time_horizon_agents = 1.0`, `avoidance_layers` /
`avoidance_mask = 1` → mutuo por defecto, `use_3d_avoidance = false` →
evita en el plano XZ, correcto para un zombi terrestre). Por eso
`zombie.tscn` **no se tocó**.

**Medición (no umbral inventado):** la sonda corre tres escenarios con los
mismos spawns — A) un zombi solo, B) cuatro con `avoidance_mask = 0`
(**control ciego**: el RVO sigue emitiendo `velocity_computed` — la
documentación dice que la señal depende de `avoidance_enabled`, no de la
máscara — pero ignora a los demás), C) cuatro con avoidance real. El
desvío lateral se mide sobre `safe_velocity` (lo que decide el RVO), no
sobre la velocidad final (que mezclaría el RVO con las colisiones físicas),
y la aserción compara **C contra B**, no contra un número fijo:

| escenario | desvío lateral | dist mín entre pares |
|---|---|---|
| A) un zombi | 0.000 m/s | — |
| B) control ciego (mask 0) | 0.003 m/s | 0.56 m (se tocan) |
| C) avoidance real | **0.373 m/s** | **1.00 m** |

El RVO duplica la separación (0.56 → 1.00 m) y añade el desvío lateral,
con la velocidad correcta (2.00 m/s, no 4.00) y los 4 llegando al objetivo.

**Verificación:** `tools/probe_avoidance.tscn` (sonda nueva) →
*RESULTADO: TODO OK* (12 aserciones); regresión `probe_zombie` (7),
`probe_melee` (14) y `probe_hitdir` (9) → todas *TODO OK*.

## D-016 — El stagger lateral del zombi: el arma manda el lado (melee); el empuje descompone en el espacio local (2026-11-05)

**Contexto:** el usuario creó `stumble_left` / `stumble_right` en `zombie_rig.glb`
(las llamó "stagger_left/stagger_right") y pidió: (a) que al empujar al zombi de
un lado se reproduzca la animación de ese lado; (b) que al golpearlo con una
melee en el cuerpo, el stagger se reproduzca según la dirección del arma (X
espacio del SwingData, rotulo "hacia la izquierda o la derecha"); (c) si X es
0, no empuja.

**Decisión:**

1. **Melee — la regla es `SwingData.direction.x` (espacio cámara):**
   `swing_x > 0` → `stumble_right`, `swing_x < 0` → `stumble_left`,
   `swing_x == 0` (`is_zero_approx`) → **no se emite stagger** (el cuerpo del
   zombi no reacciona al golpe con desplazamiento; `hurted()` hace `pass` y
   termina en `_on_hurted`). Cuchillo swing2 (`Vector3(0, 1, 0)`) es el caso
   concreto de X = 0. Las balas no traen `swing_x` → camino de empuje
   (comportamiento anterior intacto).
2. **Empujón — descomposición en el espacio LOCAL del zombi** (espejo de la
   lógica existente de `from_behind`): `f = dir · (-basis.z)`,
   `s = dir · basis.x`; es lateral si `|s| > |f|`. `s > 0` → `stumble_right`,
   `s < 0` → `stumble_left`, si no `stumble_forward`/`stumble_back` según
   `from_behind = f >= 0`. Un empujón con `s == 0` **no** se bloquea (sigue
   stumbereando adelante/atrás); la regla "X es 0 no empuja" aplica solo al X
   del arma, no al empujón — si no, un empujón frontal nunca provocaría
   stagger y rompería el comportamiento existente.
3. **Yaw:** en stagger lateral `_target_yaw = zombie.rotation.y` (el zombi no
   gira 90°); en el frontal/trasero se mantiene el `atan2(-look_dir.x, -look_dir.z)`
   existente. `from_behind`/`lateral` gobiernan la rama.
4. **Nombres:** las animaciones son `stumble_left`/`stumble_right` (nombre real
   en el glb). El AnimationTree `zombie_sm` (escena `zombie.tscn`) se amplió
   con 2 subrecursos `AnimationNodeAnimation`, 2 estados
   (`stumble_left` → posición (159, 380), `stumble_right` → (595, 90)) y 8
   transiciones idle1/idle2 ↔ stagger_left/right (xfade 0.2, switch_mode 1
   hacia el stagger / 2 desde el stagger, espejo de las de stumble_fwd/back).
   `playback.start()` no necesita transiciones, son paridad del editor.
5. **Reimport requerido:** `godot --headless --path . --import` — el cache
   `.godot/imported` estaba viejo; tras reimportar,
   `get_animation_list()` muestra `stumble_left`/`stumble_right`. El reexport
   elimina la `stun` duplicada — comportamiento conocido y aceptado; el `.glb`
   ya traía las animaciones del usuario.
6. **Sin cambios de alcance:** cabeza = muerte, pierna = stun,
   `stagger_count`/`max_stagger`, `_start_ragdoll_mid_stagger`,
   `knockback_distance` y la dirección de desplazamiento del ragdoll intactos.
   `stagger.gd` chequea `contains("stumble")` — compatible sin tocar.
7. **Regla interpretada:** "X es 0 entonces no lo empuja" = X del
   `SwingData.direction` (espacio de la cámara, según el comentario del
   descriptor), NO la X del mundo.
8. **`tools/probe_hitdir.gd` adaptado a `death.gd`** (trabajo del usuario sin
   commitear: reparenta el rig a la escena y libera la raíz del zombi al
   morir): la pelvis se captura ANTES del golpe (objeto que sobrevive al
   `queue_free()` de la raíz) y `queue_free()` final queda con guarda
   `is_instance_valid`. La sonda valida lo mismo que antes; estaba rota por
   ese cambio, no por D-016.

**Verificación:** `probe_melee` (14), `probe_zombie` (7), `probe_hitdir` (9) →
*RESULTADO: TODO OK* en todas. `check_tscn_connections.py` → 3 rotas
(addon `ragdoll_wizard`, preexistentes; ver T-011). Pendiente probar en el
juego: T-013.

## D-017 — Movimiento del jugador con inercia: aceleración, frenado con derrape e impulso aéreo conservado (2026-11-05)

**Contexto:** el usuario pidió: "hay que cambiar el movimiento del jugador,
hagamos que tenga aceleración y desaceleración, porque ahora se siente muy
poco inmersivo". La estructura ya existía (commit `293acbe` añadió
`PlayerStats.acceleration/deceleration/air_control`) pero los valores
(40/50/0.3) hacían la rampa imperceptible: la velocidad de caminar (5) se
alcanzaba en 5/40 = 0.125 s. Además dos detalles mataban la sensación de
inercia: en el aire sin input se frenaba a `deceleration · air_control` =
15 u/s² (un salto esprintando perdía TODO el impulso horizontal en 8/15 =
0.53 s, menos que los 0.65 s de airtime = 2·6.5/20), y `jump.gd` hacía
`velocity = Vector3.ZERO` al aterrizar (borraba la inercia horizontal).

**Decisión:**

1. **Valores nuevos en `player_stats.gd`** (grupo "Movement Feel"):
   `acceleration` 40 → **12** (caminar 5 en t = v/a = 0.42 s, esprintar 8 en
   0.67 s), `deceleration` 50 → **25** (parar desde 5 en 0.20 s con derrape
   v²/(2a) = 0.5 m; desde 8 en 0.32 s / 1.28 m), `air_control` 0.3 → **0.5**.
   Los tres ajustables desde el inspector (el sub-recurso PlayerStats de
   `player.tscn` usa los defaults del script).
2. **Contra-giro con producto punto** en `player.gd::__player_movement`: si
   la velocidad horizontal va en CONTRA de la dirección pedida
   (`horizontal.normalized().dot(direction) < 0`) se frena con
   `deceleration` en vez de `acceleration` (respuesta inmediata al giro de
   180°; a favor o desde parado se acelera).
3. **Impulso aéreo conservado:** con `direction == ZERO` y en el aire NO se
   toca la horizontal (antes se frenaba a 15 u/s²); con input en el aire el
   control es `acceleration · air_control` = 6 u/s². En el suelo sin input
   se frena normal con `deceleration`.
4. **Aterrizaje:** `jump.gd` ahora hace `velocity.y = 0.0` (conserva la
   horizontal; el suelo la frena con deceleration → tras aterrizar de un
   salto esprintando se resbalan ~1.28 m) y emite `idle` igual; la cadena
   idle → walk (velocity != 0) → decelera → idle ya lo maneja.
5. **Sonda nueva** `tools/probe_movimiento.tscn/.gd` (corre como escena,
   E-004): aceleración, freno con derrape integrado, sprint y salto en
   carrera con impulso conservado. La física del proyecto corre a **120 Hz**
   (las esperas se calculan con `Engine.physics_ticks_per_second`, no por
   frames); el piso de la sonda es 200×200 porque las pruebas acumulan
   ~25 m y con un piso chico el player cae por el borde (falso "no frena").

**Verificación:** `probe_movimiento` → *RESULTADO: TODO OK* (13 aserciones:
v = 1.20 a 0.1 s y 5.00 a 1 s; freno v = 4.58 a 2 frames de soltar, parada
en 0.18 s, derrape medido 0.44 m ≈ teórico 0.50 menos 2 frames de arranque;
sprint 8.00; aire: despegue 8.00 → mínima 8.00 → aterriza 8.00 → frena
solo). El aviso `1 ObjectDB instance was leaked at exit` de la sonda es
preexistente al instanciar `player.tscn` headless (lo repite
`probe_avoidance`, que no comparte código con ella; ya anotado en TASKS.md
"Notas de la validación"). Pendiente probar en el juego: T-014.

## D-018 — Movimiento del zombi: andar hacia adelante y girar el cuerpo; sin snap de mirada ni ataque de espaldas (2026-11-06)

**Contexto:** el usuario pidió:

> "vamos a cambiar el movimiento de los zombis tambien, se siente muy poco
> inmersivo, en vez de ellos poder rotar para snapear al jugador, hagamos que
> ellos tengan que caminar hacia adelante e ir rotando para quedar mirando de
> frente al jugador y verlo, de esta manera si estamos atras de ellos y
> (supongamos) hacemos ruido no se daran vuelta instantaneamente"

**Decisión:**

1. **El cuerpo es la única fuente de orientación.** `chase` no strafea ni
   camina hacia atrás: la velocidad deseada es `-basis.z * speed` (el frente
   del rig es -Z) y el yaw se acerca al rumbo de la ruta a `turn_speed_deg`
   (90°/s, exportado en `zombie.gd`) con `rotate_toward`. El giro solo se
   aplica **mientras hay velocidad horizontal** (`STILL_SPEED = 0.05`): parado
   no pivota. Para mirar al jugador tiene que caminar y girar; nunca hay un
   giro instantáneo.
2. **Se elimina el snap de la cabeza.** `%LookHead` es un
   `LookAtModifier3D` sobre el hueso `head` con
   `primary_limit_angle = 120°` e `influence` por defecto **1.0**. `idle`
   lo apuntaba al `yaw` del `Player` con un tween de 0.5 s. Como el look-at
   se aplica con `duration = 0` (snap interno; el tween solo mezclaba la
   influencia), la cabeza giraba hasta 120° sin que el cuerpo girara: **ese
   era el snap**. Ahora `idle._on_vision_target_spotted()` solo emite
   `chase`, y `chase.enter()/exit()` limpian `target_node` y ponen
   `influence = 0`. La cabeza queda solidaria al cuerpo.
3. **La visión ya sigue al cuerpo.** `ZombieVision._check_sight()` calcula el
   FOV con `owner.global_transform.basis.z * forward_sign` (120°), no con la
   cabeza. Por lo tanto el zombi solo "ve" lo que su cuerpo encara; no hay
   forma de detectar al jugador por detrás. **No existe sistema de oído
   todavía**, así que el caso "ruido a la espalda" no puede ocurrir hoy; el
   estado `turn` (90°/s en el sitio, gradual) queda listo para cuando se
   añada. No se inventó el sistema de ruido.
4. **No se ataca de espaldas.** Nuevo `attack_angle_deg = 70` y
   `is_facing_target()` en `chase`: si el objetivo está dentro de
   `grab_range` (1.0 m en la escena) pero fuera del cono, el zombi sigue
   caminando (y girando) en vez de detenerse a arañar. Así el ataque también
   exige quedar de frente, no solo la persecución.
5. **Evitación:** `Nav.radius` 0.15 → **0.3** en `zombie.tscn` (ver
   `ERRORES.md` E-018). Con el andar hacia adelante los zombis viajan en
   paralelo y el radio de 0.15 no cubría el cuerpo (caja 0.507 × 0.458):
   se solapaban a 0.39 m. Con 0.3 el RVO mantiene ≥ 0.6 m (medido 0.62).
6. **Sonda `probe_turn`:** se reparó el `const` que no compilaba (E-017) y
   se amplió a 14 aserciones: A) objetivo detrás → avanza hacia adelante y
   gira como mucho `turn_speed_deg × 0.5 s`, con la cabeza sin target y con
   influencia 0; B) a los 3 s el cuerpo ya mira al objetivo; C) `turn` gira
   en el sitio a velocidad limitada; D) `is_facing_target()` es falso con el
   jugador a la espalda y verdadero de frente; E) datos inválidos no dejan
   el estado atrapado.

**Consecuencia:** el zombi puede tardar en reaccionar (hasta 2 s para un
giro de 180° a 90°/s) y puede pasar de largo al jugador mientras gira. Es el
comportamiento pedido: la reacción deja de ser un snap y pasa a ser
locomoción. `turn_speed_deg` es ajustable desde el inspector si se quiere más
lento o más rápido.

**Verificación:** `probe_turn` (14) → *TODO OK*; `probe_avoidance` (12) →
*TODO OK* (mín 0.62 m, desvío RVO 0.823 vs 0.000 del control ciego);
`probe_zombie` (7), `probe_melee` (14) y `probe_hitdir` (9) → *TODO OK*.
`check_tscn_connections.py` → 3 rotas, todas del addon `ragdoll_wizard`
(T-008 ya no aparece). Pendiente probar en el juego: T-015.

## D-019 — Ragdoll: cuerpo raíz único, masas humanas y límites anatómicos verificados contra los ejes reales (2026-11-06)

**Contexto:** el ragdoll se veía como "un saco de papas" y con extremidades
erráticas. El análisis encontró cinco causas concretas en
`zombie_ragdoll_skelly.tscn` / `zombie.tscn`:

1. `Physical Bone root` era un cuerpo libre (`joint_type = 0`) con una
   cápsula de 0.875 m, sin joint y sin que nada lo referenciara. Caía y
   colisionaba por su cuenta.
2. Masas absurdas: pelvis 33 kg contra 1 kg en todos los demás huesos
   (total ≈53 kg, casi todo en una cápsula de 0.13 m).
3. Codos, manos, pulgares y cuello tenían los tres ejes 6DOF en 0: joints
   rígidos.
4. Damping incoherente: pelvis/columna a 0 y brazos/piernas a 22–55.
5. Límites asimétricos o ejes bloqueados (`spine` solo extensión, hombros
   con un solo sentido, rodillas con `-165°` de flexión).

**Decisión:**

1. **Eliminar `Physical Bone root`** de la escena base y sus overrides en
   `zombie.tscn` y `ragdoll_testing.tscn`. Sin `body_a`,
   `PhysicalBone3D::_reload_joint()` hace `joint_clear`; el `pelvis` queda
   como único cuerpo raíz libre del ragdoll. Su `joint_type = 2` (cono)
   queda sin uso.
2. **Repartir la masa por segmento** (total ≈70 kg): pelvis 8, spine 8,
   chest 14, neck 5 (incluye la cabeza), hombros 1.5, brazos 2.5,
   antebrazos 1.5, manos 0.4, pulgares 0.1, muslos 7, pantorrillas 3.5,
   pies 1.0.
3. **Límites anatómicos en grados Godot.** La convención importa: el
   wrapper de Jolt invierte el signo (`angulo_godot = -angulo_dextrógiro`
   alrededor del eje local; ver `jolt_generic_6dof_joint_3d.cpp`). Los ejes
   se midieron con `tools/probe_ragdoll_axes.gd` y la convención se
   comprobó con `tools/probe_6dof_sign.gd`. Resultado:

   | Hueso | X | Y | Z |
   |---|---|---|---|
   | spine | -45..25 | -20..20 | -30..30 |
   | chest | -30..20 | -20..20 | -35..35 |
   | neck | -30..30 | -25..25 | -30..30 |
   | shoulder L/R | -20..20 | -25..25 | -20..20 |
   | upper_arm L/R | -110..45 | -75..75 | -60..60 |
   | forearm L/R | -130..5 | -3..3 | -3..3 |
   | hand L/R | -60..60 | -20..20 | -40..40 |
   | thumb L/R | -10..10 | -10..10 | -10..10 |
   | thigh L/R | -20..110 | -30..30 | -20..20 |
   | shin L/R | -140..0 | -5..5 | -5..5 |

   `pelvis` y `foot L/R` usan conos: pelvis swing 45 / twist 30 (sin uso al
   ser raíz) y pies swing 35 / twist 20 (antes twist 180, casi libre).
4. **Damping y materiales homogéneos:** `linear_damp = 0`,
   `angular_damp = 0` en todos; `bounce = 0`; `friction = 0.8` (pies 1.0);
   `linear_restitution = 0`. El damping del joint (`angular_damping = 1`)
   queda como única disipación angular.
5. **Herramientas:** `tools/probe_ragdoll_axes.gd` (ejes del miembro en el
   frame del joint), `tools/probe_6dof_sign.gd` (signo de los límites),
   `tools/probe_ragdoll_behavior.gd` (estabilidad numérica) y el visor
   `scripts/debug/ragdoll_debug.gd` para tunear en vivo.

**Consecuencia:** el ragdoll ya no tiene un cuerpo fantasma ni inercia
desbalanceada; los límites permiten flexión/extensión realista y el twist
queda acotado. Sigue pendiente la validación visual en el editor para
afinar ángulos (sobre todo hombros y caderas) y el knockback del bate
(T-011).

**Verificación:** `probe_ragdoll_behavior` → *TODO OK* (20 huesos, 19
joints; velocidad final 0.12 m/s, estiramiento máximo 0.273 m durante el
impacto y 0.102 m al reposo, sin NaN, sin atravesar el piso);
`probe_zombie` → *TODO OK*; `ragdoll_testing.tscn` 300 frames headless sin
errores de script; `check_tscn_connections.py` → solo las 3 conexiones
rotas preexistentes del addon `ragdoll_wizard`.

## D-020 — Damping del CUERPO con `DAMP_MODE_REPLACE` (Jolt ignora el damping del joint 6DOF) + cámara libre e impulso por hueso en `RagdollDebug` (2026-11-06)

**Contexto:** tras D-019 el ragdoll seguía con temblor y "flacidez" ("saco de
papas"). Al investigar el wrapper `modules/jolt_physics/joints/
jolt_generic_6dof_joint_3d.cpp` (rama 4.7-stable) se confirmó que **Jolt
descarta** con `WARN_PRINT` casi todos los parámetros del joint 6DOF:
`linear_limit_softness`, `linear_restitution`, `linear_damping`,
`angular_limit_softness`, `angular_damping`, `angular_restitution`,
`angular_force_limit` y `erp` (constantes `G6DOF_DEFAULT_*`). Solo aplican los
límites lower/upper con sus flags, los *limit springs*, los motores y los
springs comunes. Por tanto, el `angular_damping = 1` de los joints (única
disipación de D-019) **no tenía efecto** en Jolt. La palanca real de
disipación es el damping del **cuerpo** (`PhysicalBone3D.angular_damp` /
`linear_damp` en `DAMP_MODE_REPLACE`), que el motor sí respeta.

El mismo código confirma la convención de signo ya documentada: Godot niega
los ángulos al pasarlos a Jolt (`lower = -upper; upper = -lower`).

**Decisión:**

1. **Aplicar damping del cuerpo con `DAMP_MODE_REPLACE`** en los 20 huesos de
   `scenes/zombies/zombie_ragdoll_skelly.tscn`: por defecto
   `linear_damp_mode = 1` / `linear_damp = 0.08` /
   `angular_damp_mode = 1` / `angular_damp = 0.55`; y en el torso
   (`pelvis`, `spine`, `chest`) `linear_damp = 0.10` / `angular_damp = 0.70`
   (más damping donde más masa). `zombie.tscn` **no requiere cambios**: sus
   overrides de huesos solo llevan `transform`/`joint_offset`/`body_offset` y
   heredan el damping de la escena base.
2. **No tocar los parámetros de softness/damping del joint 6DOF**: no tienen
   efecto en Jolt (quedan como estaban, inertes).
3. **Cámara libre estilo editor** y **aplicación de impulso al hueso
   seleccionado** en `scripts/debug/ragdoll_debug.gd`: clic derecho captura el
   ratón y permite mirar/orbitar, rueda avanza/retrocede, `W/A/S/D` + `Q/E`
   desplazan (Shift = rápido), todo con `process_mode =
   PROCESS_MODE_ALWAYS` (funciona aun con el árbol en pausa). El panel añade un
   bloque para elegir eje X/Y/Z, signo +/−, magnitud (0.5–200) y un botón
   "Aplicar impulso" que llama
   `PhysicalBone3D.apply_central_impulse(dir * magnitud)` sobre el hueso
   seleccionado, para observar hasta dónde llegan sus constraints.

**Consecuencia / verificación:** `probe_ragdoll_behavior` → *TODO OK*
(velocidad final 0.088 m/s, antes 0.121; estiramiento al reposo 0.044 m,
antes 0.102; estiramiento máximo 0.256 m, antes 0.273; sin NaN, pelvis en
rango, ningún hueso bajo el piso). Mejora modesta pero medible; la mejora
grande es la cámara libre y el impulso por hueso para afinar en vivo.
`ragdoll_testing.tscn` headless sin errores de script. La validación visual y
el ajuste fino de `linear_damp`/`angular_damp` quedan para el usuario con el
panel `RagdollDebug` (T-011).

---

## D-021 — Flacidez del ragdoll: subir el damping del cuerpo y apretar límites (los limit springs de Jolt no son accesibles) (2026-11-06)

**Contexto:** tras D-020 la flacidez restante ("saco de papas") seguía visible.
El usuario eligió en su momento "las dos juntas": damping moderado + limit
springs suaves.

**Hallazgo que bloqueó parte del plan:** los *limit springs* del joint 6DOF de
Jolt **no son accesibles desde GDScript**. En `modules/jolt_physics/` (rama
4.7-stable), `JoltPhysicsServer3D` es una clase interna de C++ con
`_bind_methods() {}` **vacío**: sus métodos `generic_6dof_joint_set_jolt_param`
/ `..._set_jolt_flag` (enum `G6DOFJointAxisParamJolt` /
`G6DOFJointAxisFlagJolt`, p. ej. `G6DOF_JOINT_LINEAR_LIMIT_SPRING_FREQUENCY`,
`G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT_SPRING`) **no están expuestos a
scripting**. El enum base `PhysicsServer3D.G6DOFJointAxisParam` solo trae los
parámetros que Jolt descarta (softness/restitution/damping/erp). Tampoco existe
propiedad de nodo `PhysicalBone3D` para ellos (`grep limit_spring` en la escena
base → 0 resultados). Solo una GDExtension/C++ los expondría.

**Decisión (alternativa elegida por el usuario): "más damping + límites".**

1. **Subir el damping del cuerpo** (`DAMP_MODE_REPLACE`) en los 20 huesos de
   `zombie_ragdoll_skelly.tscn`: `angular_damp = 0.90` / `linear_damp = 0.12`;
   torso (`pelvis`, `spine`, `chest`) `angular_damp = 1.10` / `linear_damp =
   0.14`. (Antes: 0.55/0.08 y torso 0.70/0.10.)
2. **Apretar límites angulares** donde se veían flojos:
   `shoulder_left`/`shoulder_right` x[-12,12] y[-15,15] z[-12,12];
   `hand_left`/`hand_right` x[-45,45] y[-15,15] z[-30,30]; `spine` x[-25,25]
   (antes −45).
3. **`ragdoll_debug.gd`: selector de huesos en la simulación.** Casillas por
   hueso (marcadas por defecto) + botones Todos / Ninguno / Reiniciar
   simulación; usa `PhysicalBoneSimulator3D.physical_bones_start_simulation(
   names: Array[StringName])` para simular solo los marcados y
   `physical_bones_stop_simulation()` para reiniciar. Sirve para aislar un
   hueso y ver hasta dónde llega su constraint.

**Consecuencia / verificación:** `probe_ragdoll_behavior` → *TODO OK*
(pelvis final `(0.131, 0.037, 0.283)`, velocidad final 0.177 m/s,
estiramiento final 0.049, estiramiento máximo histórico **0.251**, antes 0.255;
sin NaN, pelvis en rango, ningún hueso bajo el piso). `ragdoll_debug.gd`
compila limpio (`--check-only`) y `ragdoll_testing.tscn` corre headless sin
errores de script. Falta la validación visual del usuario con el panel.

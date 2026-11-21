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

## D-031 — Linterna: `HoldableDescriptor` + `FlashlightController` (2026-11-17)

**Contexto:** se propuso hacer `FlashlightDescriptor` hijo de `EquippableDescriptor`. Eso rompería
el juego: `HandsModel._find_main_weapon()` decide el viewmodel con `is EquippableDescriptor`, así
que una linterna sola en la mano derecha se convertiría en "arma principal" sin `viewmodel_model`
y `_on_weapon_changed()` daría `push_error("falta viewmodel_model")`. Además heredaría seis
exports de arma que no usa. El código de linterna vivía dentro de `WeaponController` (~170
líneas) y duplicaba la búsqueda de huesos de `ViewmodelAnimator`, con `caster_mask` sobrescrito
por 1, `_rig_skeleton` marcado antes de verificar los huesos y un toggle que solo miraba la mano
izquierda aunque `can_equip()` permite la derecha.

**Decisión:** separar tres responsabilidades:
1. `HoldableDescriptor` (@abstract) entre `ItemDescriptor` y `EquippableDescriptor` /
   `FlashlightDescriptor`: aporta `get_hands_required() = 1` y la acción "equipar". Así se
   elimina la duplicación sin cambiar `HandsModel` ni convertir la linterna en arma principal.
2. `FlashlightController` como nodo hermano de `WeaponController` bajo el Player: dueño único
   del toggle, del rig de huesos y del modelo. Escucha `hands.changed` y `Player.weapon_changed`;
   `WeaponController` ya no expone `toggle_flashlight()`.
3. `SkeletonUtils` con la normalización de nombres de huesos y la búsqueda de la cadena del
   brazo izquierdo, compartida por `ViewmodelAnimator` y `FlashlightController`.

La linterna acepta cualquiera de las dos manos (arity 1) pero se ancla visualmente al hueso de la
mano izquierda del viewmodel. Los parámetros de luz que antes eran números mágicos pasan a
exports del descriptor y `caster_mask` ya no se sobrescribe.

**Consecuencia:** `EquippableDescriptor` sigue siendo el tipo que identifica armas; no se tocó
`HandsModel`. El nodo `FlashlightController` tiene `unique_name_in_owner = true` y se accede como
`%FlashlightController`. `resources/items/linterna.tres` no cambió (mismo uid de script).
Verificación: editor headless sin errores de parse; sonda `tools/probe_linterna.gd` con 15
aserciones → *TODO OK*.

## D-032 — AnimationTree para armsy y migración de `weapon_ap.play` (2026-11-17)

**Contexto:** `ViewmodelAnimator` solo existe mientras hay arma, así que la capa
`ctx_flashlight` desaparecía al soltarla. `player.tscn` ya tenía un `AnimationTree` para armsy
con el blend `context` y `ctx_flashlight`, pero nunca se activaba y se animaba con
`AnimationPlayer.play("idle")`. Además `WeaponController` reproducía casi todas sus animaciones
con `weapon_ap.play(...)` y tenía fallbacks del mismo estilo en `run.gd`.

**Decisión:**
1. `ArmsAnimator` envuelve el tree existente de armsy (`parameters/player_sm/playback`,
   one-shots `grab`/`punch` y `parameters/context/blend_amount`) y expone la misma interfaz que
   `ViewmodelAnimator`. Es `RefCounted`, creado por el Player: no depende del orden de `_ready()`.
2. `FlashlightController` aplica `ctx_flashlight` a ambos animadores: viewmodel (si existe) y
   armsy (siempre). El primer refresco se diferencia para esperar a `Player._ready()`.
3. Toda reproducción de animaciones pasa por el AnimationTree. Se eliminaron los
   `weapon_ap.play`/`play_backwards`/`queue` de `WeaponController` y los fallbacks de `run.gd`.
   `weapon_ap` queda solo como referencia de metadatos (duración de reload, búsqueda de huesos).
   `ViewmodelAnimator` ya no cae a `ap.play()` si no hay playback.
4. Se retiró el `draw` invertido al desequipar: el state machine no tiene un estado *holster*,
   y animarlo con el AnimationPlayer era la última dependencia del viejo camino.
5. Se corrigieron los `travel()` a estados inexistentes que el tree apagado toleraba
   (`pistol_idle`, `Ledge`, `normal`).

**Consecuencia:** con o sin arma, armsy mantiene la pose de la linterna hasta desequiparla.
`animation_tree.active == true` y `player.playback` ahora son operativos. El uno-shot de punch
de armsy se dispara por parámetro del tree, no por `AnimationPlayer`. Verificación:
`tools/probe_linterna.gd` ampliado a 22 aserciones → *TODO OK*."

## D-033 — Cámara FPS anclada al hueso del cuello (2026-11-17)

**Contexto:** el Señor reexportó el FPS_BODY con animaciones nuevas desde Mixamo y pidió que la cámara quede pegada al cuello: debe seguir la **posición** del hueso (`spine.004`, `BoneAttachment3D` ya creado en `player.tscn`) pero **no su rotación**, para que agacharse, caminar, etc. no desalineen la vista. La altura se manejaba antes con constantes (`CAM_HEIGHT_*`) y un tween sobre `yaw.position:y` en los estados `idle`/`crouch`/`prone`, independiente de la animación.

**Decisión:**
1. Insertar `CameraRig` (`Node3D`, `NeckCameraRig`) entre `Yaw` y `Pitch`, con `unique_name_in_owner`. `Pitch`, `Camera3D`, `PushHitbox`, `WeaponPivot` y el viewmodel se reparentan juntos. Así se mueve toda la cámara sin tocar `Yaw` (moverlo realimentaría el seguimiento, porque `FPS_BODY` es su hijo) ni `Pitch` (su `position:x` la usa `LeanController` y su `position.z` es el retroceso de la cámara).
2. `CameraRig._process()` copia la posición global del `BoneAttachment3D` convertida a espacio local de `Yaw` con `yaw.to_local()`. Copiar `global_position` directo haría orbitar la cámara con el mouse. La rotación sigue siendo exclusiva de `Yaw` (horizontal) y `Pitch` (vertical); el rig no rota.
3. Se resta el `z` estático de `Pitch` (`-0.14508156`) para que el origen de `Camera3D` coincida **exactamente** con el hueso. No se resta `x`: el desplazamiento lateral del lean debe conservarse.
4. `process_priority = 1`: `AnimationPlayer`/`AnimationTree` tienen prioridad 0, así que el rig lee la pose ya calculada en el mismo frame. `Skeleton3D.skeleton_updated` se descartó: existe en la documentación pero la sonda registró 0 emisiones.
5. Se eliminan `CAM_HEIGHT_*`, `CAM_LERP_TIME` y `tween_cam_height()`, y las asignaciones de altura en `idle.gd`, `crouch.gd` y `prone.gd`. El cuerpo define ahora la altura de la cámara; los estados solo gestionan colisiones y transiciones.

**Consecuencia:** `Camera3D` queda a ~1,41 m en idle (9 cm más baja que antes) y baja ~0,57 m respecto a `Yaw` al agacharse, siguiendo la animación real en lugar de un tween fijo. ADS, view punch, recoil, lean y climb siguen operativos porque `Yaw`, `Pitch`, `WeaponPivot` y `Camera3D` mantienen sus nombres y unique names; hubo que corregir las `NodePath` escritas a mano (E-033). Verificación: `tools/probe_neck_cam.gd` → 18 comprobaciones, *TODO OK* (distancia cámara-hueso < 0,14 mm en idle, con yaw/pitch girados, en crouch y al volver a idle; rotación de cámara idéntica a la de `Pitch`). `tools/probe_linterna.gd` → 0 fallos; `probe_abuse --case=lean` → lean intacto.

## D-034 — Ciclo día/noche autocontenido (2026-11-18)

**Contexto:** el Señor pidió un ciclo día/noche con duraciones reales configurables para el día y la noche, ubicado en un `Node3D` de una escena aparte que se pueda agregar o quitar sin problemas, con sistema de horas y con la dirección del sol cambiando según la hora.

**Decisión:**
1. `scenes/environment/day_night_cycle.tscn`: raíz `Node3D` con `scripts/world/day_night_cycle.gd` (`class_name DayNightCycle`), más tres hijos propios: `WorldEnvironment`, `Sun` y `Moon` (`DirectionalLight3D`). No referencia nada externo: se instancia y se elimina como cualquier otra escena, sin tocar `scenes/debug/test.tscn` ni los autoloads.
2. Duraciones reales `@export day_duration_seconds = 120.0` y `night_duration_seconds = 60.0`, validadas > 0 en `_ready()`. No se usa `Timer`: `_process(delta)` acumula el tiempo de la fase activa.
3. Reloj continuo `0..24` con `start_hour`, `day_start_hour` y `night_start_hour` exportados. Cada fase avanza `span_hours * delta / duración` **sin modular** para detectar correctamente los cruces por medianoche; solo la hora expuesta se reduce con `fmod`. Convención asumida: `hour_rate = horas_de_la_fase / duración_real` (con los valores por defecto, 10 s/hora de día y 5 s/hora de noche). Si se desea que todas las horas duren lo mismo, hay que cambiar los rangos horarios de las fases, no solo las duraciones.
4. Trayectoria: sol de azimut `sun_rise_azimuth_deg` (90°) a `sun_set_azimuth_deg` (270°) con elevación `sin(t·PI) · sun_max_elevation_deg` (75°); luna en arco inverso con el 70 % de la elevación. Según la documentación de `DirectionalLight3D`, la luz emite por −Z de su basis global y la posición se ignora, así que solo se asigna `global_basis`. `Basis.looking_at()` ya apunta −Z al objetivo, por lo que no se invierte ningún eje (E-036).
5. `Environment` propio con `background_mode = BG_COLOR`, `ambient_light_source = AMBIENT_SOURCE_COLOR` y `ambient_light_sky_contribution = 0.0`: sin esto, `ambient_light_color` no surte efecto y el cambio de color del cielo no se ve (E-035).
6. Interpolación de color/energía/cielo con `smoothstep()` en una ventana de `twilight_hours` alrededor de amanecer y atardecer. API pública: `start()`, `stop()`, `set_hour()`, `get_hour()`, `get_phase()`, `get_sun_direction()`, `get_time_left_in_phase()`; señales `phase_changed`, `hour_changed` y `sun_direction_changed` para desacoplar a los consumidores.

**Consecuencia:** el sistema es complementariamente desechable y no modifica el entorno de la escena principal. Verificación: `tools/probe_dia_noche.gd` → 15 comprobaciones, *TODO OK* (duraciones de 10 s/5 s, fase y hora en cada transición, sol alto al mediodía y en el horizonte a las 18, luna encendida y sol apagado de noche, cielo diurno más claro y `stop()` congelando el reloj). Reescaneado el editor por E-034 antes de validar.

## D-035 — Skyboxes por hora en el ciclo día/noche (2026-11-18)

**Contexto:** el Señor aportó tres mapas equirectangulares de 1024×512 en
`assets/sprites/skys/`: `06_psx_morning_fog.png` (mañana,
`uid://drdawpa0chuik`), `02_psx_golden_hour.png` (tarde,
`uid://qqcm5wlawjyf`) y `10_psx_night.png` (noche,
`uid://bskybywtmignr`). La escena ya tenía la de mañana enlazada a un
`PanoramaSkyMaterial`, pero `_apply_environment()` forzaba `BG_COLOR` y el
override `env` se aplicaba después de `_apply_all()`, de modo que ningún
skybox llegaba a verse (E-038).

**Decisión:**
1. `DayNightCycle` expone tres `Texture2D` (`morning_sky_texture`,
   `afternoon_sky_texture`, `night_sky_texture`), asignadas en el `.tscn`
   mediante los UIDs de importación. Se mantiene un único `Sky` con un único
   `PanoramaSkyMaterial`; la conmutación cambia solo su propiedad `panorama`,
   con guardia para no reasignar la misma textura cada frame.
2. Umbrales exportados `morning_sky_end_hour = 12.0` y
   `night_sky_start_hour = 19.0`. Se usan rangos circulares semiabiertos:
   mañana `[day_start_hour, morning_sky_end_hour)`, tarde
   `[morning_sky_end_hour, night_sky_start_hour)` y noche
   `[night_sky_start_hour, day_start_hour)`, que envuelve la medianoche.
3. `Environment.background_mode = BG_SKY` únicamente si hay `Sky` con
   `PanoramaSkyMaterial` y textura válida; en caso contrario se conserva
   `BG_COLOR` como respaldo.
4. Se mantiene `ambient_light_sky_contribution = 0.0` y
   `ambient_light_source = AMBIENT_SOURCE_COLOR`: el skybox es solo visual,
   mientras la luz ambiente sigue interpolándose suavemente en los
   crepúsculos.
5. El `env` override se instala en `_ready()` **antes** de `_apply_all()` y
   `_apply_environment()` consulta un único `_get_environment()`.

**Consecuencia:** la conmutación entre los tres cielos es discreta en los
umbrales indicados (no hay fundido entre texturas, porque `PanoramaSkyMaterial`
no expone mezcla entre dos mapas). Los umbrales son ajustables en el Inspector.
Verificación: `tools/probe_dia_noche.gd` ampliado a 22 comprobaciones → *TODO OK*
(texturas asignadas, `BG_SKY` activo, mañana a las 8, tarde a las 15, noche a
las 22, más las 15 comprobaciones originales). Escena cargada en headless sin errores.
Posteriormente el Señor rechazó el cambio instantáneo; esta decisión queda
sustituida por D-036 en lo relativo al skybox.

## D-036 — Fundido continuo entre skyboxes (2026-11-18)

**Contexto:** con D-035 los cielos conmutaban de golpe en 12:00 y 19:00. El
Señor indicó: «no, no es muy discreto, cambia instantaneamente, no podemos
agregarle una transicion?». `PanoramaSkyMaterial` no expone mezcla entre dos
mapas, pero la documentación oficial confirma que `Sky.sky_material` acepta
`ShaderMaterial`.

**Decisión:**
1. Nuevo `shaders/sky_blend.gdshader` (`shader_type sky;`) con dos `sampler2D`
   (`sky_from`, `sky_to`, hint `source_color`) y un `float sky_blend` con
   `hint_range(0,1)`. La función `sky()` muestrea ambos panoramas en
   `SKY_COORDS` y aplica `COLOR = mix(...)`. La sintaxis exige el `;` después
   de `shader_type` (E-039).
2. `day_night_cycle.tscn`: el `Sky` usa ahora un `ShaderMaterial` con esos tres
   uniforms. Se marca `resource_local_to_scene = true` en el `ShaderMaterial`,
   el `Sky` y el `Environment` para que cada instancia de la escena pueda
   modificar sus uniforms sin afectar a las demás (la documentación advierte
   que los cambios de uniform afectan a todas las instancias si se comparte el
   recurso). `Sky.process_mode = 2` (INCREMENTAL), recomendado cuando hay
   uniforms personalizados.
3. `sky_transition_hours = 1.0` (horas de reloj, ancho total del fundido,
   ajustable 0..6). Cada fundido ocupa media hora antes y media después del
   umbral. Se usan tres ventanas centradas en `morning_sky_end_hour`
   (mañana→tarde), `night_sky_start_hour` (tarde→noche) y `day_start_hour`
   (noche→mañana, en coordenada local 24≡0). El peso se calcula con
   `smoothstep`, no lineal, para que arranque y termine suavemente.
4. `_apply_sky()` calcula la pareja de texturas y el peso, y escribe los
   uniforms solo si cambian. Si falta el `ShaderMaterial` o alguna textura, se
   degrada a `BG_COLOR`. Si los umbrales están desordenados se avisa y se usa
   cambio instantáneo como respaldo.
5. La iluminación y la luz ambiente siguen interpolándose por separado como en
   D-034; el fundido del skybox es únicamente visual.

**Consecuencia:** la transición es continua en los tres cambios de cielo, con
duración en horas de reloj (no en segundos reales): con los valores por defecto
dura 1 hora de reloj, es decir 10 segundos reales de día o 5 de noche.
Verificación: `tools/probe_dia_noche.gd` ampliado a 27 comprobaciones →
*TODO OK*, incluyendo fundido parcial a las 11:45 y fundido noche→mañana a las
05:45. Escena cargada en headless sin errores.

## D-037 — Escopeta: perdigones dispersos con daño dividido (2026-11-19)

**Contexto:** el proyecto ya traía el arma (`resources/weapons/firearm/remington.tres`,
viewmodel `.glb`, malla de mundo y un pickup en `scenes/debug/test.tscn`) y el enum
`Weapon.WEAPON_TYPE.SHOTGUN`, pero ninguna implementación de dispersión: `Projectile`
lanzaba un único rayo en `-basis.z` y `WeaponController` instanciaba un solo proyectil
por disparo. Además `_damage_for()` es temporal (`9999` en cabeza, `0` en el resto),
así que el `damage` del descriptor ni siquiera se usaba en armas de fuego.

**Decisión:**
1. `Projectile._camera_raycast()` se parte en un envoltorio que espera **un**
   `physics_frame` y un helper `_trace_ray(origin, direction, max_range)` sin
   `await`. Así una descarga de N perdigones no se reparte entre N frames.
   La bala única conserva exactamente su comportamiento anterior.
2. Nueva `ShotgunProjectile extends Projectile` (`scripts/weapons/shotgun_projectile.gd`):
   dispara N rayos dentro de un cono. El perdigón 0 va **siempre** por la mira;
   los N−1 restantes se reparten con distribución uniforme en ángulo sólido,
   siguiendo la fórmula ya usada en `blood_splatter.gd::_spray()`:
   `cos_t = lerp(1, cos(α), randf())`, `sin_t = sqrt(1 − cos_t²)`, `φ = randf()·TAU`.
   El cono se construye con `Projectile._basis_from_up(forward)` (eje local Y =
   dirección de la mira).
3. `Weapon` expone `pellets_per_shot` (default 1) y `pellet_spread_deg`
   (default 4°). `WeaponController.load_projectile(gun)` elige la subclase solo
   cuando `weapon_type == SHOTGUN` y `pellets_per_shot > 1`; el resto de armas
   sigue con `PROJECTILE`. Un cartucho consume una bala y emite `gun_fired` una vez.
4. `ShotgunProjectile._damage_for()` devuelve `damage` para **cualquier** hitbox de
   zombi, no el `9999/0` de la base. El daño se divide en `setup()`:
   `damage = weapon_damage / pellets`. Si los N impactan (a quemarropa) la suma
   es exactamente el daño del arma; si fallan perdigones, se pierde esa parte.
   Esto es una excepción deliberada a la regla temporal de daño por zona: sin
   ella, los perdigones laterales harían 0 y quemarropa no podría sumar el total.
5. `remington.tres`: `pellets_per_shot = 8`, `pellet_spread_deg = 4.0` y
   `curr_bullets = 8` (antes estaba en 0, así que `shoot()` rechazaba cada disparo).

**Consecuencia:** con 50 de daño y 8 perdigones, cada uno hace 6.25. El máximo
de la escopeta es 50, muy por debajo del `9999` que hace hoy un headshot de
pistola; es una decisión de balance a revisar cuando se sustituya el daño
temporal por una tabla de zonas. El `knockback` del descriptor sí se pasa a los
perdigones (las balas comunes siguen ignorándolo, como antes).

**Verificación:** `godot --headless --path . res://tools/probe_escopeta.tscn`
→ `RESULTADO: TODO OK` (18 comprobaciones): datos del descriptor, 50/8 = 6.25
por perdigón y suma 50, 9 rayos con 0° todos por la mira, con 8° el perdigón 0
exacto y el resto dentro del cono (máx. ~7.9°), y `WeaponController` elige
`ShotgunProjectile` para la remington y `Projectile` para la glock. La sonda
guarda las direcciones en un Array externo porque `fire()` llama a `queue_free()`
y el `Recorder` ya no existe al comprobarlas. Editor headless reescaneado (E-034)
y sin errores de parse nuevos.

---

## D-038 — Refactor de `WeaponController`: operaciones y comportamiento inyectado (2026-11-19)

**Situación:** `weapon_controller.gd` tenía ~86 condicionales. Los guards de
muerte/input/agarre/recarga se repetían en cada acción, la discriminación por
tipo de arma (`as Weapon`, `as Melee`, `weapon_type == SHOTGUN`) aparecía en 6+
sitios y el abort de recarga se replicaba en 6 bloques idénticos con 3 flags que
sincronizar a mano. Agregar un arma obligaba a tocar el controlador.

**Decisión:** cuatro capas, sin registro de guards encadenables (se descartó como
over-engineering):

1. `Player.can_act()` es la única fuente de verdad para muerte, locks de input y
   estado `grabbed`. `AttackOperation.is_valid()` la revalúa tras cada `await`
   (E-025/E-026). Se usa también en `normal.gd`, `aim.gd` y `consuming.gd`.
2. Polimorfismo en descriptores: `EquippableDescriptor` delega `can_reload()`,
   `get_reload_time()` y `create_projectile()` en un `behaviour: AttackBehaviour`.
   `normal.gd` llama a un único `attack()` sin castear.
3. `ReloadOperation extends AttackOperation` sustituye los 3 flags y los 6
   bloques de abort por un solo `cancel()`. La recarga escalonada se resuelve en
   un bucle interno, ya no por reentrancia. Se conserva `reloading` en el
   controlador porque `normal.gd:27` y `player.gd` lo leen.
4. Strategy por subclases de `AttackBehaviour` (`Resource`, `@abstract`):
   `FirearmBehaviour`, `ShotgunBehaviour` y `MeleeBehaviour`, con
   `FirearmAttack`/`MeleeAttack` como operaciones. Un arma nueva se agrega
   creando una subclase de behaviour y asignándola en el `.tres`, sin tocar el
   controlador ni los descriptores existentes.

`shoot()` y `swing()` quedan como wrappers de `attack()` por compatibilidad con
las sondas. Defaults: `Weapon._init()` → `FirearmBehaviour`, `Melee._init()` →
`MeleeBehaviour`; `remington.tres` → `ShotgunBehaviour` via `SubResource`.

**Detalle de serialización (causa de un fallo intermedio):** en un `.tres`, todo
`[ext_resource]` debe declararse ANTES del `[sub_resource]` que lo referencia.
`remington.tres` tenía el `sub_resource` en la línea 3 y el `ext_resource` con id
`4_behav` en la 11, lo que producía `Can't load cached ext-resource id` y hacía
que el behaviour cayera al default `FirearmBehaviour`. Reordenado el archivo y
reescaneado el editor (E-034), la sonda instancia `ShotgunProjectile` de nuevo.

**Eliminación de comentarios:** por instrucción del Señor, se eliminaron todos
los comentarios de los archivos tocados (incluido `player.gd`) y se corrigieron
los `:=` preexistentes en esos mismos archivos a declaraciones con tipo explícito.
La documentación `.md` permanece en español.

**Verificación:** editor reescaneado y `--quit` limpios (solo los 2 errores
preexistentes de `decorar_malla`/`rp_node`). `probe_escopeta.tscn`,
`probe_melee.tscn` → TODO OK; `probe_linterna.gd` → Fallos: 0;
`probe_abuse.tscn --case=lean` → sin fallos; `check_tscn_connections.py` → las
mismas 4 conexiones rotas preexistentes.

---

## D-039 — Auditoría de sistemas y refactor quirúrgico (2026-11-20)

**Situación:** el Señor pidió reanalizar inventario, armas y movimiento, valorar
su sostenibilidad, detectar prácticas que rompan la modularidad y decidir si
conviene rehacer desde cero.

**Decisión:** NO rehacer desde cero. El núcleo (modelos de inventario, UI como
vista inyectada, behaviours de armas, cámara de cuello, ciclo día/noche) es
recuperable y cuenta con 38 decisiones y más de 40 errores documentados. Un
reinicio no evita los hábitos que produjeron el estado en `Resource` (E-044) y
el widget de UI dentro del nodo de autoridad (E-045). Se adopta un refactor
quirúrgico en este orden:

1. Corregir los bloqueantes `swing_index` (E-042) y la carrera de recarga
   (E-043). **Aplicado en esta sesión.**
2. Sacar munición/cargador de los `.tres` a estado por instancia (E-044).
3. Devolver `quick_slots` a la UI (E-045).
4. Unificar input del movimiento y arreglar `jump.gd` (E-048).
5. Tabla de daño por zona y revisión de la excepción de escopeta (E-049).
6. `mochila.tres` y `update_inventory_ammo` en `drop_item` (E-046, E-047).
7. Sondas que ejecuten las operaciones nuevas de punta a punta.

**Detalle aplicado:** `WeaponController.swing_index` se declara con tipo
explícito; `is_active_operation()` comprueba identidad y `cancelled`;
`play_reload_animation()`/`play_reload_idle()` exigen el token de la operación.
Se conserva `reloading` porque `normal.gd` y `player.gd` lo leen (D-038).

**Verificación:** nueva sonda `tools/probe_refactor_d038_fixes.tscn` → TODO OK
(9 comprobaciones: golpe melee real, cancelación A/B de recarga y recarga
normal). Sin regresiones: `probe_escopeta.tscn` (18), `probe_melee.tscn` (17),
`check_tscn_connections.py` (4 conexiones rotas preexistentes). Se corrige
además TASKS.md:259: `PlayerNeeds.heal()` sí tiene rama `HEALTH`.

**Pendiente:** E-041 (knockback del melee) sigue sin corregirse; requiere
autorización expresa del Señor. La prueba en juego de la recarga escalonada
sigue abierta (T-026).

---

## D-040 — Pasos de audio disparados por la fase del sway (2026-11-20)

**Contexto:** el Señor está agregando sonidos «por los pasos» y eligió como
disparador la fase del `viewmodel_sway`. Los cuatro
`assets/sounds/Footstep Stone *.ogg` llevaban importados desde el inicio sin
ninguna referencia en scripts o escenas. `run.gd:15` llamaba
`play_audio(run_sounds)` en cada `update()`; como `play_audio()` hace
`stop()` + `play()`, el clip se reiniciaba cada frame, y además dependía de
que hubiera un arma equipada.

**Decisión:**
1. `ViewmodelSway` emite `signal footstep` cuando `fmod(bob_time, PI)` vuelve a
   cero, es decir dos veces por ciclo del `absf(cos(bob_time))` que ya mueve el
   viewmodel. El avance de fase se ejecuta **antes** del retorno por "sin arma",
   para que los pasos suenen también con las manos vacías. Se conserva la
   inhibición durante ADS por E-027.
2. `mouse_delta` se consume al principio de `_process()`, no al final del bloque
   con arma, para que no se acumule mientras no hay viewmodel.
3. `FootstepPlayer` (`scripts/components/footstep_player.gd`) es un nodo del
   Player con un `AudioStreamPlayer` propio; no reutiliza el reproductor de
   `WeaponController` para no cortar los sonidos del arma. La señal se conecta
   en `player.tscn`: `ViewmodelSway.footstep → FootstepPlayer.play_step`.
4. `resources/footsteps_stone.tres` es un `AudioStreamRandomizer` con los
   cuatro clips y variación de tono, asignado al nodo desde la escena.
5. Se eliminaron los `:=` de `viewmodel_sway.gd` y se subieron sus `@onready` a
   la cabecera, según la norma de estilo del proyecto.

**Consecuencia:** el paso suena con o sin arma, sincronizado con el bob del
viewmodel, sin tocar el audio del arma. Verificación: `tools/probe_pasos.gd`
→ *RESULTADO: TODO OK* (7 comprobaciones: nodos, randomizer, conexión, fase
antes/después del cruce y reproducción); `--quit` sin errores de script;
`check_tscn_connections.py` = 4 conexiones rotas preexistentes;
`probe_linterna.gd` → 0 fallos; `probe_abuse --case=lean` sin cambios.

**Pendiente:** `run.gd:15` sigue reiniciando `run_sounds` en cada frame; se
propone corregirlo como siguiente paso de audio.

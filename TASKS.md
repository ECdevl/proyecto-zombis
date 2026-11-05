# TASKS.md — Tareas pendientes

## En curso

- [x] **T-001 Reorganizar la estructura de archivos del proyecto** (ver `DECISIONS.md` D-001..D-003)
  - [x] Inventario completo + mapa de referencias `res://`
  - [x] Detectar duplicados exactos, archivos vacíos y código muerto
  - [x] Fase 1: `scripts/` (carpetas y archivos mal ubicados)
  - [x] Fase 2: `Assets/` → `assets/`
  - [x] Fase 3: `scenes/`, `resources/` y raíz
  - [x] Verificación: cero rutas `res://` rotas

  Resumen: 354 rutas renombradas, 32 archivos eliminados, 19 `.uid` reubicados.
  Los cambios están *staged* en git (sin commit) y son reversibles con `git reset`.
  Respaldo previo en `/tmp/opencode/zombis_backup_pre_reorg.tar.gz`.

  **Pendiente de validación en el editor:** abrir el proyecto con Godot 4.7.2 para
  forzar la reimportación de los assets movidos y confirmar que no hay errores.

- [ ] **T-011 Rework de ragdoll en curso (sin commitear, detectado 2026-11-04)**
      Trabajo sin commitear que no estaba documentado acá ni en `DECISIONES.md`:
      addon `ragdoll_wizard` nuevo (+ `project.godot`), `ragdoll_generator`
      borrado, huesos físicos movidos de `zombie.tscn` a la nueva
      `scenes/zombies/zombie_ragdoll_skelly.tscn`, `MujerZombiConRig.glb`,
      cambios en `stun.gd`, `zombie.gd` (`die()` lee `info.force` y corrige
      el typo `amage`), `ragdoll_component.gd`, `bate.tres` (range4.0 +
      knockback500), `cuchillo.tres` (sweep_angle0 en swing2),
      `swing_data.gd` (sweep_rays7→14) y `melee_projectile.gd` (debug rays
      siempre visibles, timer3s, `force:knockback`).
  - [x] Restaurar `simulator`/`pelvis` en `RagdollComponent` — el rework movió
        los huesos y no actualizó los `NodePath`; el ragdoll no arrancaba
        (E-014).
  - [ ] Afinar `knockback`: `bate.tres` =500 da≈60 m/s de pelvis (¿excesivo?);
        probar en juego. Machete/cuchillo quedan en20 (default de
        `EquippableDescriptor`).
  - [ ] `check_tscn_connections.py`:3 conexiones rotas en
        `addons/ragdoll_wizard/ragdoll_wizard_panel.tscn`
        (`CreateButton`/`ClearSlotsButton`/`CopyBoneNameButton`) + la
        preexistente T-008. **Se mantiene en 4 tras el rework de zombis**
        (E-016: se restauró `_on_nav_target_reached()`).
  - [ ] Decidir cómo commitear: el fix de E-014 vive dentro de `zombie.tscn`,
        que además contiene todo el rework.

- [x] **T-012 Rework de `scripts/zombie/`: modularidad + evitación mutua**
      (2026-11-04, D-014 / D-015 / E-015 / E-016)
  - [x] `zombie.gd`: hooks `_on_hurted()` / `_on_died()` para zombis
        especiales, guardas contra `info` incompleta, referencias `%` en
        vez de rutas hardcodeadas, `nav.max_speed = speed`, contrato de
        escena documentado en el encabezado.
  - [x] `chase.gd`: eliminar la doble multiplicación por `speed` (era
        `speed²`), quitar la condición muerta `zombie.direction`, guarda
        `state != self` en el callback del RVO, no girar con velocidad ~0.
  - [x] Restaurar `_on_nav_target_reached()` — se había perdido y con ella
        el manejo del `Marker3D` de "objetivo perdido" (E-016).
  - [x] `zombie.tscn`: **sin cambios** (los parámetros de Nav por defecto
        están verificados contra la doc de Godot 4.7; ver D-015).
  - [x] Sondas nuevas `tools/probe_zombie.tscn` (7 aserciones) y
        `tools/probe_avoidance.tscn` (12 aserciones, con control ciego
        `avoidance_mask = 0`).
  - [x] Regresión: `probe_zombie`, `probe_avoidance`, `probe_melee`,
        `probe_hitdir` → todas *TODO OK*; `check_tscn_connections.py` →
        4 rotas (las preexistentes).
  - [ ] Probar en el editor/juego: hordas grandes, que el avoidance no
        se note caro en rendimiento (el RVO cuesta con muchos agentes).

## Pendientes (detectado, no ejecutado)

- [ ] **T-002 Bugs de runtime** — *verificados en runtime con Godot headless el 2026-10-22*
  - [ ] **`player.weapon_grip` no existe** (confirmado: la propiedad no está en el
        `property_list` del `Player`). Se usa en
        `scripts/state_machine/player_states/climb.gd:24` y `hang.gd:20,44`.
        Al entrar en `hang` o `climb` salta
        `Invalid access to property or key 'weapon_grip' on a base object of type 'Player'`.
  - [x] **6 conexiones de señal a handlers inexistentes** — **resuelto (C5, 2026-10-22)**.
        Las 6 se borraron tras verificar que eran vestigiales:
        | Escena | Señal | Destino | Método ausente | Por qué se borró |
        |---|---|---|---|---|
        | `scenes/player.tscn` | `weapon_changed` | `ArmsFSM/normal` | `_on_player_weapon_changed` | El método nunca existió (verificado con `git log -S`); `WeaponController._on_weapon_changed` ya hace la animación |
        | `scenes/player.tscn` | `animation_finished` | `ArmsFSM/normal` | `_on_animation_player_animation_finished` | El método nunca existió; ningún estado de brazos escucha `animation_finished` |
        | `scenes/player.tscn` | `animation_finished` | `ArmsFSM/normal` | `_on_animation_tree_animation_finished` | Ídem |
        | `scenes/player.tscn` | `ammo_consumed` | `CanvasLayer/UI` | `_on_remove_item` | El HUD lee la munición cada frame en `ui.gd::_update_ammo()` |
        | `scenes/player.tscn` | `gun_fired` | `CanvasLayer/UI` | `_on_remove_item` | Ídem |
        | `scenes/ui/ui.tscn` | `inventory_close` | `InventoryUIController` | `_on_ui_inventory_close` | `ui.gd::toggle_inventory()` ya llama a `inventory_ui.close_loot()` |

        En todos los casos Godot no avisaba al conectar: la conexión se rechazaba en silencio y
        solo fallaba al emitir la señal. Borrarlas **no cambia el comportamiento** (eran no-ops).
        `tools/check_tscn_connections.py` ahora da **0 conexiones rotas** en las 29 escenas.

  - [ ] **`UI.inventory_open` / `UI.inventory_close` no tienen ningún oyente.** Son señales de
        la UI sin consumir. Se mantienen como API de eventos de la vista; si no se usan,
        eliminarlas.

  - [ ] `resources/clothes/mochila.tres` usa `container_model` (propiedad eliminada);
        la vigente es `container_capability`
  - [ ] `PlayerCarriedInventories.take_ammo()` muta `descriptor.rounds`, que es un
        `Resource` compartido
  - [ ] `PlayerNeeds.heal()` no tiene rama `HEALTH` pero `arm_states/consuming.gd:35` la invoca
  - [ ] `inventory_ui_controller.gd:72` y `:223` leen `descriptor.quick_slots`, que solo
        existe en `WearableItemDescriptor` (error de tipo estático en GDScript)

  - [ ] **`zombie/states/idle.gd:12`** — `Invalid access to property or key 'velocity' on a
        base object of type 'null instance'` en `physics_update`. Aparece en runtime
        (sondas headless) repetidamente: el estado se procesa con `zombie == null`.
        Observado el 2026-10-29 al validar el fix de soltado; no investigado a fondo.

  - [ ] ~~`item_inventory.gd` (sistema `Item` legacy)~~ — resuelto: el script se eliminó
        en la reorganización (T-001)

- [ ] **T-003 `README.md` desactualizado**: documenta el inventario, la jerarquía de
      descriptores, la IA de zombi y el melee tal como estaban antes de D-001.

- [x] **T-004 Clave SSH privada commiteada**: `key` y `key.pub` en la raíz del repo.
      Sacadas del control de versiones y añadidas al `.gitignore` (verificado: `git ls-files`
      no las lista).

- [ ] **T-005 Assets huérfanos** (importados por Godot pero sin uso en el juego):
      `glock.glb`, `bate.glb`, `pistol_arms.glb`, `casa2_texturizada.glb`,
      `mochila.glb`, `pantalon_largo.glb`, `remera_manga_corta.glb`,
      `zapatillas.glb`, `machete.fbx`, `cuchillo_de_cocina.obj`, `blood*.png`,
      `blood_particle.png`, `sprites/decals/*`, `decal_01.jpg`, `decal_02.jpg`,
      `t_decal_blood*.png`, `black_smoke_24.png`, `textures/sky/cielo.*`,
      `arms_01.png`, `arms_texture.png`, `textures/sky/01_up..05_front.png`,
      `scenes/weapons/firearm/{glock,desert_eagle}.tscn`,
      `scenes/weapons/melee/machete.tscn`, `scenes/weapons/viewmodel.gdshader`,
      `scenes/components/door_components.tscn`, `scenes/debug/ragdoll_testing.tscn`.

- [ ] **T-007 Pendientes de datos del refactor de pickables** (D-006, D-008, D-009, E-011):
  - [x] **Repuntar `item_mesh` a una escena heredada con el script en la raíz** —
        **OBSOLETO (D-008/D-009)**: la escena heredada ya no existe en el flujo:
        `drop_item()` instancia la prefabricada `pickable_object.tscn` y el
        descriptor aporta solo el mesh (`item_mesh: Mesh`).
  - [x] Poner **capa de colisión 2** al `RigidBody3D` — **OBSOLETO (D-009)**: la capa
        2 / mask 7 vive directo en la raíz de `pickable_object.tscn`; el script ya no
        aplica ni exporta capas.
  - [x] Definir el destino de `scenes/components/pickable_object.tscn` — **resuelto
        (D-009)**: es LA escena física fija del flujo (raíz `RigidBody3D` + `Malla` +
        `Colision` + `AreaInteraccion` inline).
  - [ ] **Migrar `item_mesh` de cada descriptor al `ArrayMesh` del FBX (D-009):**
        el campo pasó de `PackedScene` a `Mesh`, así que los `.tres` quedan con el
        campo en null. Archivos: `resources/clothes/{remera, pantalon_largo, mochila,
        zapatillas}.tres`, `resources/weapons/melee/{cuchillo, bate, machete}.tres`,
        `resources/weapons/firearm/{desert_eagle, glock-17}.tres`,
        `resources/consumables/agua.tres`. En el editor: abrir el `.fbx`, arrastrar
        la malla del `MeshInstance3D` al campo **Item Mesh** del descriptor. Después,
        en una instancia de `pickable_object.tscn` verificar escala/rotación del
        hijo `Malla` (se puede decorar a mano; la colisión lo sigue).
  - [ ] **`pickup_area.tscn` y `new_sphere_shape_3d.tres` quedaron huérfanos (D-009):**
        el área y la esfera ahora viven inline en `pickable_object.tscn`. Decidir si
        se borran (la tarea de mover `new_sphere_shape_3d.tres` a `resources/`
        queda obsoleta).

- [ ] **T-008 Conexión rota en `zombie.tscn` (trabajo en curso de zombis, no del
      refactor de inventario):** `StateMachine/chase/claw_timer.timeout →
      StateMachine/chase.claw` apunta a un método que ya no existe en
      `scripts/zombie/states/chase.gd` (detectado por `probe_inventario.gd`
      sección 4 y `check_tscn_connections.py`). Revisar al retomar el trabajo
      de zombis (Jarvis). Sigue rota tras el commit del 2026-11-02:
      `chase.gd` tiene `attack()`, `hurt_target()` y arranca `claw_timer`, pero
      ninguna `func claw`.

- [ ] **T-010 Apuntar a extremidades en el melee** (D-011 / D-012,
      2026-11-02): el golpe es un abanico de rayos estilo L4D2
      (`sweep_angle` / `sweep_rays` en `SwingData`) con prioridad al rayo
      central, que sigue pegasando en la extremidad que se apunta (validado
      con `tools/probe_melee.tscn`, 14 aserciones). Falta convertirlo en
      jugada:
      - [ ] Etapa 2 (opcional): barrido por tick durante la ventana del
            swing, como L4D2, para no errar objetivos en movimiento.
      - [ ] Tabla de daño/efecto por zona (hoy: cabeza = daño completo,
            resto = 0.1; la pierna ya deja `stun` vía `Zombie.hurted`).
      - [ ] Feedback de apunte: decirle al jugador qué extremidad tiene en la
            mira antes de golpear (crosshair/indicador).
      - [ ] Ajustar tiempos de stun y ventaja de la "combo" pierna → cabeza
            (`min_stun_time` / `max_stun_time` de `stun.gd`).
      - [ ] Decidir si `WORLD_MASK` corta el golpe (hoy atraviesa paredes).
      - [ ] Revisar rangos: machete 3.0 m vs `melee_range` de L4D2 ≈ 1.78 m.

## Hecho

- [x] **T-009 Tunneling de los pickables al soltarlos** (2026-11-02, E-012, D-010):
      `continuous_cd = true` en la raíz de `pickable_object.tscn`, transformación
      de `Malla` horneada en los puntos del casco (sin escala en `Colision`) y
      limpieza de `Colision.shape` cuando no hay mesh (se eliminó el casco
      horneado obsoleto del prefab). Validado con la nueva sonda
      `tools/probe_tunel.gd` → *NINGÚN ATRAVIESO* (incluida la ola V6, la
      instancia real del juego), `probe_soltar.gd` → *TODO OK* y `--check-only`
      limpio.

- [x] **Refactor del inventario (D-004, D-005) + C5** — rama `refactor/inventario-en-player`,
      2026-10-22. El inventario pasó de `ui.tscn` a `player.tscn`; la UI quedó como vista
      unidireccional que se inyecta; se eliminaron las señales de relevo de `ui.gd` y las
      6 conexiones rotas. Verificado con `tools/probe_inventario.gd` (TODO OK) y
      `tools/check_tscn_connections.py` (0 rotas).
- [x] `AGENTS.md` movido de `.opencode/` a la raíz del proyecto (ruta que opencode carga
      automáticamente).
- [x] **T-006 Godot accesible desde la terminal**: symlink
      `~/.local/bin/godot` → `~/.local/share/Steam/steamapps/common/Godot Engine/godot.x11.opt.tools.64`
      (Godot 4.7.2 stable). `~/.local/bin` ya estaba en el `PATH`, no hizo falta tocar
      `~/.bashrc`.
- [x] **Reimportación validada**: `godot --headless --path . --import` → **0 ERROR**,
      **0 SCRIPT ERROR**. Los `.import` fueron regenerados por Godot con las rutas nuevas
      (los hashes de `dest_files` cambiaron, por eso los `.import` aparecen como modificados).
      Carga headless de `scenes/player.tscn` y `scenes/zombies/zombie.tscn`: sin errores.

### Notas de la validación

- `scenes/ui/ui.tscn` cargada **aislada** da `SCRIPT ERROR` en `ui.gd:40` y `:54`:
  `player = get_parent().owner` es `null` porque la escena espera ser instanciada dentro
  de `scenes/player.tscn`. Es un supuesto preexistente del diseño, no un efecto de la
  reorganización (con la escena del jugador no aparece el error).
- `project.godot` no define `run/main_scene`: no hay escena principal asignada. Preexistente.
- Avisos de "ObjectDB instances were leaked at exit" al terminar el headless: artefacto
  del cierre del proceso, no del proyecto.
- `godot --headless --path . --import` deja **1 ERROR**, **preexistente en `main`**:
  `Animation name "stun" already exists in library.` — la biblioteca de animaciones del
  `zombie_rig.glb` versionado trae la animación `stun` duplicada. El importador reexporta el
  `.glb` (544432 → 608376 bytes) y al hacerlo elimina el duplicado, por eso el archivo aparece
  modificado tras importar. **No incluir `assets/models/zombies/zombie_rig.glb` en commits que no
  sean del asset** (ver `ERRORES.md` E-007).
- Avisos `FBX: ufbx warning ... Duplicate connection to 128`: vienen de los `.fbx` originales
  (`bate.fbx`, `glock.fbx`, `machete.fbx`, `cuchillo.fbx`), no de la reorganización.

### Herramientas de diagnóstico (en el repo, en `tools/`)

- `tools/check_tscn_connections.py` — analiza los 29 `.tscn` del proyecto y lista las
  conexiones de señal rotas: comprueba que el nodo destino existe, que el método destino está
  definido en el script de ese nodo (o en sus clases base) y que la señal de origen existe
  (la declara el script del nodo o es una señal del motor). Expande las escenas instanciadas.
  Uso: `python3 tools/check_tscn_connections.py`
  → *Escenas analizadas: 29 | conexiones: 19 — OK: ninguna conexión de señal está rota.*
- `tools/probe_tunel.gd` — sonda headless de tunneling (E-012): cae un objeto
  delgado (el casco real del machete, derivado del descriptor como lo hace el
  juego) sobre el piso trimesh del juego en 5 escenarios (spawn plano, soltado
  a 6 m/s, de canto, mango-primero con giro, caída de 30 m/s) con variantes:
  V1 CCD off (línea base), V2 CCD on, V3 `BoxShape3D`, V4 casco engrosado,
  V5 forma escalada y **V6 la instancia real del prefab con descriptor** —
  solo V2 y V6 cuentan en el resultado. Incluye trayectorias tick a tick y un
  barrido de alturas para hallar el umbral de la primera penetración (~3 cm).
  Uso: `godot --headless --path . --script res://tools/probe_tunel.gd`
  → *RESULTADO: NINGÚN ATRAVIESO*.
- `tools/probe_inventario.gd` — sonda headless que monta `scenes/debug/test.tscn` en un árbol
  vivo y comprueba: que el inventario lo tiene el `Player`, que la UI quedó enlazada a él, que
  las 8 ranuras (6 de ropa + 2 de manos) tienen su modelo, que no queda ninguna conexión rota,
  que `ammo_source` es `player.inventory`, y que los flujos de **recoger** y **usar** un objeto
  funcionan (el objeto entra al inventario; `use_item` lleva el FSM de `normal` a `consuming`).
  Uso: `godot --headless --path . --script res://tools/probe_inventario.gd` → *RESULTADO: TODO OK*
- `tools/probe_melee.tscn` + `tools/probe_melee.gd` — sonda del golpe cuerpo a
  cuerpo (D-011): monta un piso, una cámara y un zombi real, y apunta
  `MeleeProjectile` (machete) a una extremidad concreta. Comprueba que el rayo
  pega en ESA hitbox (se registra `health_component.hurted` y se compara
  `info.who`): pierna → 0.1 de daño + estado `stun`; cabeza → daño completo +
  meta `melee_hit_dir`; vacío → nada. **Corre como escena, no con `--script`**
  (`zombie.gd` necesita el autoload `GameManager`, inexistente en ese modo; ver
  E-004). Uso: `godot --headless --path . res://tools/probe_melee.tscn`
  → *RESULTADO: TODO OK*
- `tools/probe_hitdir.tscn` + `tools/probe_hitdir.gd` — sonda de la dirección
  del impulso melee (D-013 / E-014): mata un zombi real con `MeleeProjectile`
  desde una cámara orientada y mide la velocidad de la pelvis para ver hacia
  dónde sale volando. Comprueba que `SwingData.direction = +X` vuela a la
  derecha del jugador, que girar la cámara180° da la vuelta en el mundo, que
  `-X` vuela a la izquierda, y que el descriptor real `machete.tres` también
  da impulso (el caso "zombi de espaldas con la misma cámara" se imprime sin
  aserción, es diagnóstico). Uso:
  `godot --headless --path . res://tools/probe_hitdir.tscn`
  → *RESULTADO: TODO OK*
- `tools/probe_zombie.tscn` + `tools/probe_zombie.gd` — sonda de robustez de
  `Zombie` (D-014 / E-015): comprueba que `die()` e `hurted()` no truenan con
  la `info` real de una bala (sin `impulse`/`force`), con `info` vacía, con
  hitbox de pierna sin atacante, con `hit_pos` no finito y con `attacker` sin
  `who`; y que los hooks `_on_hurted()` / `_on_died()` existen. **Corre como
  escena, no con `--script`** (E-004). Uso:
  `godot --headless --path . res://tools/probe_zombie.tscn`
  → *RESULTADO: TODO OK*
- `tools/probe_avoidance.tscn` + `tools/probe_avoidance.gd` — sonda de la
  evitación mutua (D-015): monta piso + `NavigationRegion3D` con un navmesh
  armado a mano (cuadrado 24×24 m, sin hornear) + objetivo real
  (`player.tscn`), y corre `states/chase.gd` en tres escenarios con los
  mismos spawns: **A)** un zombi solo (control sin vecinos), **B)** cuatro
  con `avoidance_mask = 0` (**control ciego**: el RVO ignora a los demás
  pero sigue emitiendo `velocity_computed`), **C)** cuatro con avoidance
  real. Mide la velocidad (detecta el bug de doble `×speed`), el desvío
  lateral sobre `safe_velocity` (no sobre la velocidad final, para no
  mezclarlo con las colisiones), la distancia mínima entre pares y la
  llegada al objetivo. **Corre como escena.** Uso:
  `godot --headless --path . res://tools/probe_avoidance.tscn`
  → *RESULTADO: TODO OK*
- `tools/dump_engine_signals.gd` — genera `tools/engine_signals.py`: la tabla de señales que
  declara cada clase del motor usada en el proyecto. Se regenera solo si se agregan clases:
  `godot --headless --path . --script res://tools/dump_engine_signals.gd`

Nota: en modo `--script` los autoloads todavía no existen cuando se compila la cadena de
dependencias, así que aparecen errores de compilación falsos. Ver `ERRORES.md` E-004.

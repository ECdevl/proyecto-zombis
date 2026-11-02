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
      de zombis (Claude).

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
- `tools/dump_engine_signals.gd` — genera `tools/engine_signals.py`: la tabla de señales que
  declara cada clase del motor usada en el proyecto. Se regenera solo si se agregan clases:
  `godot --headless --path . --script res://tools/dump_engine_signals.gd`

Nota: en modo `--script` los autoloads todavía no existen cuando se compila la cadena de
dependencias, así que aparecen errores de compilación falsos. Ver `ERRORES.md` E-004.

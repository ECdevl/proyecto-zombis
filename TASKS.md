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
  - [ ] **6 conexiones de señal a handlers inexistentes** (confirmado en runtime):
        | Escena | Señal | Destino | Método ausente |
        |---|---|---|---|
        | `scenes/player.tscn:849` | `weapon_changed` | `ArmsFSM/normal` | `_on_player_weapon_changed` |
        | `scenes/player.tscn:850` | `animation_finished` | `ArmsFSM/normal` | `_on_animation_player_animation_finished` |
        | `scenes/player.tscn:851` | `animation_finished` | `ArmsFSM/normal` | `_on_animation_tree_animation_finished` |
        | `scenes/player.tscn:863` | `ammo_consumed` | `CanvasLayer/UI` | `_on_remove_item` |
        | `scenes/player.tscn:864` | `gun_fired` | `CanvasLayer/UI` | `_on_remove_item` |
        | `scenes/ui/ui.tscn` | `inventory_close` | `InventoryUIController` | `_on_ui_inventory_close` |
        Godot no avisa al conectar: solo falla cuando la señal se emite.
  - [ ] `resources/clothes/mochila.tres` usa `container_model` (propiedad eliminada);
        la vigente es `container_capability`
  - [ ] `PlayerCarriedInventories.take_ammo()` muta `descriptor.rounds`, que es un
        `Resource` compartido
  - [ ] `PlayerNeeds.heal()` no tiene rama `HEALTH` pero `arm_states/consuming.gd:35` la invoca
  - [ ] `inventory_ui_controller.gd:72` y `:223` leen `descriptor.quick_slots`, que solo
        existe en `WearableItemDescriptor` (error de tipo estático en GDScript)
  - [ ] ~~`item_inventory.gd` (sistema `Item` legacy)~~ — resuelto: el script se eliminó
        en la reorganización (T-001)

- [ ] **T-003 `README.md` desactualizado**: documenta el inventario, la jerarquía de
      descriptores, la IA de zombi y el melee tal como estaban antes de D-001.

- [ ] **T-004 Clave SSH privada commiteada**: `key` y `key.pub` en la raíz del repo.
      Sacarlas del control de versiones y añadir al `.gitignore`.

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

## Hecho

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
- Avisos `FBX: ufbx warning ... Duplicate connection to 128`: vienen de los `.fbx` originales
  (`bate.fbx`, `glock.fbx`, `machete.fbx`, `cuchillo.fbx`), no de la reorganización.

### Herramientas de diagnóstico (fuera del repo, en `/tmp/opencode/`)

- `check_tscn_connections.py` — analiza todos los `.tscn` y lista las conexiones de señal
  cuyo handler no existe en el script destino (resuelve escenas instanciadas).
  Uso: `python3 /tmp/opencode/check_tscn_connections.py`
- `probe_runtime.gd` / `probe_runtime2.gd` / `probe_runtime3.gd` — sondas headless que
  montan la escena del jugador en un árbol vivo e inspeccionan propiedades y conexiones
  reales. Uso: `godot --headless --path . --script /tmp/opencode/probe_runtime3.gd`
  (los autoloads **sí** están disponibles en este modo).

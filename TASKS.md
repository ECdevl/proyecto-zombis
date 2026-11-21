# TASKS.md — Tareas pendientes

## En curso

- [ ] **Fase crítica de mitigación de bugs del abuse (2026-11-10)** — aprobada por el Señor
  tras el reporte de bugs del prototipo jugable
  - [x] Bloqueo de input por motivo (muerte/agarrado/inventario) en `player.gd`
  - [x] Muerte una sola vez (`HealthComponent`) + curación `HEALTH` en `PlayerNeeds`
  - [x] Inventario modal/lazy: sin movimiento/ataque al jugador mientras está abierto
  - [x] HUD de munición con arma válida (`Weapon`) y actualización en `UI`
  - [x] Quick slot no resucita items huérfanos
  - [x] Segundo zombi: ataca en vez de agarrar a un jugador ya agarrado
  - [x] Guards de estado zombie (`idle`, `recover`, `stun`, `grab`) tras `await`/muerte del jugador
  - [x] ViewPunch restaura cámara original (`WeaponPivot`) tras escape
  - [x] Lean: reset en aire/muerto/agarrado, liberar uno no cancela el otro, clamp pared
  - [x] Estado `fall` del jugador + transiciones coherentes
  - [x] Melee con `WORLD_MASK | HITBOX_MASK` (paredes cortan)
  - [x] WeaponController input/death/reload/shoot/swing guards + revalidación post-`await`
  - [x] Recarga: aborta si cambia estado/arma, jugador muere o se bloquea
  - [x] Puerta `MOVE`: no abre si `direction` es cero; `rot_amount` ya no se muta en checks
  - [x] Iconos en headless: se omite generación para evitar bloqueo por `frame_post_draw`
  - [x] Boot headless sin errores de `IconCreator`
  - [x] Ícono manual por descriptor (`ItemDescriptor.icon`) con respaldo automático (`get_icon()`), UI migrada (D-027)
  - [x] Estudio `IconCreator` `@tool` con SubViewport, botón de captura, guardado `.res`/`.tres` y asignación opcional al descriptor; respaldo automático separado en `icon_creator_auto.tscn` (D-028)
  - [x] Linterna: el brazo izquierdo levantado se ancla al esqueleto visible del viewmodel y se mantiene con cualquier arma de una mano (E-024, D-029)
- [x] AnimationTree compartido en viewmodels: `ViewmodelAnimator` centraliza base (idle/run), one-shots (draw/shoot/swing/reload/punch) y capas contextuales filtradas al brazo izquierdo; migrado `weapon_controller` y `run.gd`; animación contextual `ctx_flashlight` generada una sola vez y reutilizada en todos los viewmodels (D-030)
  - [ ] Autoría de nuevas animaciones contextuales: añadir clips `ctx_*.tres` con pistas `rig/Skeleton3D:...` y registrarlos en `ViewmodelAnimator`.
  - [ ] Sigue probando en runtime con `tools/probe_abuse.tscn` para casos residuales (swap de arma en recarga, muerte durante agarre/zombie, ejecución melee, etc.)

- [ ] **T-018 Viñeta de pantalla para poca vida / muerte** (2026-11-10, D-026)
  - [x] `materials/vignette.gdshader` + `materials/vignette.tres`: canvas_item
        con `intensity`, `inner_radius`, `softness`, `screen_tint`,
        `pulse_speed`, `pulse_strength` y `vignette_color`
  - [x] Compilado en Forward Mobile (Vulkan) en una escena temporal, sin errores;
        captura con `intensity = 1`: centro intacto, bordes rojos y esquinas
        al máximo
  - [ ] Integrar en `scenes/ui/ui.tscn` como ColorRect a pantalla completa
        (por encima del HUD, `mouse_filter = 2`) y manejar `intensity` según
        `player.health_component`; decidir si reemplaza a `hurt_flash`
  - [ ] Afinar en juego: umbral de aparición, latido y tinte de muerte

- [ ] **T-015 Movimiento del zombi: andar hacia adelante y girar el cuerpo**
      (2026-11-06, D-018)
  - [x] `chase`: se mantiene el andar solo hacia adelante (-Z) y el giro
        limitado a `turn_speed_deg` (90°/s) únicamente mientras camina; parado
        no pivota; `stop = false` al entrar
  - [x] Sin snap de mirada: `idle` ya no apunta `%LookHead` al jugador;
        `chase.enter/exit` limpian `target_node` e `influence = 0`; la cabeza
        queda solidaria al cuerpo
  - [x] Ataque solo de frente: `attack_angle_deg = 70` +
        `is_facing_target()`; dentro de `grab_range` pero fuera del cono,
        sigue caminando para girar
  - [x] `zombie.tscn`: `Nav.radius` 0.15 → 0.3 (los zombis se solapaban al
        andar en paralelo; E-018)
  - [x] `probe_turn` reparada (E-017) y ampliada a 14 aserciones →
        *RESULTADO: TODO OK*
  - [x] `probe_avoidance` con la métrica corregida (desvío contra
        `Nav.velocity`, no contra la recta al objetivo) → *TODO OK*
        (mín 0.62 m, desvío 0.823 vs 0.000 del control ciego)
  - [x] Regresión `probe_zombie` (7), `probe_melee` (14),
        `probe_hitdir` (9) → *TODO OK*
  - [ ] Probar en el juego: que un zombi al que se le aparece el jugador
        por detrás/sal lado camine y gire en vez de clavar la mirada;
        ajustar `turn_speed_deg` (90) y `attack_angle_deg` (70) desde el
        inspector si hace falta

- [ ] **T-014 Movimiento del jugador con inercia** (2026-11-05, D-017)
  - [x] `player_stats.gd`: `acceleration` 12, `deceleration` 25,
        `air_control` 0.5 (ajustables desde el inspector, grupo
        "Movement Feel")
  - [x] `player.gd`: contra-giro (dot(vel, dirección) < 0 → frena con
        `deceleration`) e impulso aéreo conservado (sin input en el aire
        no se toca la horizontal)
  - [x] `jump.gd`: al aterrizar `velocity.y = 0` (antes `Vector3.ZERO`
        borraba la inercia horizontal del salto)
  - [x] Sonda nueva `tools/probe_movimiento.tscn` → *RESULTADO: TODO OK*
        (13 aserciones; ver D-017)
  - [ ] Probar en el juego: sensación de arranque, frenado y derrape;
        afinar 12/25/0.5 desde el inspector si hace falta

- [x] **T-013 Stagger izquierdo/derecho del zombi** (2026-11-05, D-016)
      (`stumble_left`/`stumble_right` del `zombie_rig.glb`)
  - [x] GLB reimportado con `godot --headless --path . --import`;
        `get_animation_list()` confirma `stumble_left`/`stumble_right`
  - [x] AnimationTree `zombie_sm` ampliado (2 nodos + 2 estados + 8
        transiciones, espejo de stumble_fwd/back); escena sigue válida
  - [x] Melee en cuerpo: `swing_x` del SwingData manda
        (>0 → stumble_right, <0 → stumble_left, ==0 → sin stagger)
  - [x] Empujón: descomposición zombie-local; lateral si |s| > |f|
  - [x] Sondas verdes: `probe_melee`, `probe_zombie`, `probe_hitdir`
        (esta última adaptada a `death.gd`, ver D-016)
  - [ ] Probar en el juego: empujón a izquierda/derecha y golpes melee;
        confirmar que el cuchillo (swing2, X = 0) no empuja

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

- [ ] **T-011 Rework de ragdoll (2026-11-04; constraints 2026-11-06, D-019)**
      Trabajo que no estaba documentado acá ni en `DECISIONES.md`:
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
  - [x] Quitar `Physical Bone root` (cuerpo libre de 0.875 m sin joint) de la
        escena base y de los overrides de `zombie.tscn` /
        `ragdoll_testing.tscn`; el pelvis queda como raíz libre.
  - [x] Repartir masa por segmento (total ≈70 kg), damping 0, bounce 0,
        friction 0.8/1.0 y límites anatómicos verificados contra los ejes
        reales y la convención de signo de Jolt (D-019).
  - [x] Sondas nuevas `probe_ragdoll_axes`, `probe_6dof_sign` y
        `probe_ragdoll_behavior`; esta última da *TODO OK* (estable, sin
        NaN ni joints separados).
  - [x] Damping del **cuerpo** con `DAMP_MODE_REPLACE` (D-020; Jolt ignora el
        damping del joint 6DOF): `angular_damp` 0.55 / `linear_damp` 0.08,
        torso 0.70 / 0.10 → *probe TODO OK* (estiramiento 0.256→0.044 al
        reposo).
  - [x] `ragdoll_debug.gd`: cámara libre estilo editor (clic derecho + WASD +
        rueda, funciona en pausa) e impulso dirigido al hueso seleccionado
        (eje/signo/magnitud) para ver el tope de los constraints (D-020).
  - [x] `ragdoll_debug.gd`: selector de huesos en la simulación (casillas por
        hueso + Todos/Ninguno/Reiniciar) que llama
        `physical_bones_start_simulation(names)` (D-021).
  - [x] **Bug "el ragdoll se va a la estratosfera" (2026-11-06, E-022/D-022)**:
        ascenso infinito corregido en `ragdoll_component.gd` (teletransporte
        del body y `velocity = Vector3.ZERO` solo si la pelvis simula); UI del
        selector con semántica de clausura de descendientes y checkbox
        "pelvis (raíz)"; huesos sin simular quedan fantasma (capa/máscara 0,
        `_ghost_unselected_bones()`); `_on_restart_simulation()` asienta 10
        frames antes de arrancar (el "golpe" del joint pasó de v≈280 a v≈1.7
        m/s); "pelvis marcada = ragdoll completo" es comportamiento del motor
        (sin API pública de selección exacta) y queda documentado en la UI.
        Sonda nueva `tools/probe_ragdoll_partial.gd` (A: todos menos pelvis;
        B: solo pelvis) → *RESULTADO: TODO OK*; `probe_ragdoll_behavior` →
        *TODO OK*.
  - [x] Subir el damping del cuerpo a `angular_damp` 0.90 / `linear_damp` 0.12,
        torso 1.10 / 0.14, y apretar hombros (x ±12, y ±15, z ±12) y manos
        (x ±45, y ±15, z ±30) y `spine` x lower −25 (D-021) → *probe TODO OK*
        (estiramiento máximo 0.251, antes 0.255).
  - [ ] Validación visual en el editor con `ragdoll_testing.tscn` /
        `RagdollDebug`: afinar hombros, caderas y pies si algún ángulo se ve
        antinatural; ajustar `linear_damp`/`angular_damp` con el panel si
        sigue habiendo temblor o flacidez.
  - [ ] Afinar `knockback`: `bate.tres` =500 da≈60 m/s de pelvis (¿excesivo?);
        probar en juego. Machete/cuchillo quedan en20 (default de
        `EquippableDescriptor`).
  - [ ] `check_tscn_connections.py`:3 conexiones rotas en
        `addons/ragdoll_wizard/ragdoll_wizard_panel.tscn`
        (`CreateButton`/`ClearSlotsButton`/`CopyBoneNameButton`) + la
        preexistente T-008. **Se mantiene en 4 tras el rework de zombis**
        (E-016: se restauró `_on_nav_target_reached()`).

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

- [ ] **T-016 Sangre: chorro en la herida + salpicaduras donde cae** (2026-11-06, D-023)
  - [x] `scripts/effects/blood_burst.gd` + `scenes/effects/blood_burst.tscn`: GPUParticles3D en
        espacio de mundo con gravedad (sin colisión por partícula), `local_coords = false`;
        `spray(pos, exit_dir, strength)` duplica el `ParticleProcessMaterial` (orientación y
        velocidad por chorro) y se libera con `finished`; tope 12 chorros vivos
  - [x] `zombie.gd`: `_exit_direction()` (impulse → atacante→herida → adelante del zombi) y
        `_blood_strength()` (cabeza 1.4/1.6, mortal 1.0/1.1, normal 0.6, roce 0.3, sin daño 0.4);
        `_spawn_blood()` lanza chorro + `BloodSplatter` (posición de impacto + proyección al piso)
  - [x] `blood_splatter.gd`: `splash(..., intensity)` escala radios/distancias/tamaños;
        `_ground_drop()` proyecta el aterrizaje por delante del chorro
  - [x] `game_manager.gd`: `blood_splatter()` redirigido al sistema nuevo (firma compatible)
  - [x] Sonda `tools/probe_blood.tscn` → *TODO OK* (8 aserciones: cabeza vmax 7.0 vs pierna 2.1,
        dirección dot 1.00, decals en piso 0.05 < chorro 1.90); regresión
        `probe_zombie`, `probe_melee`, `probe_hitdir` → *TODO OK*
  - [ ] Probar en el juego: que el chorro no nazca dentro del cuerpo y que la salpicadura
        del piso no quede eclipsada por el `visibility_aabb`; afinar `spread`/`gravity`/`amount`
        desde la escena si hace falta
  - [ ] Decidir si se borra `scenes/effects/blood.tscn` (legacy, sin referencias) o se conserva
        como variante

- [ ] **T-017 Bullet holes: en el cuerpo + icono placeholder en el mundo** (2026-11-06, D-024/D-025)
  - [x] En zombi: `Decal` hijo del `BoneAttachment` del hitbox (pega al cuerpo, sigue al
        hueso al moverse); en mundo: fijo con el icono de Godot como placeholder
  - [x] `projectile_resource.gd`: `_spawn_bullet_hole_on_bone()` (local = inversa del hueso
        * global deseado); mundo solo si collider es `StaticBody3D`; rayo excluye por RID
        todo `PickableItem` (E-023)
  - [x] `test.tscn`: pickups de capa 3/16 → capa 2 (causa raíz del bloqueio)
  - [x] Sonda `tools/probe_bullet_hole.tscn` → *TODO OK* (pegado al hueso, se mueve 5.00 m,
        icono en el mundo, atraviesa pickup en capa 1); `probe_blood` corregida a velocidad
        → *TODO OK*; regresión `probe_zombie`, `probe_melee`, `probe_hitdir` → *TODO OK*
  - [ ] Reemplazar `icon.svg` del mundo por la textura definitiva
  - [ ] Probar en el juego: distancias de desvanecido y solape con decals de sangre
  - [ ] Decidir si el agujero debe respetarse al pegar bolsas (`BloodSplatter._track`) con
        tope propio o sigue compartiendo vida útil

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
  - [x] ~~`PlayerNeeds.heal()` no tiene rama `HEALTH`~~ — DESACTUALIZADO:
        `player_needs.gd:29-34` sí contiene la rama `Needs.HEALTH` (revisado en D-039)
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

- [x] **Melee: el swing sobrevive a la cancelación y completa el golpe** (2026-11-21,
      E-050, corrección definitiva): `MeleeAttack.run()` comprueba `controller.is_active_operation(self)`
      tras el post-`await` y limpia la vista (`play_base idle`) en los caminos de cancelación
      o condiciones no cumplidas; la cancelación durante el swing ya no aborta el golpe (sin
      spawn de proyectil, sin audio ni daño) ni deja la animación colgada en `swing`. Sonda
      `tools/probe_melee_ataque` con swing limpio → *TODO OK*.

- [x] **Melee: sonidos de swing/hit reproducidos tras el rework con behaviours** (2026-11-21,
      E-050): `melee_projectile.gd` añade los `AudioStreamPlayer` al árbol antes de `play()`;
      `probe_melee` + `probe_melee_ataque` → *TODO OK*.

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
- `tools/probe_movimiento.tscn` + `tools/probe_movimiento.gd` — sonda del
  movimiento con inercia (D-017): monta un piso 200×200 (las pruebas acumulan
  ~25 m; con un piso chico el player cae por el borde) y un player real, y
  simula input con `Input.action_press`/`action_release`. Comprueba:
  aceleración (v = 1.2 a 0.1 s, 5.00 a 1 s), freno (v > 3.5 a 2 frames de
  soltar, se detiene solo en < 1 s, derrape integrado 0.3–0.8 m), sprint
  (8.00 en 1.5 s) y salto en carrera con impulso conservado (soltar todo en
  el aire mantiene la velocidad, aterriza y frena solo). La física corre a
  **120 Hz**: las esperas se calculan con `Engine.physics_ticks_per_second`.
  **Corre como escena.** Uso:
  `godot --headless --path . res://tools/probe_movimiento.tscn`
  → *RESULTADO: TODO OK*
- `tools/dump_engine_signals.gd` — genera `tools/engine_signals.py`: la tabla de señales que
  declara cada clase del motor usada en el proyecto. Se regenera solo si se agregan clases:
  `godot --headless --path . --script res://tools/dump_engine_signals.gd`

Nota: en modo `--script` los autoloads todavía no existen cuando se compila la cadena de
dependencias, así que aparecen errores de compilación falsos. Ver `ERRORES.md` E-004.

- [x] **T-019 Linterna desacoplada de `WeaponController`** (2026-11-17, D-031)
  - [x] `HoldableDescriptor` como base común de `EquippableDescriptor` y
        `FlashlightDescriptor`; se eliminan `get_hands_required()` / `get_actions()`
        duplicados y la linterna deja de ser candidata a arma principal
  - [x] `FlashlightController` extraído de `WeaponController` (~170 líneas menos):
        nodo hermano bajo el Player con `%FlashlightController`, dueño del toggle,
        del rig óseo y del modelo, suscrito a `hands.changed` y `weapon_changed`
  - [x] `SkeletonUtils` centraliza la normalización de huesos y la búsqueda del
        brazo izquierdo; se eliminan las copias en `ViewmodelAnimator` y en el
        viejo bloque de linterna
  - [x] Corregidos `caster_mask` sobrescrito, `_rig_skeleton` marcado sin
        attachment, `_flashlight_light` no nulificado al desmontar y toggle
        que ignoraba la mano derecha; parámetros de luz pasan a exports
  - [x] `tools/probe_linterna.gd`: 15 aserciones → *TODO OK* (jerarquía,
        existencia del controlador y toggle con la linterna en mano derecha)
  - [ ] Probar en juego: anclaje/pose del brazo izquierdo con cada viewmodel y
        encendido/apagado con la linterna en ambas manos

- [x] **T-020 Animación de la linterna con manos vacías** (2026-11-17, D-032)
  - [x] `ArmsAnimator` reutiliza el AnimationTree ya presente en `player.tscn`
        y se activa desde `Player._ready()`; se retiró `arms_ap.play("idle")`
  - [x] `FlashlightController` aplica `ctx_flashlight` al viewmodel y a armsy,
        con refresco diferido al arranque
  - [x] Migrados todos los `weapon_ap.play`/`play_backwards`/`queue` de
        `WeaponController` y los fallbacks de `run.gd` al AnimationTree
  - [x] Corregidos los `travel()` a estados inexistentes (`pistol_idle`, `Ledge`,
        `normal`) que el tree apagado hacía inofensivos (E-031 incluida)
  - [x] `tools/probe_linterna.gd`: 22 aserciones → *TODO OK* (armsy sin arma,
        viewmodel + armsy simultáneos, soltar arma y desequipar linterna)
  - [ ] Probar en juego la pose de armsy al soltar el arma y el one-shot de punch

- [x] **T-021 Cámara FPS anclada al hueso del cuello** (2026-11-17, D-033)
  - [x] `scripts/components/camera_rig.gd` (`NeckCameraRig`): copia la posición
        del `BoneAttachment3D` al espacio local de `Yaw`, compensa el `z` de
        `Pitch` y deja la rotación a `Yaw`/`Pitch`; `process_priority = 1`
  - [x] `scenes/player.tscn`: `CameraRig` insertado entre `Yaw` y `Pitch`, con
        `neck_attachment` enlazado por `node_paths`; reparentado `Pitch` y todos
        sus descendientes; corregidas las 6 `NodePath`, el `[editable path]` y
        las sondas que usaban la ruta antigua (E-033)
  - [x] `Player`: referencia `%CameraRig`, asserts actualizados y eliminados
        `CAM_HEIGHT_*`, `CAM_LERP_TIME` y `tween_cam_height()`
  - [x] `idle.gd`, `crouch.gd`, `prone.gd`: retirados los ajustes de altura
  - [x] `tools/probe_neck_cam.gd`: 18 comprobaciones → *TODO OK* (seguimiento en
        idle, con rotación, en crouch y al volver; rotación intacta)
  - [x] Sin regresiones en `probe_linterna.gd` (0 fallos) ni en
        `probe_abuse.tscn -- --case=lean`
  - [ ] Probar en juego el seguimiento con las animaciones nuevas de Mixamo
        (caminar, agacharse, saltar) y ajustar el hueso si el encuadre no agrada

- [x] **T-022 Ciclo día/noche desacoplado** (2026-11-18, D-034)
  - [x] `scripts/world/day_night_cycle.gd` (`DayNightCycle`): reloj continuo
        0..24, fases con duración real configurable, trayectoria del sol y de
        la luna, crepúsculos y API/señales públicas
  - [x] `scenes/environment/day_night_cycle.tscn`: `Node3D` raíz con
        `WorldEnvironment`, `Sun` y `Moon`; autocontenida, sin referencias externas
  - [x] Reescaneo de clases con `godot --headless --path . --editor --quit` (E-034)
  - [x] `tools/probe_dia_noche.gd`: 15 comprobaciones → *TODO OK*
  - [ ] Probar en juego la escena instanciada en `scenes/debug/test.tscn`:
        comprobar que el entorno propio no pelea con el `WorldEnvironment` de
        la escena, el cambio de luz al amanecer/atardecer y el cielo nocturno
  - [ ] Ajustar `day_start_hour`/`night_start_hour` y las duraciones al gusto
        del Señor (convención: cada hora de fase dura `span/duración` segundos)

- [x] **T-023 Skyboxes por hora en el ciclo día/noche** (2026-11-18, D-035)
  - [x] `scripts/world/day_night_cycle.gd`: exports de las tres texturas y de
        los umbrales `morning_sky_end_hour` / `night_sky_start_hour`; selección
        por rangos circulares y `BG_SKY` con respaldo `BG_COLOR`
  - [x] `scenes/environment/day_night_cycle.tscn`: texturas de mañana, tarde y
        noche enlazadas por UID, preservando el trabajo previo del Señor
  - [x] Corregido el override `env`: se aplica antes de `_apply_all()` (E-038)
  - [x] `tools/probe_dia_noche.gd`: 22 comprobaciones → *TODO OK* (7 nuevas de
        skybox + las 15 originales)
  - [ ] Probar en juego los tres skyboxes y ajustar los umbrales de cambio
        (ahora 12:00 y 19:00) al gusto del Señor

- [x] **T-024 Fundido continuo entre skyboxes** (2026-11-18, D-036)
  - [x] `shaders/sky_blend.gdshader`: `shader_type sky;` con dos panoramas y
        `sky_blend`, mezclados con `mix()` sobre `SKY_COORDS`
  - [x] `scenes/environment/day_night_cycle.tscn`: `ShaderMaterial` con
        `resource_local_to_scene` en material, Sky y Environment;
        `Sky.process_mode = 2`; export `sky_transition_hours = 1.0`
  - [x] `scripts/world/day_night_cycle.gd`: `_apply_sky()`, `_wrapped_offset()`,
        `_validate_sky_thresholds()` y respaldo a `BG_COLOR`
  - [x] Corregido E-039 (`;` en `shader_type`) y revalidado el editor headless
  - [x] `tools/probe_dia_noche.gd`: 27 comprobaciones → *TODO OK* (fundidos
        parciales a las 11:45 y 05:45)
  - [ ] Probar en juego los tres fundidos y ajustar `sky_transition_hours`
        al gusto del Señor

- [ ] **T-025 Escopeta: perdigones dispersos con daño dividido** (2026-11-19, D-037)
  - [x] `Projectile._camera_raycast()` separado en envoltorio + `_trace_ray()` sin
        `await` (un solo frame físico para toda la descarga)
  - [x] `ShotgunProjectile`: perdigón 0 siempre al centro, N−1 aleatorios en cono
        de ángulo sólido, `_damage_for()` = daño por perdigón en cualquier zona
  - [x] `Weapon.pellets_per_shot` / `pellet_spread_deg` como exports;
        `WeaponController.load_projectile(gun)` elige subclase solo para SHOTGUN
  - [x] `remington.tres`: 8 perdigones, 4° de semiángulo, 8 cartuchos iniciales
  - [x] Ejecutar `tools/probe_escopeta.tscn` → TODO OK (18 comprobaciones);
        corregida la sonda: `fire()` libera el proyectil, así que las direcciones
        se capturan en un Array externo y se comprueba el último hijo del holder
  - [ ] Probar en juego: ajustar `pellets_per_shot` / `pellet_spread_deg` desde
        el inspector y revisar el balance (50 total frente al 9999 de un headshot)
  - [ ] Al definir la tabla de daño por zona, revisar la excepción de
        `ShotgunProjectile._damage_for()` (D-037, punto 4)

- [ ] **T-026 Refactor de `WeaponController` — operaciones + behaviour inyectado** (2026-11-19, D-038)
  - [x] Respaldo `/tmp/opencode/weapon_refactor_backup_20261119_195213.tar.gz`
  - [x] Línea base de sondas capturada antes de editar (4 conexiones rotas preexistentes,
        2 errores de editor preexistentes, `Instructor`-only en modo `--script`)
  - [x] `Player.can_act()` como única fuente de verdad; usado en `normal.gd`,
        `aim.gd`, `consuming.gd` y `AttackOperation.is_valid()`
  - [x] `AttackOperation`/`AttackBehaviour` (`Resource`, `@abstract`) y subclases
        `FirearmAttack`, `MeleeAttack`, `ReloadOperation`, `FirearmBehaviour`,
        `ShotgunBehaviour`, `MeleeBehaviour`
  - [x] `ReloadOperation`: un solo `cancel()`, recarga escalonada no reentrante
  - [x] `WeaponController` reescrito: `attack()` central, wrappers `shoot()`/`swing()`,
        `load_projectile(gun)` delega en `gun.create_projectile()`
  - [x] Descriptores delegan en `behaviour`; `remington.tres` usa `ShotgunBehaviour`
  - [x] Corregido el orden `ext_resource` → `sub_resource` en `remington.tres`
        (`Can't load cached ext-resource id` → behaviour caía al default)
  - [x] Eliminados TODOS los comentarios de los archivos tocados; `:=` preexistentes
        corregidos a tipos explícitos en esos mismos archivos
  - [x] Editor reescaneado; `--quit`, `probe_escopeta`, `probe_melee`,
        `probe_linterna` (Fallos: 0), `probe_abuse --case=lean` y
        `check_tscn_connections.py` sin regresiones
  - [ ] Probar en juego: recarga escalonada, interrupción por muerte/agarre a mitad
        de `await`, y dispara/apuntar con arma nueva sin tocar el controlador
  - [ ] Revisar E-041 (knockback de melee anulado) — pendiente de autorización

- [ ] **T-027 Auditoría de sistemas y refactor quirúrgico** (2026-11-20, D-039)
  - [x] Auditoría de inventario, armas y movimiento; decisiones D-039 y
        hallazgos E-042..E-049 registrados
  - [x] E-042: `swing_index` declarado en `WeaponController` y `MeleeAttack.run()`
        ejercitado por `tools/probe_refactor_d038_fixes.tscn`
  - [x] E-043: `is_active_operation()` y guards de identidad en
        `ReloadOperation`; carrera A/B verificada en la misma sonda
  - [x] Sonda nueva: 9/9 comprobaciones; `probe_escopeta` y `probe_melee` sin
        regresiones; `check_tscn_connections.py` = 4 rotas preexistentes
  - [x] TASKS.md:259 corregido: `PlayerNeeds.heal()` sí tiene rama `HEALTH`
  - [ ] E-044: estado de munición/cargador fuera de los descriptores compartidos
  - [ ] E-045: devolver `quick_slots` a `InventoryUIController`
  - [ ] E-046: corregir `mochila.tres` a `container_capability`
  - [ ] E-047: pasar el descriptor correcto a `update_inventory_ammo`; quitar
        la llamada muerta a `ensure_item_mesh()`
  - [ ] E-048: transición `jump` → `walk` al aterrizar en movimiento
  - [ ] E-049: tabla de daño por zona y revisar la excepción de escopeta
  - [ ] Revisar E-041 (knockback de melee) con autorización del Señor
  - [ ] Probar en juego: combo melee, interrupción de recarga y recarga escalonada

- [ ] **T-028 Sonidos de pasos por la fase del sway** (2026-11-20, D-040)
  - [x] `ViewmodelSway` emite `footstep` al cruzar `fmod(bob_time, PI)`, también sin arma
  - [x] `FootstepPlayer` con `AudioStreamPlayer` propio; no comparte el reproductor del arma
  - [x] `resources/footsteps_stone.tres`: randomizer de los cuatro `Footstep Stone *.ogg`
  - [x] Conexión en `player.tscn` y `:=` corregidos en `viewmodel_sway.gd`
  - [x] `tools/probe_pasos.gd` → *TODO OK* (7 comprobaciones); sin regresiones en
        `probe_linterna`, `probe_abuse --case=lean` ni `check_tscn_connections.py`
  - [ ] Probar en juego: cadencia de caminar/correr y volumen del randomizer
  - [ ] Corregir `run.gd:15`: `play_audio(run_sounds)` se reinicia en cada `update()`
  - [ ] Decidir si los pasos deben seguir sonando al apuntar (hoy se inhiben con ADS, E-027)

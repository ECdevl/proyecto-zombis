# Zombis — Documentación técnica

Godot 4.7. Shooter/survival zombie en primera persona, estilo Project Zomboid con feel de Tarkov/Unturned.

Este documento explica **cómo está armado el código**, no las mecánicas de diseño en sí. Para cada sistema hay un flujo paso a paso pensado para que cualquiera (vos, otra IA, otro dev) pueda entender dónde tocar sin romper la arquitectura.

---

## Principios generales del proyecto

- **Sin autoloads salvo excepciones puntuales.** Comunicación entre nodos vía `%NombreUnico` (unique names) o señales. Autoloads actuales: `GameManager` (efectos globales tipo sangre) e `IconCreator` (renderiza ícono de un mesh a textura).
- **Composición sobre herencia** en los ítems del inventario: las "capabilities" (`ContainerCapability`, etc.) son campos `@export` opcionales en el Resource, no subclases.
- **Separación estricta de capas** en el inventario: Descriptor (dato estático) → Model (dato dinámico, sin nodos) → View (nodos visuales) → Controller (orquesta múltiples Views). Ver sección dedicada.
- **State Machine por nodos** (patrón de *Game Programming Patterns*, Robert Nystrom): cada estado es un `Node` hijo de un `StateMachine`, con nombre = nombre del estado. Se usa tanto para movimiento del jugador como para los brazos/arma.

---

## Estructura de carpetas

```
scripts/
  core/            → player.gd, game_manager.gd (autoload)
  components/      → Resources reutilizables (salud, stats, necesidades, ítems "legacy")
  inventory/
    descriptors/   → ItemDescriptor y subclases (dato estático de cada tipo de ítem)
    model/         → InventoryModel (grilla, sin nodos)
    view/          → InventoryView + ItemVisual (nodos visuales, drag & drop)
    controller/    → InventoryUIController (abre/cierra paneles)
    ui/            → HUD, tooltip, equipo puesto, contenedores que carga el jugador
  state_machine/
    core/          → State, StateMachine, run.gd
    player_states/ → idle, walk, crouch, prone, climb, hang, jump (movimiento del cuerpo)
    arm_states/    → idle, aim, consuming, inventory (qué hacen los brazos/arma)
  weapons/         → weapon_controller.gd (disparo/recarga/melee), viewmodel_sway.gd, muzzle_flash.gd
  world/           → container_interactable.gd (cofres/contenedores del mundo)
  zombie/          → zombie.gd
scenes/            → misma organización por dominio que scripts/
resources/         → instancias .tres de descriptors, armas, ropa, consumibles
```

---

## Sistema de Inventario (Descriptor / Model / View / Controller)

Es el sistema más maduro del proyecto. Cuatro capas, cada una con una responsabilidad y nada más:

| Capa | Script | Qué es | Qué NO hace |
|---|---|---|---|
| Descriptor | `scripts/inventory/descriptors/*.gd` | `Resource` estático, uno por *tipo* de ítem (ej: "Machete"). Se comparte entre instancias iguales — no representa una copia física en el mundo. | No guarda posición, no sabe si está en un grid. |
| Model | `scripts/inventory/model/inventory_model.gd` | `Resource` con la grilla (`Array[Array[ItemDescriptor]]`) de un contenedor concreto (la mochila del jugador, un cofre). Emite señales cuando cambia. | Cero referencias a nodos de escena. |
| View | `scripts/inventory/view/inventory_view.gd` + `item_inventory_visual.gd` | `GridContainer` que escucha las señales del Model y crea/mueve/destruye los `ItemVisual` (drag & drop, rotación, preview de color). Única responsable de instanciar nodos visuales de ítems. | No modifica el Model directamente salvo a través de sus métodos públicos (`try_place`, `remove_item`). |
| Controller | `scripts/inventory/controller/inventory_ui_controller.gd` | Abre y cierra paneles de inventario (el propio del jugador y los de loot), uno por Model activo. | No sabe de grillas ni de drag & drop, solo instancia/destruye paneles. |

### `ItemDescriptor` — jerarquía actual

```
ItemDescriptor (abstract)
├── MiscItemDescriptor        → lore_text, sin comportamiento especial
├── ConsumableItemDescriptor  → efecto (comer/beber/curar), duración
└── WearableItemDescriptor    → slot de equipo, armadura, puede contener un InventoryModel (mochilas)
```

Campos comunes en `ItemDescriptor`: `item_name`, `icon`, `weight`, `max_stack`, `dimensions` (tamaño en grilla), `item_mesh`, y `container_capability` opcional (si el ítem en sí es un contenedor tipo caja/lata, no lo confundas con `WearableItemDescriptor.container_model` que es para ropa que lleva mochila incorporada).

### Flujo: añadir un ítem al inventario

1. Alguien llama `InventoryModel.add_item_by_descriptor(descriptor)` (busca hueco libre automáticamente) o `try_place(descriptor, row, col, rotated)` (posición explícita, usado en el drag & drop).
2. Si hay espacio, el Model escribe el descriptor en las celdas del `grid` y emite `item_placed(descriptor, row, col, rotated)`.
3. La `InventoryView` que esté escuchando ese Model recibe la señal en `_on_item_placed`, crea (si no existe) un `ItemVisual` vía `_spawn_visual`, y lo posiciona en pantalla.
4. Si el jugador levanta un objeto pickeable del mundo (`PickableItem`), el flujo real pasa por `PlayerCarriedInventories.try_add_anywhere(item)`, que recorre todos los contenedores que el jugador tiene registrados y llama `add_item_by_descriptor` en el primero que tenga hueco.

### Flujo: quitar un ítem del inventario

1. `InventoryModel.remove_item(descriptor)` limpia las celdas donde estaba y emite `item_removed(descriptor)`.
2. La View recibe la señal pero **no destruye el nodo visual automáticamente** — solo limpia el preview de color. Esto es intencional: al arrastrar un ítem, `ItemVisual.start_drag()` ya llama `remove_item` para sacarlo del Model mientras sigue "vivo" en pantalla siendo arrastrado.
3. La destrucción real del `ItemVisual` ocurre en `ItemVisual.end_drag()` cuando el drop es válido en *otra* view distinta a la de origen, o queda flotando esperando un nuevo `try_place` si el drop fue inválido (vuelve a su posición original).

### Flujo: drag & drop entre contenedores (mochila del jugador ↔ cofre del mundo)

1. Click izquierdo sobre un `ItemVisual` → `start_drag()`: guarda posición/rotación original, saca el ítem del Model de origen (`view.remove_item(self)`), pero el nodo visual sigue existiendo y sigue al mouse.
2. Mientras se arrastra, `ItemVisual._input` busca con `InventoryView.find_at(mouse_pos, tree)` qué view (grupo `"drop_targets"`) está bajo el cursor, y le pide que dibuje el preview verde/rojo (`update_preview`).
3. Al soltar el mouse (`end_drag`), se intenta `try_place` en la view bajo el cursor. Si es una view distinta a la original, el nodo se reparenta (`item_layer.add_child`) y pasa a pertenecer a esa view.
4. Si el drop falla (fuera de grilla, choque con otro ítem), se restaura la posición/rotación original en el Model de origen.

### Contenedores que el jugador lleva encima

`PlayerCarriedInventories` (bajo `scripts/inventory/ui/`) mantiene la lista de `InventoryModel` que el jugador tiene disponibles en ese momento (bolsillos + mochila puesta). Cuando se equipa una prenda con `container_model` (ej: una mochila), `UI._on_equipment_item_equipped` la registra ahí; al desequiparla se desregistra y, si tiene ítems adentro, se intenta reubicarlos en otro contenedor antes de tirarlos al piso.

### ⚠️ Duplicación conocida: sistema `Item` viejo

Existe una clase paralela `Item` (`scripts/components/item_inventory.gd`, `Resource` con `get_actions()`) de la que heredan `Weapon`, `ItemCloth`, `ItemAmmo`, `ItemConsumable` (en `scripts/components/`). Este es un sistema de inventario **anterior** al Descriptor/Model/View actual, y todavía lo usa `weapon_controller.gd` para buscar munición en `player.inventory_manager.containers_available` — una propiedad que **no existe** en `player.gd` actualmente (referencia rota, WIP). No mezclar: los nuevos ítems deberían modelarse como `ItemDescriptor` (o subclase), no como `Item`. Migrar armas/ropa/consumibles/munición al sistema de Descriptors es trabajo pendiente.

---

## State Machine (movimiento y brazos)

Dos `StateMachine` separadas corren en paralelo dentro de `player.tscn` (accesibles vía `%StateMachine` y `%ArmsFSM`):

- **StateMachine de cuerpo** (`player_states/`): `idle`, `walk`, `run` (en `state_machine/core/run.gd`), `crouch`, `prone`, `climb`, `hang`, `jump`. Controla velocidad, altura de colisión/cámara y transiciones según input.
- **StateMachine de brazos** (`arm_states/`): `idle` (maneja ataques M1/M2, recarga, equipar arma nueva vía `_on_player_weapon_changed`), `aim`, `consuming` (animación de comer/beber), `inventory`.

### Cómo funciona una `State`

Cada `State` (`scripts/state_machine/core/state.gd`) tiene 4 métodos virtuales que la `StateMachine` llama automáticamente: `enter`, `exit`, `update` (cada frame), `physics_update` (cada tick de física), y `handle_input` (input no manejado). Para transicionar, el estado emite `finished.emit("nombre_del_siguiente_estado")` — la `StateMachine` busca un hijo con ese nombre y hace `exit` → `enter`.

### Añadir un estado nuevo

1. Crear script que `extends State`.
2. Instanciarlo como `Node` hijo del `StateMachine` correspondiente en la escena, con el `name` exacto que vas a usar en los `finished.emit(...)`.
3. Implementar solo los métodos que necesites (`enter`/`exit`/`update`/`physics_update`/`handle_input`); el resto ya vienen vacíos en la clase base.

---

## Armas y combate

`weapon_controller.gd` centraliza **toda** la lógica de gameplay del arma equipada (disparo por raycast, munición, recarga, recoil). Los estados (`arm_states/idle.gd`, `aim.gd`) nunca calculan esto por su cuenta: solo llaman a `weapon_controller.shoot()` / `.swing()` / `.reload()`.

- **Fuego**: raycast desde la cámara, con multiplicador de daño a la cabeza (`headshot_multiplier`). Detecta zombies por `hit.owner is Zombie`.
- **Melee**: usa `MeleeHitbox` (`ShapeCast3D`) activado por Call Method Tracks en el `AnimationPlayer` del viewmodel (`start_attack()` / `stop_attack()`), definido en `scenes/components/melee_hitbox.tscn`.
- **Recoil**: cinemático (rota pitch/yaw de cámara) + visual (offset del ADS), ambos se recuperan solos con `recoil_recovery_speed`.
- **Sway del viewmodel**: `viewmodel_sway.gd`, nodo separado y desacoplado del arma en sí, usa `event.screen_relative` para el sway por mouse y consulta el estado de las dos FSM (cuerpo + brazos) para el bobbing al caminar/correr.

---

## Zombies

`zombie.gd` es mínimo por ahora: `HealthComponent` propio (duplicado en `_ready` para no compartir estado entre instancias — **regla general**: cualquier Resource compartido en un `.tres` sin `.duplicate()` va a mutar en todas las instancias por igual), y un `PhysicalBoneSimulator3D` (ragdoll) que arranca la simulación física al morir o si `ragdoll_text` está activo (para debug).

---

## Estado de las mecánicas del GDD

Leyenda: ✅ implementado — 🟡 parcial/base — ⬜ WIP (no encontrado en el código)

### Mecánicas del jugador

| Mecánica | Estado | Notas |
|---|---|---|
| Caminar | ✅ | `player_states/walk.gd` |
| Correr | ✅ | `state_machine/core/run.gd` |
| Saltar | ✅ | `player_states/jump.gd` |
| Agacharse | ✅ | `player_states/crouch.gd` |
| Trepar | ✅ | `player_states/climb.gd` + `hang.gd` (detección de saliente vía raycasts en `arm_states/idle.gd`) |
| Cuerpo a tierra | ✅ | `player_states/prone.gd` |
| Inventario | ✅ | Sistema Descriptor/Model/View/Controller (ver arriba). Grid con rotación y drag & drop. |
| Armas melee | ✅ | `weapon_controller.swing()` + `MeleeHitbox` |
| Armas de fuego | ✅ | `weapon_controller.shoot()`, recarga, recoil, munición |
| Ejecuciones | ⬜ | No encontrado |
| Necesidades | 🟡 | `PlayerNeeds` (stamina, hambre, sed, sueño) existe y se refleja en el HUD, pero no vi decaimiento automático por tiempo (`_process`) ni penalizaciones por estar en 0 |
| Construcción | ⬜ | No encontrado |
| Cordura | ⬜ | No encontrado |
| Estadísticas | 🟡 | `PlayerStats` solo tiene `base_carry_weight` y `base_speed` por ahora |
| Habilidades | ⬜ | No encontrado |
| Sistema de niveles | ⬜ | No encontrado |
| Daño por partes del cuerpo | 🟡 | Hay multiplicador de headshot en el raycast de disparo, pero no un sistema genérico de partes del cuerpo con sus propios modificadores |

### Economía del juego

| Recurso | Estado | Notas |
|---|---|---|
| Comida perecedera / no perecedera | 🟡 | `ConsumableItemDescriptor` genérico (EAT/DRINK/HEAL), sin distinción de perecedera vs no |
| Agua | ✅ | `resources/consumables/agua.tres`, `water_bottle.tres` |
| Munición | 🟡 | `ItemAmmo` existe pero pertenece al sistema `Item` viejo, no migrado a `ItemDescriptor` |
| Armas de fuego | ✅ | Glock, Desert Eagle (`resources/weapons/firearm/`) |
| Armas melee | ✅ | Bate, Machete (`resources/weapons/melee/`) |
| Ropa | ✅ | Mochila, pantalones, remera, zapatillas (`resources/clothes/`) |
| Arrojables | ⬜ | No encontrado |
| Recargables | ⬜ | No encontrado (más allá de recarga de munición de arma) |
| Luz (linternas, etc.) | ⬜ | No encontrado |
| Medicamentos | 🟡 | Cubierto parcialmente por `ConsumableItemDescriptor` tipo HEAL, sin ítems específicos aún |
| Primeros auxilios | ⬜ | No encontrado |
| Vehículos | ⬜ | No encontrado |

### IA

| Sistema | Estado | Notas |
|---|---|---|
| Zombie común (movimiento/ataque básico) | 🟡 | Solo hay `HealthComponent` + ragdoll; sin `NavigationAgent3D`, detección ni ataque implementados |
| Sistema de hordas | ⬜ | No encontrado |
| Detección de estímulos (oído/vista) | ⬜ | No encontrado |
| Migración de horda | ⬜ | No encontrado |
| Zombies especiales (memoria, sensibilidad) | ⬜ | No encontrado |
| NPCs (comerciantes, saqueadores, víctimas) | ⬜ | No encontrado |

### Condiciones de victoria/derrota

| Condición | Estado | Notas |
|---|---|---|
| Sobrevivir (victoria) | ⬜ | No encontrado |
| Morir (derrota) | 🟡 | `HealthComponent.death` se emite en 0 HP, pero no vi manejo de game over en `player.gd` |
| Ser infectado (derrota) | ⬜ | No encontrado |

---

## Convenciones a mantener

- Nuevos tipos de ítem del inventario → subclase de `ItemDescriptor`, nunca del `Item` viejo.
- Nuevos estados de movimiento/brazos → heredar de `State`, agregarlos como hijo nombrado del `StateMachine` correspondiente.
- Nada de autoloads nuevos salvo que sea estrictamente global (efectos, managers de juego); preferir `%unique_name` o señales.
- Capabilities de ítems (contenedor, líquido, etc.) → campos `@export` opcionales en el Resource, no herencia nueva.

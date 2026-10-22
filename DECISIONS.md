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

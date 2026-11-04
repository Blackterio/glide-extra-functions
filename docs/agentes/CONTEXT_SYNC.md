# CONTEXT_SYNC — Blackterio's Glide Extra Functions

## Qué es
Librería GLua para vehículos Glide (animaciones, tablero, cartel de destino, limitador, clicks en interruptores) que los vehículos de Blackterio cargan opcionalmente.

## Estado
FULL_REINDEX: false
ULTIMA_ACTUALIZACION: 2026-11-04 — claude

## Estado por dominio
| Dominio | Servicio(s) | Estado | Pendiente |
|---|---|---|---|
| Cartel de destino | `DrawDestinationSign`, `AddEditableVars` | Completo | — |
| Controles, animaciones, limitador | `lua/glide/autoload/*` | Completo | — |
| Documentación y ejemplo | `Add support to your vehicle.md`, `examples/` | Completo | — |

## Decisiones de arquitectura vigentes
- Extra Functions es opcional: los vehículos chequean `BlackterioExtraFunctions` y declaran los mismos NetworkVar en la rama `else` — para no romper el spawn sin el addon.
- Varios renglones del destino se separan con `|` — Edit Properties no admite saltos de línea.
- El color del cartel se elige siempre desde Edit Properties; sin elegir, usa `destinationSignColor` (ámbar) — así los vehículos existentes no cambian.

## Historial
<!-- Máximo 10 entradas. Al agregar la 11, mover la más vieja al inicio de CONTEXT_SYNC_HISTORY.md -->
### 2026-11-04 — v110426: color editable del cartel de destino (M)
- `lua/autorun/shared/blackterio_extra_functions.lua` — `AddEditableVars` agrega `DestinationColor` (Vector, `VectorColor`, orden +3) con `destinationText`; `DrawDestinationSign` lo usa para destino y número (0,0,0 = ámbar de la config)
- `Add support to your vehicle.md`, `examples/example_full_vehicle.lua` — documentado, rama sin Extra Functions con el Vector
- Tronador II (ma15) — Vector en la rama sin Extra Functions. Probado en vivo: verde, vuelve al ámbar con (0,0,0), Edit Properties lista Destino, Línea y Color
- Se agregó el seguimiento agent-system (`AGENTS.md`, `CLAUDE.md`, `docs/agentes/`, `agentes/`)
- Sin commit (pendiente de tu permiso)
### 2026-11-04 — v110426: cartel de destino con fondo transparente, línea y varios renglones (M)
- `lua/autorun/shared/blackterio_extra_functions.lua` — `destinationSignShowBackground`, número de línea (`destinationLine`), renglones con `|`, `VERSION` 261104
- `Add support to your vehicle.md`, `README.md`, `examples/example_full_vehicle.lua` — documentado
- Tronador II (ma15) — `destinationLine = true`. Probado en vivo: línea, 2 renglones, fondo y marquee
- Bug corregido: `cam.PushModelMatrix(m, true)` dentro de 3D2D
- Sin commit (pendiente de tu permiso)

# Blackterio's Glide Extra Functions
Addon de Garry's Mod (GLua) que agrega funciones extra a los vehículos Glide: pedales, tablero, puertas, cartel de destino, limitador, clicks en interruptores. La librería es `lua/autorun/shared/blackterio_extra_functions.lua`; los loaders están en `lua/glide/autoload/`.

## Comandos
- No hay build ni tests. Se prueba en el juego con el MCP de GMod (`gmod_status` primero).
- Este repo NO es el addon que carga el juego. El que carga es `GarrysMod/garrysmod/addons/Blackterio's Glide Extra Functions`.
- Vehículo de prueba: `blackterios_glide_metalpar_tronador_ii_ma15` (addon `Metalpar Tronador II REMAKE`).

## Cómo trabajamos
- Antes de cada tarea: leer `docs/agentes/CONTEXT_SYNC.md` (y `agentes/HANDOFF_current.md` si hay una tarea a medias).
- Pipeline: ANALISIS → PLAN aprobado → EJECUCION → REVIEW. Nada de código sin plan aprobado.
- Cada paso del plan lleva `→ verificar:` con qué se ejecuta y qué se espera.
- Tamaño S/M/L decide el cierre (ver la skill `agent-system`).
- No asumas. Exponé la confusión. Escribí el mínimo código que resuelve el problema. Modificá solo lo necesario.
- Confirmar aparte, aunque esté en el plan: borrar archivos, `git commit`, `git push`.
- Textos y commits cortos y simples.

## Gotchas
- Después de editar `lua/`, `resource/` o `sound/`, copiarlos al addon instalado (ruta de arriba). Sin eso el juego nunca carga el cambio.
- Al editar la librería, subir `VERSION` (YYMMDD). Si no, la guarda de versión ignora el cambio en una partida abierta.
- Un NetworkVar nuevo solo existe en vehículos spawneados después de cargarlo: hay que respawnear.
- Los NetworkVar de la rama sin Extra Functions de cada vehículo van en el mismo orden que en `AddEditableVars`.
- Dentro de `cam.Start3D2D`, `cam.PushModelMatrix(m, true)`: sin el `true` se pierde la transformación del cartel.
- `SetupBones` y el dibujo solo existen en el cliente. `CompileString` sobre una copia en `garrysmod/data` sirve para chequear sintaxis (borrar la copia después).
- La versión se llama vMMDDYY (v102926) pero el código usa YYMMDD (261029).

## Al compactar
Preservar: plan aprobado con criterios, paso actual, archivos modificados y la regla de copiar al addon instalado.

---
name: web-work
description: Verificar e interactuar con la app web en un browser real usando agent-browser. Usar cuando haya que probar una feature de UI/SaaS, reproducir un flujo de usuario, sacar un screenshot, o confirmar que un cambio web funciona de verdad (no solo que compila).
---

# web-work — verificación web con agent-browser

Usás `agent-browser` (CLI) para tocar la app como un usuario y confirmar
comportamiento real. Detalle completo en `docs/agent-browser.md`.

## Precondiciones
- `agent-browser --version` responde. Si no: `npm install -g agent-browser && agent-browser install`.
- La app está corriendo (dev server). Si no, levantala primero.
- `.harness/config.json → agent_browser.enabled` es `true` (perfil saas-web).

## Procedimiento
1. `agent-browser open <url>` — navegá a la pantalla relevante.
2. `agent-browser snapshot -i` — obtené el árbol accesible con refs (@e1, @e2…).
3. Interactuá por ref: `agent-browser click @e2`, `agent-browser fill @e3 "<texto>"`.
4. **Re-snapshot** después de cada cambio de página/estado (los refs cambian).
5. Afirmá el resultado esperado (texto, estado, request de red con `agent-browser network`).
6. `agent-browser screenshot <ruta>` como evidencia.

## Reglas
- Trabajá por **refs del snapshot**, no por coordenadas.
- Tras navegar o cambiar estado, **siempre** re-snapshot antes de interactuar.
- Reportá en el handoff/review exactamente qué flujo verificaste y el resultado.
- Para inspección de componentes React / web vitals / red, ver perfiles MCP y
  comandos avanzados en `docs/agent-browser.md`.

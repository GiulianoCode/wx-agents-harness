# agent-browser — el agente toca/prueba la web él mismo

[agent-browser](https://github.com/vercel-labs/agent-browser) es un CLI nativo
(Rust + Chrome DevTools Protocol) que le da al agente control real de un browser:
navegar, click, fill, screenshots, snapshots de accesibilidad con refs deterministas,
inspección de red, etc. Ideal para verificar features de SaaS web sin intervención humana.

## Instalación (una vez por máquina)

```bash
npm install -g agent-browser      # o: brew install agent-browser / cargo install agent-browser
agent-browser install             # baja Chrome for Testing
```

Verificá: `agent-browser --version`.

> En este harness está habilitado por defecto en el perfil `saas-web`
> (`.harness/config.json → agent_browser`). Si trabajás en un proyecto no-web,
> el onboarding lo deja deshabilitado.

## Flujo recomendado (refs)

```bash
agent-browser open http://localhost:3000     # 1. navegar
agent-browser snapshot -i                    # 2. árbol accesible con refs (@e1, @e2…)
agent-browser click @e2                       # 3. interactuar por ref
agent-browser fill @e3 "hola@test.com"
agent-browser snapshot -i                    # 4. re-snapshot tras cambios de página
agent-browser screenshot /tmp/after.png       # evidencia visual
```

Salida estructurada con `--json`. Otras capacidades: `eval` (JS), `network`/HAR,
cookies/storage, auth state persistente, web vitals, PDF export.

## Integraciones

- **CLI** (lo de arriba) — el modo por defecto en este harness (`agent_browser.mode: "cli"`).
- **Skill** — `npx skills add vercel-labs/agent-browser` (registra la skill oficial
  para Claude Code). Este repo además trae una skill local `web-work` que envuelve el
  patrón de verificación visual.
- **MCP** — `agent-browser mcp` levanta un MCP server (perfiles: core, network, state,
  debug, tabs, react, mobile, all). Útil si preferís tools MCP en vez del CLI.

## Patrón de verificación de una feature web

1. Levantá la app (dev server).
2. `open` la URL de la feature, `snapshot -i`.
3. Reproducí el flujo del usuario (click/fill/navegación) según los requirements.
4. Afirmá el resultado esperado (texto en pantalla, estado, request de red).
5. `screenshot` como evidencia y anotá en el handoff/review qué se verificó.

Se complementa con la skill `verify` de Claude Code (validación de cambios corriendo
la app de verdad).

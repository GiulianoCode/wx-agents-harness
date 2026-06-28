# Arquitectura del harness

Dos capas: el **harness** (cómo trabaja el agente) y el **proyecto** (la app que se
construye encima). Esta doc describe el harness; la arquitectura de la app se
documenta acá tras el onboarding.

## Capa harness

```
.harness/            cerebro agnóstico de agente
  config.json        config única: perfil, umbrales de rate limit, handoff
  bin/               usage.sh · usage-codex.sh · handoff-template.md
  profiles/          perfiles de onboarding (saas-web, api-service, cli, library)

.claude/             leverage específico de Claude
  settings.json      hooks (rate limit + resume) + permisos
  hooks/             prompt-usage · ratelimit-guard · session-resume · _common
  commands/          /onboard /spec /handoff /verify
  agents/            spec-author · implementer · reviewer
  skills/            web-work (agent-browser), etc.

specs/<id>/          requirements · design · tasks   (SDD)
progress/            current.md (handoff vivo) · history.md
feature_list.json    scope: features y estado
init.sh              verificación
docs/                esta carpeta
```

Contratos canónicos compartidos (Claude + Codex): `AGENTS.md`. Claude lee además
`CLAUDE.md` (que importa `AGENTS.md`).

## Flujos

- **SDD**: `docs/specs.md`.
- **Rate limit + handoff**: `docs/rate-limit-handoff.md`.
- **Web / agent-browser**: `docs/agent-browser.md`.
- **Verificación**: `docs/verification.md`.

## Capa proyecto (completar tras `/onboard`)

- Stack: <…>
- Estructura de carpetas de la app: <…>
- Comando de verificación: `.harness/config.json → project.verify_cmd`

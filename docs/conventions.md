# Convenciones

## Código
- Escribí código que se lea como el que lo rodea: imitá naming, densidad de
  comentarios e idioms del archivo/módulo donde trabajás.
- Cambios chicos y atómicos, alineados a los tasks de la spec.
- No introduzcas dependencias nuevas sin registrarlo en `design.md`.

## Commits (cuando el usuario los pida)
- Mensajes en imperativo, foco en el "por qué".
- Un commit por unidad lógica de trabajo (idealmente por task o grupo de tasks).

## Archivos del harness
- `feature_list.json`: kebab-case para `id`. Una feature `in_progress` a la vez.
- `progress/current.md`: siempre refleja el estado real; `status: done` si no hay
  trabajo abierto.
- `progress/history.md`: append-only, una línea por handoff.

## Rate limit
- En zona danger/hard: pasos chicos + `/handoff` tras cada paso atómico.
- Nunca dejes una sesión cerca del límite sin handoff completo.

## Honestidad
- Si algo quedó a medias, sin verificar o falló: decilo explícito en el handoff y
  al usuario. No reportes como hecho lo que no verificaste.

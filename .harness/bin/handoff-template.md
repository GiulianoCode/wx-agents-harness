# Handoff — <título corto de la tarea>
status: open
updated: <YYYY-MM-DD HH:MM>
from_agent: <claude|codex>
to_agent: <codex|claude|cualquiera>
5h_at: <pct>%

## Objetivo
<Qué se está intentando lograr, en 1-3 frases. El "por qué".>

## Spec de referencia
<specs/<feature>/  ·  o "N/A (trabajo ad-hoc)">

## Hecho
- [x] <logro concreto> — `archivo:línea`
- [x] ...

## En progreso (lo que estaba pasando al cortar)
- <el paso atómico exacto en el que se quedó, con suficiente detalle para retomar sin re-investigar>

## Próximos pasos (ordenados)
1. <acción concreta y chica>
2. ...

## Archivos tocados
- `ruta` — <qué se cambió / qué falta>

## Cómo correr / verificar
```bash
bash init.sh        # o el comando real del proyecto
```

## Decisiones y gotchas
- <decisiones de diseño tomadas, callejones sin salida, supuestos, cosas a no repetir>

## Prompt de continuación (pegar en el próximo agente)
```text
Retomá el trabajo descrito en progress/current.md de este repo. Contexto: <1-2 frases>.
Ya está hecho: <resumen>. El próximo paso es: <paso 1>. Seguí desde ahí, manteniendo
el handoff actualizado. Verificá con: <comando>. No rehagas lo ya hecho.
```

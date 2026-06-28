---
description: Crear la spec SDD de una feature (requirements/design/tasks) delegando en el subagente spec-author
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Task
argument-hint: <feature-id o descripción>
---

Creá la especificación SDD para: **$ARGUMENTS**

Pasos:
1. Si `$ARGUMENTS` no corresponde a una feature existente en `feature_list.json`,
   agregala (status `pending`, con un `id` en kebab-case y `spec_dir: specs/<id>`).
2. Generá `specs/<id>/{requirements.md,design.md,tasks.md}` siguiendo `docs/specs.md`
   (basate en `specs/_TEMPLATE/`). **Por defecto hacelo vos, inline.** Delegá en el
   subagente **spec-author** (Task tool) **solo si la feature es grande o requiere
   mucha exploración** — ahí conviene aislar ese ruido del hilo principal.
3. Cuando vuelva, revisá que la spec sea concreta y verificable, actualizá la
   feature a `status: spec_ready`, y **pedile aprobación humana** al usuario antes
   de implementar (gate del flujo SDD).

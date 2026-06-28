# Handoff — (sin trabajo activo)
status: done
updated: —
from_agent: —

No hay handoff abierto. Cuando una sesión se acerque al límite de 5h (o quieras
cambiar de agente), corré `/handoff` para volcar acá el estado y el prompt de
continuación. Mientras `status` sea `done`, el hook `session-resume.sh` no inyecta
nada al arrancar.

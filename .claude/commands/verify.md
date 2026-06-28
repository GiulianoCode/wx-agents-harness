---
description: Correr la verificación del harness/proyecto (init.sh) y reportar el resultado
allowed-tools: Bash, Read
---

Corré `bash init.sh` y reportá el resultado de forma clara:

1. Ejecutá `bash init.sh`.
2. Si pasa (exit 0): confirmalo y resumí qué se verificó.
3. Si falla: listá cada `✗` con una explicación y una propuesta de fix concreta.
   No marques ninguna feature como `done` mientras `init.sh` falle.
4. Si hay un `!` de "sin tests detectados", recordá que se puede setear
   `project.verify_cmd` en `.harness/config.json`.

$ARGUMENTS

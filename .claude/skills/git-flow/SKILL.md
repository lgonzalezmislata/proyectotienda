---
name: git-flow
description: Todo el git del proyecto. Lanza uno de los comandos start N, update, commit, finish N o publish del flujo de ramas (rama y worktree por issue, squash en develop, develop → main). Úsala siempre que haya que empezar, actualizar, hacer commit, terminar o publicar un issue; fuera de ella no se ejecuta ningún git.
allowed-tools: Bash(.claude/skills/git-flow/scripts/*), Bash(./.claude/skills/git-flow/scripts/*), Bash(scripts/issue_*.sh*)
---

# /git-flow

Cada comando es un script de `.claude/skills/git-flow/scripts/` que comprueba, hace el trabajo y responde
con un mensaje fijo. **Tú solo lo lanzas** (en la carpeta actual, sin `cd`) y **copias su salida tal cual**
como respuesta, sin añadir consejos, alternativas ni órdenes de git. Si el script se para, te paras: no
arreglas nada, no preguntas y no lanzas nada más. Una operación por invocación.

Argumentos: `$ARGUMENTS`

| Argumento | Lo que se lanza |
|---|---|
| `start N` | `.claude/skills/git-flow/scripts/start.sh N` |
| `update` | `.claude/skills/git-flow/scripts/update.sh` |
| `commit` | el procedimiento de abajo |
| `finish N` | `.claude/skills/git-flow/scripts/finish.sh N` |
| `publish` | `.claude/skills/git-flow/scripts/publish.sh` |

Sin argumentos o con otro comando, responde: «Uso: /git-flow start N | update | commit | finish N | publish».
Si `start` o `finish` vienen sin número, lanza el script sin número: él da el mensaje de uso.

## commit

Es el único comando en el que piensas: decides cómo agrupar los cambios y escribes las descripciones.

1. Lanza `.claude/skills/git-flow/scripts/commit.sh` sin argumentos. Si responde con un mensaje de parada
   (no hay cambios, no es el worktree, update a medias) o con la lista de commits, cópialo y termina.
2. Si no, te enseña los ficheros cambiados y sus diferencias. Lee también los ficheros nuevos (`??`).
   Agrupa los cambios **por intención, no por fichero**: cada grupo es una cosa hecha (una
   funcionalidad, un test, la documentación de algo).
3. Por cada grupo, lanza:
   `.claude/skills/git-flow/scripts/commit.sh "Descripción" fichero1 fichero2 ...`
   - La descripción es **solo lo que se ha hecho**, corta, en castellano y con mayúscula inicial:
     `Formulario de alta con validación de NIF`. **Sin `type(#N):` delante**: la rama ya dice de qué
     issue es, y el `feat(#N):` lo pone `finish` en `develop`.
   - Un directorio nuevo (`?? carpeta/`) se pasa tal cual, como `carpeta/`.
   - Si responde «El fichero X no tiene cambios: quítalo del commit», quita ese fichero y repítelo.
4. Tras el último grupo, el script sube la rama a GitHub y responde con la lista de commits de la rama:
   esa es tu respuesta.

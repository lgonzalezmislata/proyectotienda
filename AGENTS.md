# Proyecto Tienda

Tienda online de ejemplo del módulo Despliegue y proyecto: un único repositorio con el backend y el
frontend.

- `frontend/`: de momento, páginas HTML estáticas. Se prueba abriendo `frontend/index.html` en el
  navegador; no se compila.
- `backend/`: todavía no existe.
- `scripts/`: crear, empezar y cerrar issues del Project de GitHub (`issue_create.sh`,
  `issue_in_progress.sh`, `issue_close.sh`).

## Git

- **Git solo con `/git-flow`** (`start N`, `update`, `commit`, `finish N`, `publish`). Fuera de la skill
  no se ejecuta ningún `git`, ni siquiera para mirar: si hace falta algo que la skill no hace, se para y
  se le dice al usuario.
- Se programa en el worktree del issue (`../proyectotienda-wt-<slug>-<N>`); la carpeta principal está
  siempre en `develop` y limpia.

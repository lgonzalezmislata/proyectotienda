#!/bin/bash
# /git-flow publish — pasa origin/develop a origin/main (fast-forward) y deja la main local igual.
# Se lanza en la carpeta principal. Publica lo que hay en GitHub: la rama y el estado local dan igual.
# Uso: .claude/skills/git-flow/scripts/publish.sh
. "$(dirname "$0")/lib.sh"

# Deja la main local igual que origin/main sin cambiar de rama (fast-forward; si está en main, merge --ff-only)
main_local() {
  if [ "$(git -C "$MAIN" branch --show-current)" = main ]; then
    git -C "$MAIN" merge --ff-only --quiet origin/main
  elif git show-ref -q --verify refs/heads/main; then
    git -C "$MAIN" fetch --quiet origin main:main
  else
    git -C "$MAIN" branch --quiet --track main origin/main
  fi 2>/dev/null || echo "Aviso: la main local tiene commits que no están en GitHub; no se ha tocado"
}

# ---------- Precondiciones ----------
traer
C=$(commits origin/develop..origin/main); [ -z "$C" ] ||
  para "main tiene commits que no están en develop: $C. En main no se trabaja; no se publica hasta resolverlo"
if [ -z "$(git rev-list origin/main..origin/develop)" ]; then
  main_local >&2
  para "main ya está igual que develop: no hay nada que publicar"
fi

# ---------- Acciones ----------
ENTRAN=$(commits origin/main..origin/develop)
git push --quiet origin origin/develop:refs/heads/main 2>/dev/null ||
  para "GitHub no ha aceptado main: ha cambiado mientras tanto. Vuelve a lanzar /git-flow publish" 2
traer
main_local
echo "Publicado: main = develop ($(git rev-parse --short origin/main)). Entran: $ENTRAN. GitHub Actions lo despliega"

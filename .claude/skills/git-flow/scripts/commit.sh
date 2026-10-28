#!/bin/bash
# /git-flow commit — un commit por cada cosa hecha y push de la rama. La IA solo decide cómo agrupar y
# escribe las descripciones; este script comprueba, añade, hace cada commit y sube la rama.
# Se lanza en el worktree del issue. Uso:
#   commit.sh                       comprueba las precondiciones y enseña los cambios (para agrupar)
#   commit.sh "Descripción" f...    hace un commit con solo esos ficheros; si ya no quedan cambios,
#                                   sube la rama y responde con la lista de commits
. "$(dirname "$0")/lib.sh"

# ---------- Precondiciones ----------
[ "$TOP" != "$MAIN" ] && es_rama_issue "$CUR" ||
  para "commit se lanza en el worktree del issue. En develop no se hace commit: lo hace finish"
merge_a_medias && para "Hay un update a medias. Termina el conflicto y vuelve a lanzar /git-flow update"

# Sube la rama (sin forzar) y responde con los commits de la rama que no están en origin/develop
subir_y_listar() {
  git push --quiet origin "$CUR" 2>/dev/null ||
    para "Commits hechos, pero GitHub no ha aceptado la rama $CUR. Vuelve a lanzar /git-flow commit" 2
  echo "Commits de la rama $CUR que no están en develop:"
  git log --no-merges --format='  %h %s' origin/develop..HEAD
}

if [ $# -eq 0 ]; then
  if [ -z "$(cambios)" ]; then
    # Sin cambios pero con commits sin subir: viene de un commit cortado antes del push
    [ -n "$(git rev-list "origin/$CUR..HEAD" 2>/dev/null)" ] && { subir_y_listar; exit 0; }
    para "No hay cambios que commitear"
  fi
  echo "Rama $CUR. Ficheros con cambios (?? = nuevo):"
  git -c core.quotepath=off status --porcelain | sed 's/^/  /'
  echo
  echo "Diferencias de los ficheros ya seguidos:"
  git -c core.quotepath=off --no-pager diff HEAD | head -c 60000
  exit 0
fi

# ---------- Un commit ----------
MSG=$1; shift
[ -n "$MSG" ] && [ $# -gt 0 ] || para 'Uso: commit.sh "Descripción" fichero...'
for f in "$@"; do
  [ -n "$(git -c core.quotepath=off status --porcelain -- "$f")" ] || para "El fichero $f no tiene cambios: quítalo del commit"
done
git add -A -- "$@" && git commit --quiet -m "$MSG" -- "$@" || para "git commit ha fallado" 2
git log -1 --format='Hecho: %h %s'
if [ -n "$(cambios)" ]; then echo "Quedan cambios: $(cambios)"; else subir_y_listar; fi

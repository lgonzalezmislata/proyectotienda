#!/bin/bash
# /git-flow commit — un commit por cada cosa hecha. La IA solo decide cómo agrupar y escribe los mensajes;
# este script comprueba, añade y hace cada commit. Se lanza en el worktree del issue.
# Uso:
#   commit.sh                         comprueba las precondiciones y enseña los cambios (para agrupar)
#   commit.sh "type(#N):título" f...  hace un commit con solo esos ficheros
#   commit.sh --lista                 commits de la rama que no están en origin/develop
. "$(dirname "$0")/lib.sh"

# ---------- Precondiciones ----------
[ "$TOP" != "$MAIN" ] && es_rama_issue "$CUR" ||
  para "commit se lanza en el worktree del issue. En develop no se hace commit: lo hace finish"
merge_a_medias && para "Hay un update a medias. Termina el conflicto y vuelve a lanzar /git-flow update"
N=${CUR##*-}

lista() {
  echo "Commits de la rama $CUR que no están en develop:"
  git log --no-merges --format='  %h %s' origin/develop..HEAD
}

if [ "$1" = --lista ]; then lista; exit 0; fi

if [ $# -eq 0 ]; then
  [ -n "$(cambios)" ] || para "No hay cambios que commitear"
  echo "Rama $CUR (issue #$N). Ficheros con cambios (?? = nuevo):"
  git -c core.quotepath=off status --porcelain | sed 's/^/  /'
  echo
  echo "Diferencias de los ficheros ya seguidos:"
  git -c core.quotepath=off --no-pager diff HEAD | head -c 60000
  exit 0
fi

# ---------- Un commit ----------
MSG=$1; shift
invalido() { para "Mensaje no válido: tiene que ser type(#$N):título, con type feat, fix, test, docs, refactor o chore${1:+ ($1)}"; }
[[ "$MSG" =~ ^(feat|fix|test|docs|refactor|chore)\(#$N\):[^[:space:]].* ]] || invalido
[ $# -gt 0 ] || invalido "faltan los ficheros"
for f in "$@"; do
  [ -n "$(git -c core.quotepath=off status --porcelain -- "$f")" ] || invalido "$f no tiene cambios"
done
git add -A -- "$@" && git commit --quiet -m "$MSG" -- "$@" || para "git commit ha fallado" 2
git log -1 --format='Hecho: %h %s'
[ -n "$(cambios)" ] && echo "Quedan cambios: $(cambios)" || lista

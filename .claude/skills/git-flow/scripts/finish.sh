#!/bin/bash
# /git-flow finish N — squash de la rama del issue en develop, push, cierra el issue y borra rama y worktree.
# Se lanza en la carpeta principal. Uso: .claude/skills/git-flow/scripts/finish.sh N
. "$(dirname "$0")/lib.sh"
N=$1

# ---------- Precondiciones de develop ----------
[[ "$N" =~ ^[0-9]+$ ]] || para "Uso: /git-flow finish N"
traer
[ "$CUR" = develop ] && [ "$TOP" = "$MAIN" ] || para "finish se lanza en la carpeta principal y en develop, y aquí la rama es ${CUR:-(ninguna)}"
F=$(cambios); [ -z "$F" ] || para "La carpeta principal tiene cambios sin commit: $F. En develop no se trabaja: llévalos a un issue o descártalos"

RAMA=$(rama_local "$N"); [ -n "$RAMA" ] || RAMA=$(rama_remota "$N")
WT=; [ -n "$RAMA" ] && WT=$(worktree_de "$RAMA")
YA_SUBIDO=$(git log --format=%s origin/develop | grep -m1 -E "^(feat|fix)\(#$N\):")
LOCAL=$(commits origin/develop..develop)

# Estado a medias: el commit del issue está hecho en develop pero no subido (se cortó el push)
if [ -z "$YA_SUBIDO" ] && [ "$(git rev-list --count origin/develop..develop)" = 1 ] &&
   git log -1 --format=%s develop | grep -qE "^(feat|fix)\(#$N\):"; then
  git push --quiet origin develop 2>/dev/null || {
    git reset --quiet --keep HEAD~1
    para "GitHub no ha aceptado develop: ha cambiado mientras tanto. Se ha deshecho el commit; la rama y el worktree siguen ahí. Lanza /git-flow update en el worktree y otra vez finish $N" 2; }
  traer; YA_SUBIDO=$(git log -1 --format=%s develop); LOCAL=
fi
[ -z "$LOCAL" ] || para "develop tiene commits que no están en GitHub: $LOCAL. En develop solo hace commits finish"

if [ -z "$YA_SUBIDO" ]; then
  # ---------- Precondiciones de la rama del issue ----------
  [ -n "$RAMA" ] && [ -n "$WT" ] || para "El issue #$N no tiene rama ni worktree: no se ha empezado o ya está terminado"
  { F=$(cambios "$WT"); [ -z "$F" ] && ! merge_a_medias "$WT"; } ||
    para "El worktree tiene cambios sin commit o un update a medias: ${F:-merge sin terminar}. Termínalo allí con /git-flow commit o /git-flow update"
  # develop no tiene commits locales (comprobado arriba): contener origin/develop es contener develop
  git merge-base --is-ancestor origin/develop "$RAMA" ||
    para "La rama $RAMA no tiene los últimos cambios de develop. Lanza /git-flow update en $(relativa "$WT"), prueba y vuelve a lanzar finish $N"
  [ "$(git rev-list --no-merges --count "origin/develop..$RAMA")" -gt 0 ] ||
    para "La rama $RAMA no tiene commits: no hay nada que cerrar"
  INFO=$(gh issue view "$N" --json title,labels 2>/dev/null) || para "No se puede leer el issue #$N en GitHub" 2
  TITULO=$(jq -r .title <<<"$INFO")
  if jq -e '[.labels[].name] | index("bug")' <<<"$INFO" >/dev/null; then TIPO=fix; else TIPO=feat; fi

  # ---------- Acciones: squash, commit y push ----------
  git merge --ff-only --quiet origin/develop || para "No se puede poner develop al día con origin/develop" 2
  git merge --squash --quiet "$RAMA" >/dev/null || para "El squash de $RAMA ha fallado" 2
  GITDIR=$(git rev-parse --git-dir)
  {
    echo "$TIPO(#$N):$TITULO"
    echo
    # Del SQUASH_MSG: el título de cada commit de la rama, sin su type(#N):, del más antiguo al más nuevo
    sed -nE "s/^    (feat|fix|test|docs|refactor|chore)\(#$N\): ?(.*)$/- \2/p" "$GITDIR/SQUASH_MSG" | tac
  } > "$GITDIR/FINISH_MSG"
  git commit --quiet -F "$GITDIR/FINISH_MSG" && rm -f "$GITDIR/FINISH_MSG" "$GITDIR/SQUASH_MSG" ||
    para "El commit del squash ha fallado" 2
  if ! git push --quiet origin develop 2>/dev/null; then
    git reset --quiet --keep HEAD~1
    para "GitHub no ha aceptado develop: ha cambiado mientras tanto. Se ha deshecho el commit; la rama y el worktree siguen ahí. Lanza /git-flow update en el worktree y otra vez finish $N" 2
  fi
  YA_SUBIDO=$(git log -1 --format=%s)
else
  # Viene de un finish que ya subió develop: se salta a cerrar el issue
  [ -n "$RAMA" ] || [ -n "$WT" ] || [ "$(gh issue view "$N" --json state --jq .state 2>/dev/null)" = OPEN ] ||
    para "El issue #$N no tiene rama ni worktree: no se ha empezado o ya está terminado"
  git merge --ff-only --quiet origin/develop || para "No se puede poner develop al día con origin/develop" 2
fi

# ---------- Acciones: cerrar el issue y borrar rama y worktree ----------
OUT=$("$MAIN/scripts/issue_close.sh" "$N") || para "develop subido, pero no se ha podido cerrar el issue: $OUT. Vuelve a lanzar /git-flow finish $N" 2
if [ -n "$RAMA" ]; then
  if git show-ref -q --verify "refs/remotes/origin/$RAMA"; then
    git push --quiet origin --delete "$RAMA" 2>/dev/null || para "develop subido e issue cerrado, pero GitHub no ha borrado la rama $RAMA. Vuelve a lanzar /git-flow finish $N" 2
  fi
  if [ -n "$WT" ]; then
    git worktree remove "$WT" 2>/dev/null ||
      para "develop subido e issue cerrado, pero $(relativa "$WT") está abierto en otro programa. Ciérralo y vuelve a lanzar /git-flow finish $N" 2
  fi
  git show-ref -q --verify "refs/heads/$RAMA" && git branch --quiet -D "$RAMA"
fi
echo "Issue #$N en develop: $YA_SUBIDO. Issue cerrado y en Done. Rama y worktree borrados"

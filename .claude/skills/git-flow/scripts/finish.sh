#!/bin/bash
# /git-flow finish N — squash de la rama del issue en develop, push, cierra el issue y borra rama y worktree.
# Se lanza en la carpeta principal. Uso: .claude/skills/git-flow/scripts/finish.sh N
# Se continúa relanzándolo: si se cortó antes de subir develop, lo sube; si se cortó después, cierra y borra.
. "$(dirname "$0")/lib.sh"
N=$1

rechazado() {
  git reset --quiet --keep HEAD~1
  para "GitHub no ha aceptado develop: ha cambiado mientras tanto. Se ha deshecho el commit; la rama y el worktree siguen ahí. Lanza /git-flow update en el worktree y otra vez finish $N" 2
}
del_issue() { grep -m1 -E "^(feat|fix)\(#$N\):"; }   # el commit feat(#N)/fix(#N) de una lista de títulos

# ---------- Precondiciones de develop ----------
[[ "$N" =~ ^[0-9]+$ ]] || para "Uso: /git-flow finish N"
traer
[ "$CUR" = develop ] && [ "$TOP" = "$MAIN" ] || para "finish se lanza en la carpeta principal y en develop, y aquí la rama es ${CUR:-(ninguna)}"
F=$(cambios); [ -z "$F" ] || para "La carpeta principal tiene cambios sin commit: $F. En develop no se trabaja: llévalos a un issue o descártalos"

RAMA=$(rama_local "$N"); [ -n "$RAMA" ] || RAMA=$(rama_remota "$N")
WT=; [ -n "$RAMA" ] && WT=$(worktree_de "$RAMA")
SUBIDO=$(git log --format=%s origin/develop | del_issue)
LOCAL=$(git log --format=%s origin/develop..develop)
SIN_SUBIR=
if [ -n "$LOCAL" ]; then
  # El único commit sin subir es el propio feat(#N)/fix(#N): viene de un finish cortado antes del push
  [ "$(wc -l <<<"$LOCAL")" = 1 ] && [ -n "$(del_issue <<<"$LOCAL")" ] && [ -z "$SUBIDO" ] ||
    para "develop tiene commits que no están en GitHub: $(commits origin/develop..develop). En develop solo hace commits finish"
  SIN_SUBIR=$LOCAL
fi

if [ -n "$SIN_SUBIR" ]; then
  # ---------- Viene de un finish cortado antes de subir: salta a subirlo ----------
  git push --quiet origin develop 2>/dev/null || rechazado
  COMMIT=$SIN_SUBIR
elif [ -n "$SUBIDO" ]; then
  # ---------- Viene de un finish que ya subió: salta a cerrar el issue ----------
  [ -n "$RAMA" ] || [ -n "$WT" ] || [ "$(gh issue view "$N" --json state --jq .state 2>/dev/null)" = OPEN ] ||
    para "El issue #$N no tiene rama ni worktree: no se ha empezado o ya está terminado"
  git merge --ff-only --quiet origin/develop || para "No se puede poner develop al día con origin/develop" 2
  COMMIT=$SUBIDO
else
  # ---------- Precondiciones de la rama del issue (contra origin/develop) ----------
  [ -n "$RAMA" ] && [ -n "$WT" ] || para "El issue #$N no tiene rama ni worktree: no se ha empezado o ya está terminado"
  { F=$(cambios "$WT"); [ -z "$F" ] && ! merge_a_medias "$WT"; } ||
    para "El worktree tiene cambios sin commit o un update a medias: ${F:-merge sin terminar}. Termínalo allí con /git-flow commit o /git-flow update"
  git merge-base --is-ancestor origin/develop "$RAMA" ||
    para "La rama $RAMA no tiene los últimos cambios de develop. Lanza /git-flow update en $(relativa "$WT"), prueba y vuelve a lanzar finish $N"
  [ "$(git rev-list --no-merges --count "origin/develop..$RAMA")" -gt 0 ] ||
    para "La rama $RAMA no tiene commits: no hay nada que cerrar"
  INFO=$(gh issue view "$N" --json title,labels 2>/dev/null) || para "No se puede leer el issue #$N en GitHub" 2
  TITULO=$(jq -r .title <<<"$INFO")
  if jq -e '[.labels[].name] | index("bug")' <<<"$INFO" >/dev/null; then TIPO=fix; else TIPO=feat; fi

  # ---------- Acciones: develop al día, squash, commit y push ----------
  git merge --ff-only --quiet origin/develop || para "No se puede poner develop al día con origin/develop" 2
  git merge --squash --quiet "$RAMA" >/dev/null || para "El squash de $RAMA ha fallado" 2
  GITDIR=$(git rev-parse --git-dir)
  {
    echo "$TIPO(#$N):$TITULO"
    echo
    # Del SQUASH_MSG (del más nuevo al más antiguo): el título de cada commit, sin los merges, y al revés
    awk '/^commit /{m=0; h=1; next} h && /^Merge: /{m=1} h && /^$/{h=0; t=1; next}
         t {t=0; if(!m){sub(/^    /,""); print "- " $0}}' "$GITDIR/SQUASH_MSG" | tac
  } > "$GITDIR/FINISH_MSG"
  git commit --quiet -F "$GITDIR/FINISH_MSG" && rm -f "$GITDIR/FINISH_MSG" "$GITDIR/SQUASH_MSG" ||
    para "El commit del squash ha fallado" 2
  git push --quiet origin develop 2>/dev/null || rechazado
  COMMIT=$(git log -1 --format=%s)
fi

# ---------- Acciones: cerrar el issue y borrar rama y worktree ----------
OUT=$("$MAIN/scripts/issue_close.sh" "$N") || para "develop subido, pero no se ha podido cerrar el issue: $OUT. Vuelve a lanzar /git-flow finish $N" 2
if [ -n "$RAMA" ]; then
  if git show-ref -q --verify "refs/remotes/origin/$RAMA"; then
    git push --quiet origin --delete "$RAMA" 2>/dev/null || para "develop subido e issue cerrado, pero GitHub no ha borrado la rama $RAMA. Vuelve a lanzar /git-flow finish $N" 2
  fi
  if [ -n "$WT" ]; then
    git worktree remove "$WT" 2>/dev/null ||
      para "develop subido e issue cerrado, pero no se ha podido borrar $(relativa "$WT"): está abierto en otro programa o tiene ficheros nuevos. Ciérralo y vuelve a lanzar /git-flow finish $N" 2
  fi
  git show-ref -q --verify "refs/heads/$RAMA" && git branch --quiet -D "$RAMA"
fi
echo "Issue #$N en develop: $COMMIT. Issue cerrado y en Done. Rama y worktree borrados"

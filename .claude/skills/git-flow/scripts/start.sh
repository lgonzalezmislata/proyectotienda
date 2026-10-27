#!/bin/bash
# /git-flow start N — crea la rama y el worktree del issue N desde develop y pasa su tarjeta a In Progress.
# Se lanza en la carpeta principal. Uso: .claude/skills/git-flow/scripts/start.sh N
. "$(dirname "$0")/lib.sh"
N=$1

# ---------- Precondiciones (no cambian nada) ----------
[[ "$N" =~ ^[0-9]+$ ]] || para "Uso: /git-flow start N"
traer
[ "$CUR" = develop ] && [ "$TOP" = "$MAIN" ] || para "start se lanza en la carpeta principal y en develop, y aquí la rama es ${CUR:-(ninguna)}"
F=$(cambios); [ -z "$F" ] || para "La carpeta principal tiene cambios sin commit: $F. En develop no se trabaja: llévalos a un issue o descártalos"
C=$(commits origin/develop..develop); [ -z "$C" ] || para "develop tiene commits que no están en GitHub: $C. En develop solo hace commits finish"

RAMA=$(rama_local "$N"); [ -n "$RAMA" ] || RAMA=$(rama_remota "$N")
CONTINUAR=
if [ -n "$RAMA" ]; then
  WT=$(worktree_de "$RAMA")
  # Estado a medias de un start anterior: rama y worktree creados, pero sin subir a GitHub
  if [ -n "$WT" ] && [ -z "$(rama_remota "$N")" ]; then
    CONTINUAR=1
  else
    para "El issue #$N ya tiene la rama $RAMA en $(relativa "${WT:-$PARENT/$REPO-wt-$RAMA}"): trabaja allí"
  fi
fi

INFO=$(gh api graphql -F owner='{owner}' -F repo='{repo}' -F n="$N" -f query='
  query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){
    projectsV2(first:1){nodes{number}}
    issue(number:$n){state title url labels(first:20){nodes{name}} projectItems(first:20){nodes{project{number}}}}}}' 2>/dev/null)
ESTADO=$(jq -r '.data.repository.issue.state // empty' <<<"$INFO")
[ "$ESTADO" = OPEN ] || para "El issue #$N no existe o está cerrado"
TITULO=$(jq -r '.data.repository.issue.title' <<<"$INFO")
URL=$(jq -r '.data.repository.issue.url' <<<"$INFO")
PROJECT=$(jq -r '.data.repository.projectsV2.nodes[0].number // empty' <<<"$INFO")
jq -e '[.data.repository.issue.labels.nodes[].name] | index("feature") or index("bug")' <<<"$INFO" >/dev/null ||
  para "El issue #$N no tiene etiqueta feature ni bug: gh issue edit $N --add-label feature y vuelve a lanzar start"
jq -e --argjson p "${PROJECT:-0}" '[.data.repository.issue.projectItems.nodes[].project.number] | index($p)' <<<"$INFO" >/dev/null ||
  para "El issue #$N no está en el Project: gh project item-add ${PROJECT:-<número del Project>} --owner @me --url $URL y vuelve a lanzar start"

# ---------- Acciones ----------
if [ -z "$CONTINUAR" ]; then
  git merge --ff-only --quiet origin/develop || para "No se puede poner develop al día con origin/develop" 2
  # Slug: minúsculas, sin tildes, sin palabras de 1 o 2 letras, con guiones, 30 caracteres como mucho (cortando por palabra)
  SLUG=$(echo "$TITULO" | sed 'y/ÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÑÇáéíóúàèìòùäëïöüâêîôûñç/aeiouaeiouaeiouaeiouncaeiouaeiouaeiouaeiounc/' |
    tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/ /g' |
    awk '{s=""; for(i=1;i<=NF;i++) if(length($i)>2){ t=(s==""?$i:s"-"$i); if(length(t)>30) break; s=t } print s}')
  [ -n "$SLUG" ] || SLUG=issue
  RAMA="$SLUG-$N"
  WT="$PARENT/$REPO-wt-$RAMA"
  [ -e "$WT" ] && para "La carpeta $(relativa "$WT") ya existe y no es el worktree de ninguna rama: bórrala o muévela y vuelve a lanzar start"
  git worktree add --quiet -b "$RAMA" "$WT" develop || para "No se ha podido crear el worktree $(relativa "$WT")" 2
fi

git -C "$WT" push --quiet --set-upstream origin "$RAMA" 2>/dev/null ||
  para "Rama $RAMA y worktree $(relativa "$WT") creados, pero GitHub no ha aceptado la rama. Vuelve a lanzar /git-flow start $N" 2
OUT=$("$MAIN/scripts/issue_in_progress.sh" "$N") ||
  para "Rama $RAMA subida, pero la tarjeta no ha pasado a In Progress: $OUT. Lanza scripts/issue_in_progress.sh $N" 2

echo "Issue #$N: $TITULO. Rama $RAMA creada desde develop. Worktree en $(relativa "$WT")"

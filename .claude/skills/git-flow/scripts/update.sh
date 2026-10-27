#!/bin/bash
# /git-flow update — trae a la rama del issue lo nuevo de origin/develop.
# Se lanza en el worktree del issue. Uso: .claude/skills/git-flow/scripts/update.sh
. "$(dirname "$0")/lib.sh"

# ---------- Precondiciones ----------
[ "$TOP" != "$MAIN" ] && es_rama_issue "$CUR" || para "update se lanza en el worktree del issue, no en la carpeta principal"

conflicto() {
  echo "Conflicto al traer develop a la rama $CUR."
  echo "Ficheros en conflicto:"
  printf '  %s\n' "$@"
  echo "Resuélvelos en el worktree: deja cada fichero como tiene que quedar y quita las marcas <<<<<<< ======= >>>>>>>."
  echo "Después vuelve a lanzar /git-flow update: él termina el merge."
  exit 2
}

ENTRADO=
if merge_a_medias; then
  # Merge a medias: viene de un conflicto de un update anterior
  mapfile -t U < <(git -c core.quotepath=off diff --name-only --diff-filter=U)
  CON_MARCAS=()
  # Se miran los que siguen en conflicto y los ya añadidos (por si se añadió alguno con marcas)
  for f in $(printf '%s\n' "${U[@]}" $(git -c core.quotepath=off diff --cached --name-only) | sort -u); do
    [ -f "$f" ] && grep -qE '^(<<<<<<<|=======|>>>>>>>)( |$)' -- "$f" && CON_MARCAS+=("$f")
  done
  [ ${#CON_MARCAS[@]} -eq 0 ] || conflicto "${CON_MARCAS[@]}"
  [ ${#U[@]} -eq 0 ] || git add -- "${U[@]}"
  ENTRADO=$(commits HEAD..MERGE_HEAD)
  git commit --quiet --no-edit || para "No se ha podido terminar el merge" 2
else
  F=$(cambios); [ -z "$F" ] || para "Hay cambios sin commit: $F. Haz /git-flow commit y vuelve a lanzar update"
fi

# ---------- Acciones ----------
traer
if git merge-base --is-ancestor origin/develop HEAD; then
  [ -n "$ENTRADO" ] && para "Rama $CUR al día con develop: $ENTRADO" 0
  para "La rama $CUR ya tenía todo develop" 0
fi

NUEVOS=$(commits HEAD..origin/develop)
if ! git merge --quiet --no-edit origin/develop >/dev/null 2>&1; then
  merge_a_medias || para "No se ha podido traer develop: git merge ha fallado sin conflicto (¿ficheros sin seguimiento que develop también trae?)" 2
  mapfile -t U < <(git -c core.quotepath=off diff --name-only --diff-filter=U)
  conflicto "${U[@]}"
fi
echo "Rama $CUR al día con develop: ${ENTRADO:+$ENTRADO; }$NUEVOS"

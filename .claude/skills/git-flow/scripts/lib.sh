#!/bin/bash
# Funciones comunes de los comandos de /git-flow. Se carga con: . "$(dirname "$0")/lib.sh"
# Convención de salida: 0 = hecho; 1 = parado en una precondición (no se ha tocado nada);
# 2 = parado a medias por un conflicto o un fallo de GitHub (el mensaje dice qué relanzar).

export GIT_TERMINAL_PROMPT=0
export GIT_EDITOR=true          # nunca abre un editor: los mensajes los ponen los scripts

para()  { echo "$1"; exit "${2:-1}"; }

# Carpeta principal (primer worktree), carpeta actual y rama actual
MAIN=$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
[ -n "$MAIN" ] || para "No es un repositorio git"
TOP=$(git rev-parse --show-toplevel)
CUR=$(git branch --show-current)
REPO=$(basename "$MAIN")
PARENT=$(dirname "$MAIN")

traer() { git fetch --prune --quiet origin || para "No se puede conectar con GitHub (git fetch ha fallado)" 2; }

# Ficheros con cambios sin commit (incluidos los nuevos sin seguimiento), separados por comas
cambios() { git -C "${1:-.}" -c core.quotepath=off status --porcelain | cut -c4- | paste -sd, - | sed 's/,/, /g'; }

# Commits de un rango, "hash título" separados por "; "
commits() { git log --format='%h %s' "$@" | paste -sd';' - | sed 's/;/; /g'; }

merge_a_medias() { git -C "${1:-.}" rev-parse -q --verify MERGE_HEAD >/dev/null; }

# Rama del issue N: local o en GitHub, que acabe en -N
rama_local()  { git for-each-ref --format='%(refname:short)' refs/heads/ | grep -E -- "-$1\$" | head -1; }
rama_remota() { git for-each-ref --format='%(refname:short)' refs/remotes/origin/ | sed 's#^origin/##' | grep -E -- "-$1\$" | head -1; }

# Carpeta del worktree que tiene la rama $1 (vacío si no tiene)
worktree_de() {
  git worktree list --porcelain | awk -v b="refs/heads/$1" '
    /^worktree /{w=substr($0,10)} $0=="branch " b {print w}'
}

# Ruta relativa a la carpeta principal, como la dan los mensajes: ../repo-wt-slug-N
relativa() { echo "../$(basename "$1")"; }

es_rama_issue() { [[ "$1" =~ -[0-9]+$ ]] && [ "$1" != develop ] && [ "$1" != main ] && [ "$1" != master ]; }

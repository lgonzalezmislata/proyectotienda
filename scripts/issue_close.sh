#!/bin/bash
# Uso: issue_close.sh N
PROJECT=$(gh api graphql -F owner='{owner}' -F repo='{repo}' -f query='query($owner:String!,$repo:String!){repository(owner:$owner,name:$repo){projectsV2(first:1){nodes{number}}}}' --jq '.data.repository.projectsV2.nodes[0].number') 
N=$1

PROJECT_ID=$(gh project view $PROJECT --owner @me --format json --jq .id)
CAMPO=$(gh project field-list $PROJECT --owner @me --format json --jq '.fields[] | select(.name=="Status") | .id')
OPCION=$(gh project field-list $PROJECT --owner @me --format json --jq '.fields[] | select(.name=="Status") | .options[] | select(.name=="Done") | .id')
TARJETA=$(gh project item-list $PROJECT --owner @me --limit 1000 --format json --jq ".items[] | select(.content.number==$N) | .id")

if [ -z "$TARJETA" ]; then echo "El issue #$N no está en el Project"; exit 1; fi

gh issue close $N > /dev/null 2>&1
gh project item-edit --project-id $PROJECT_ID --field-id $CAMPO --single-select-option-id $OPCION --id $TARJETA > /dev/null
echo "Issue #$N cerrado y en Done"

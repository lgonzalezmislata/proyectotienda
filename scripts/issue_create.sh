#!/bin/bash
# Uso: issue_create.sh "título" "descripción" [feature|bug]
PROJECT=$(gh api graphql -F owner='{owner}' -F repo='{repo}' -f query='query($owner:String!,$repo:String!){repository(owner:$owner,name:$repo){projectsV2(first:1){nodes{number}}}}' --jq '.data.repository.projectsV2.nodes[0].number')

URL=$(gh issue create --title "$1" --body "$2" --label "${3:-feature}")
gh project item-add $PROJECT --owner @me --url $URL > /dev/null 2>&1    # si ya lo ha añadido GitHub, da igual
echo $URL | grep -o '[0-9]*$'

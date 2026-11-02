#!/usr/bin/env bash
set -euo pipefail

: "${FLUTTER_ROOT:?FLUTTER_ROOT must point to the Flutter checkout}"

cd "$FLUTTER_ROOT"

revert_commit=77dd6dcadcb7a3515e82e58287d03f232e4210dd
if ! git log --format=%B --grep="This reverts commit $revert_commit" -n 1 | grep -Fq "$revert_commit"; then
  git -c user.name='GitHub Actions' \
    -c user.email='github-actions[bot]@users.noreply.github.com' \
    revert --strategy-option theirs --no-edit "$revert_commit"
fi

if ! git show-ref --verify --quiet refs/tags/3.47.7; then
  git tag 3.47.7 HEAD
fi

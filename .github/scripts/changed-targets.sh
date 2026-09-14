#!/usr/bin/env bash
# Prints a JSON array of the bake targets that need rebuilding compared to a base commit.
#
#   changed-targets.sh           # every target
#   changed-targets.sh <commit>  # targets whose definition or build inputs changed since <commit>
set -euo pipefail

base=${1:-}

bake_targets() {
  docker buildx bake --progress=quiet --print "$@" | jq -c '.target'
}

head=$(bake_targets)

# No usable base commit (manual run, new branch): build everything
if [ -z "${base}" ] || ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
  jq -c 'keys' <<< "${head}"
  exit 0
fi

# Anything shared by every image changed: build everything
if ! git diff --quiet "${base}" -- Dockerfile .dockerignore rootfs rcon-fix \
  .github/scripts/smoke-test.sh .github/scripts/client-test.js .github/scripts/rcon-test.js \
  .github/scripts/package.json .github/scripts/package-lock.json; then
  jq -c 'keys' <<< "${head}"
  exit 0
fi

base_targets='{}'
if git cat-file -e "${base}:docker-bake.hcl" 2>/dev/null; then
  base_targets=$(git show "${base}:docker-bake.hcl" | bake_targets -f -)
fi

jq -cn --argjson head "${head}" --argjson base "${base_targets}" \
  '[$head | to_entries[] | select(.value != $base[.key]) | .key]'

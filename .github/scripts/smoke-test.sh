#!/usr/bin/env bash
set -euo pipefail

image=$1
name="smoke-test-$$"

fail() {
  echo "::error::${image}: $1"
  docker logs "${name}" 2>&1 | tail -100
  docker rm -f "${name}" > /dev/null 2>&1 || true
  exit 1
}

docker run -d --name "${name}" -e ACCEPT_EULA=true -e RCON_PASSWORD=smoke-test "${image}" > /dev/null

healthy=false
for _ in $(seq 300); do
  if docker exec "${name}" /health 2> /dev/null; then
    healthy=true
    break
  fi
  if [ "$(docker inspect -f '{{.State.Running}}' "${name}")" != true ]; then
    fail "server exited before becoming healthy"
  fi
  sleep 1
done
[ "${healthy}" = true ] || fail "server did not become healthy within 300s"

output=$(docker exec "${name}" /pre-stop 2>&1) || fail "pre-stop failed: ${output}"
echo "${output}"
grep -q 'Saved the game' <<< "${output}" || fail "pre-stop did not save the game"

docker stop -t 60 "${name}" > /dev/null
code=$(docker inspect -f '{{.State.ExitCode}}' "${name}")
[ "${code}" = 0 ] || [ "${code}" = 143 ] || fail "server exited with code ${code} when stopped"

docker rm "${name}" > /dev/null
echo "${image}: smoke test passed"

#!/usr/bin/env bash
set -euo pipefail

image=$1
name="smoke-test-$$"
scripts=$(dirname "$(readlink -f "$0")")
pre_stop=$(mktemp)

cleanup() {
  docker rm -f "${name}" > /dev/null 2>&1 || true
  docker volume rm -f "${name}" > /dev/null 2>&1 || true
  rm -f "${pre_stop}"
}
trap cleanup EXIT

fail() {
  echo "::error::${image}: $1"
  docker logs "${name}" 2>&1 | tail -100
  exit 1
}

docker run --rm --entrypoint cat "${image}" /pre-stop | sed 's/^WAIT=600$/WAIT=60/' > "${pre_stop}"
grep -q '^WAIT=60$' "${pre_stop}" || fail "could not shorten the pre-stop wait"
chmod 755 "${pre_stop}"

docker run --rm -v "${name}:/minecraft" --entrypoint sh "${image}" -c 'echo online-mode=false > /minecraft/server.properties'
docker run -d --name "${name}" -v "${name}:/minecraft" -v "${pre_stop}:/pre-stop:ro" \
  -e ACCEPT_EULA=true -e RCON_PASSWORD=smoke-test "${image}" > /dev/null

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

host=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${name}")
variant=$(docker exec "${name}" sh -c 'echo "${MC_VARIANT}"')
node "${scripts}/rcon-test.js" "${host}" smoke-test "${variant}" || fail "rcon test failed"

result=0
node "${scripts}/client-test.js" "${name}" "${host}" || result=$?

case "${result}" in
  0) ;;
  2)
    output=$(docker exec "${name}" /pre-stop 2>&1) || fail "pre-stop failed: ${output}"
    echo "${output}"
    grep -q 'Saved the game' <<< "${output}" || fail "pre-stop did not save the game"
    ;;
  *) fail "client test failed" ;;
esac

docker stop -t 60 "${name}" > /dev/null
code=$(docker inspect -f '{{.State.ExitCode}}' "${name}")
[ "${code}" = 0 ] || [ "${code}" = 143 ] || fail "server exited with code ${code} when stopped"

echo "${image}: smoke test passed"

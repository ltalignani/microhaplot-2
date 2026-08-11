#!/usr/bin/env bash
# End-to-end Docker smoke test for the microhaplot image.
#
# This is the single test seam for the Docker packaging effort: it exercises
# the packaging from the user's point of view rather than unit-testing
# individual Dockerfile steps. It verifies that
#
#   1. the image builds,
#   2. `docker compose up` starts both services without error,
#   3. the `main` and `prep` services both respond on their ports,
#   4. the `prep` service can run a real extraction over a bundled BAM+VCF
#      dataset (proving samtools and Perl work inside the image),
#   5. the resulting .rds is visible and loadable from the `main` service
#      through the shared volume, without restarting any container.
#
# CI runs this before publishing an image; it is also meant to be run
# locally while developing the Dockerfile or compose file.
#
#   scripts/docker-smoke-test.sh
#   SKIP_BUILD=1 scripts/docker-smoke-test.sh   # reuse an existing image tag
#
# Ports, image name, and the tag under test are overridable via the same
# environment variables docker-compose.yml reads.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

IMAGE=${IMAGE:-ghcr.io/ltalignani/microhaplot-2}
export MICROHAPLOT_VERSION=${MICROHAPLOT_VERSION:-smoke-test}
export MICROHAPLOT_MAIN_PORT=${MICROHAPLOT_MAIN_PORT:-3838}
export MICROHAPLOT_PREP_PORT=${MICROHAPLOT_PREP_PORT:-3839}
export SMOKE_RUN_LABEL=${SMOKE_RUN_LABEL:-smoke}

# A throwaway stand-in for the user's shared data folder. World-writable so
# the container's default 1000:1000 can write to it whatever the host UID.
data_dir=$(mktemp -d "${TMPDIR:-/tmp}/microhaplot-smoke.XXXXXX")
chmod 777 "$data_dir"
export MICROHAPLOT_DATA_DIR=$data_dir

cleanup() {
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "--- smoke test failed; container logs follow ---" >&2
    docker compose logs >&2 || true
  fi
  docker compose down --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$data_dir"
  return "$status"
}
trap cleanup EXIT

step() { echo; echo "==> $*"; }

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  step "1/5 Building ${IMAGE}:${MICROHAPLOT_VERSION}"
  docker build -t "${IMAGE}:${MICROHAPLOT_VERSION}" .
else
  step "1/5 Skipping build, reusing ${IMAGE}:${MICROHAPLOT_VERSION}"
fi

step "2/5 Starting both services (data dir: ${data_dir})"
docker compose up -d

step "3/5 Waiting for both services to respond"
for port in "$MICROHAPLOT_MAIN_PORT" "$MICROHAPLOT_PREP_PORT"; do
  for attempt in $(seq 1 30); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${port}/" || true)
    if [ "$code" = "200" ]; then
      echo "port ${port} responded 200"
      break
    fi
    if [ "$attempt" = "30" ]; then
      echo "port ${port} never responded 200 (last: ${code})" >&2
      exit 1
    fi
    sleep 2
  done
done

step "4/5 Running a real BAM+VCF extraction in the prep service"
docker compose exec -T -e SMOKE_RUN_LABEL="$SMOKE_RUN_LABEL" prep \
  bash -s < scripts/smoke/prep-extraction.sh

step "5/5 Loading the produced .rds from the main service (no restart)"
docker compose exec -T -e SMOKE_RUN_LABEL="$SMOKE_RUN_LABEL" main \
  Rscript - < scripts/smoke/main-verify.R

echo
echo "smoke test passed on $(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')"

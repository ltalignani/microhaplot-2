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
#   5. microhaplot-extract (wayfinder ticket #34) actually works inside the
#      built image too — `validate` against a known-good BAM, and a real
#      `extract` batch run whose combined output matches the golden
#      fixture — even though nothing calls it in place of Perl yet,
#   6. the resulting .rds from step 4 is visible and loadable from the
#      `main` service through the shared volume, without restarting any
#      container.
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
  # Everything the containers wrote into the volume is owned by the
  # container's UID (1000 by default), which on Linux is a different user
  # from whoever runs this script — on a GitHub runner, `runner` is 1001, so
  # this fails outright. macOS hides the difference, which is why it went
  # unnoticed. The directory is a mktemp scratch dir either way, so failing
  # to remove it must not fail the run.
  rm -rf "$data_dir" 2>/dev/null || true
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

# Step 3 only proves Shiny served a page. The server function does not run
# until a browser opens a websocket, so an app that dies on its first line
# still answers 200 — see scripts/smoke/app-loads.R.
step "3b/6 Checking the Shiny app's own code loads in the image"
docker compose exec -T main Rscript - < scripts/smoke/app-loads.R

step "4/6 Running a real BAM+VCF extraction in the prep service"
docker compose exec -T -e SMOKE_RUN_LABEL="$SMOKE_RUN_LABEL" prep \
  bash -s < scripts/smoke/prep-extraction.sh

step "5/6 Checking microhaplot-extract works inside the built image"
docker compose exec -T prep \
  bash -s < scripts/smoke/microhaplot-extract-check.sh

# The container step above wrote its combined output into the shared
# volume; compare it here, on the host, against the same golden fixture
# the Rust/R test suites already check it against — this is the "not just
# that the image builds" half of ticket #34's acceptance criterion.
actual=$(sort "$data_dir/microhaplot-extract-check/intermed/all.summary")
expected=$(sort tests/testthat/fixtures/hapture-golden/sebastes-all.summary)
if [ "$actual" != "$expected" ]; then
  echo "microhaplot-extract's output inside the image doesn't match the golden fixture" >&2
  exit 1
fi
echo "microhaplot-extract's output matches the golden fixture"

step "6/6 Loading the produced .rds from the main service (no restart)"
docker compose exec -T -e SMOKE_RUN_LABEL="$SMOKE_RUN_LABEL" main \
  Rscript - < scripts/smoke/main-verify.R

echo
echo "smoke test passed on $(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')"

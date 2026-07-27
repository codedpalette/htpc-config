#!/usr/bin/env bash
set -euo pipefail

# Resolve directory of this script, regardless of where it's called from
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# `down` never runs a healthcheck, but Compose still validates these durations while
# parsing, so they have to be set to *something*. The real values live in up.sh.
export START_PERIOD=0s
export START_INTERVAL=0s

cd "$ROOT_DIR"
docker -l error compose down "$@"
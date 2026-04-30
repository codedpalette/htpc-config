#!/usr/bin/env bash
set -euo pipefail

# Resolve directory of this script, regardless of where it's called from
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT_DIR"
docker -l error compose down "$@"
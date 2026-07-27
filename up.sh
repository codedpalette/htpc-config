#!/usr/bin/env bash
set -euo pipefail

# Resolve directory of this script, regardless of where it's called from
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# Short hostname (e.g. "server" rather than "server.local")
DOMAIN="$(hostname -s)"
export DOMAIN

# Pi's IP on local network
DEFAULT_INTERFACE="$(ip route show default | awk '/default/ {print $5; exit}')"
LOCAL_IP="$(ip -4 addr show $DEFAULT_INTERFACE | awk '/inet / {print $2}' | cut -d/ -f1)"
export LOCAL_IP

# First IPv4 address from Tailscale
TAILSCALE_IP="$(tailscale ip -4 | head -n1)"
if [[ -z "$TAILSCALE_IP" ]]; then
  echo "Error: could not determine Tailscale IP. Is tailscale running?" >&2
  exit 1
fi
export TAILSCALE_IP

# Get hostnames of all Tailscale devices, for Pi-hole clients resolution
TAILNET_HOSTS="$(tailscale status | awk 'NF >= 2 && $1 ~ /^[0-9]+\./ { print $1, $2 }' | paste -sd ';' -)"
export TAILNET_HOSTS

# Healthcheck grace period, applied to every service's healthcheck.
# Everything boots at once on a Pi, so slow starters must not be reported unhealthy
# while they are still coming up - otherwise autoheal restarts them and the storm
# feeds itself. Failing probes inside START_PERIOD don't count towards `retries`, and
# the first passing probe ends it early, so this costs nothing when startup is fast.
START_PERIOD="5m"
export START_PERIOD

# How often to probe while still inside START_PERIOD (vs. the 30s default interval),
# so a service is picked up as healthy soon after it is actually ready.
START_INTERVAL="5s"
export START_INTERVAL

echo "ROOT_DIR=$ROOT_DIR"
echo "DOMAIN=$DOMAIN"
echo "LOCAL_IP=$LOCAL_IP"
echo "TAILSCALE_IP=$TAILSCALE_IP"
echo "TAILNET_HOSTS=$TAILNET_HOSTS"
echo "START_PERIOD=$START_PERIOD"
echo "START_INTERVAL=$START_INTERVAL"
  
cd "$ROOT_DIR"
docker compose up -d "$@"
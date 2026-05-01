#!/usr/bin/env bash
set -euo pipefail

# Resolve directory of this script, regardless of where it's called from
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

# Short hostname (e.g. "server" rather than "server.local")
DOMAIN="$(hostname -s)"
export DOMAIN

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

echo "ROOT_DIR=$ROOT_DIR"
echo "DOMAIN=$DOMAIN"
echo "TAILSCALE_IP=$TAILSCALE_IP"
echo "TAILNET_HOSTS=$TAILNET_HOSTS"
  
cd "$ROOT_DIR"
docker compose up -d "$@"
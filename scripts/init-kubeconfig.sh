#!/bin/sh
# Downloads the cluster's kubeconfig from the control plane (k8s-node-1) into ./kubeconfig
# and points it at the address you give.
#
# Usage:   scripts/init-kubeconfig.sh <control-plane-address> [path-to-ssh-key]
#   - from your PC use the control plane PUBLIC IP
#   - from the Jenkins server use the control plane PRIVATE IP
# The key can also be given with the SSH_KEY environment variable.
set -e

ADDR="$1"
KEY="${2:-${SSH_KEY:-$HOME/.ssh/oeson_key}}"
OUT="${KUBECONFIG_OUT:-kubeconfig}"

if [ -z "$ADDR" ]; then
  echo "Usage: $0 <control-plane-address> [path-to-ssh-key]" >&2
  exit 1
fi

ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 "ubuntu@$ADDR" \
  "sudo cat /etc/kubernetes/admin.conf" > "$OUT"
chmod 600 "$OUT"

# admin.conf points at the control plane's private address; point it at the one we can reach
sed -i "s#server: https://.*:6443#server: https://${ADDR}:6443#" "$OUT"

echo "Wrote $OUT"
echo "Use it with:  export KUBECONFIG=$(pwd)/$OUT"

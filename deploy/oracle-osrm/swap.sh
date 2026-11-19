#!/usr/bin/env bash
# Step 1 on the Oracle VM: add a 1 GB swap file before installing Docker.
# The E2.1.Micro shape has 1 GB RAM; swap absorbs short spikes during
# apt installs and image pulls. Safe to run more than once.
#
#   sudo bash swap.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }

SWAPFILE=/swapfile
SIZE=1G

if swapon --show --noheadings | grep -q .; then
  echo "Swap already active:"; swapon --show
else
  if [ ! -f "$SWAPFILE" ]; then
    fallocate -l "$SIZE" "$SWAPFILE" || dd if=/dev/zero of="$SWAPFILE" bs=1M count=1024
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
  fi
  swapon "$SWAPFILE"
  echo "Swap enabled."
fi

# Keep it after reboots.
grep -qE "^$SWAPFILE\s" /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab

# Prefer RAM; use swap only under pressure.
echo "vm.swappiness=10" > /etc/sysctl.d/99-droobi-swap.conf
sysctl -q -p /etc/sysctl.d/99-droobi-swap.conf

free -h

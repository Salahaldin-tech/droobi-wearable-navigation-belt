#!/usr/bin/env bash
# Step 2 on the Oracle VM: open TCP 80 and 443 in the instance firewall.
#
# Oracle's Ubuntu images ship iptables rules that REJECT every inbound port
# except SSH, even when the VCN security list allows 80/443. This inserts
# ACCEPT rules above that REJECT rule, both live and in
# /etc/iptables/rules.v4 so they survive reboots. The file is edited
# directly instead of `netfilter-persistent save`, which would also store
# Docker's own rules once Docker is installed. Safe to run more than once.
#
#   sudo bash firewall.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }

PORTS=(80 443)
RULES=/etc/iptables/rules.v4

rule_args() { echo "-p tcp -m state --state NEW -m tcp --dport $1 -j ACCEPT"; }

# --- live rules -----------------------------------------------------------
for port in "${PORTS[@]}"; do
  # shellcheck disable=SC2046
  if iptables -C INPUT $(rule_args "$port") 2>/dev/null; then
    echo "live: port $port already allowed"
    continue
  fi
  reject_line=$(iptables -L INPUT --line-numbers -n | awk '$2 == "REJECT" {print $1; exit}')
  if [ -n "$reject_line" ]; then
    # shellcheck disable=SC2046
    iptables -I INPUT "$reject_line" $(rule_args "$port")
  else
    # shellcheck disable=SC2046
    iptables -A INPUT $(rule_args "$port")
  fi
  echo "live: port $port allowed"
done

# --- persistent rules -----------------------------------------------------
if [ -f "$RULES" ]; then
  [ -e "$RULES.droobi-backup" ] || cp "$RULES" "$RULES.droobi-backup"
  for port in "${PORTS[@]}"; do
    line="-A INPUT $(rule_args "$port")"
    if grep -qxF -- "$line" "$RULES"; then
      echo "saved: port $port already in $RULES"
    elif grep -q '^-A INPUT -j REJECT' "$RULES"; then
      # Insert just before the first INPUT REJECT rule.
      awk -v add="$line" '!done && /^-A INPUT -j REJECT/ {print add; done=1} {print}' "$RULES" > "$RULES.tmp"
      mv "$RULES.tmp" "$RULES"
      echo "saved: port $port added to $RULES"
    else
      echo "WARNING: no INPUT REJECT rule in $RULES; port $port not added there." >&2
    fi
  done
  iptables-restore --test < "$RULES" && echo "$RULES syntax OK"
else
  echo "WARNING: $RULES not found; live rules will not survive a reboot." >&2
fi

echo; iptables -L INPUT --line-numbers -n

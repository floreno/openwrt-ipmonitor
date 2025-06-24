#!/bin/bash

# Usage: ./ip-time-block.sh <IP_ADDRESS> <DURATION_MS>

IP="$1"
DURATION_MS="$2"
CHAIN_NAME="block_client_short"

# === Parameter prüfen ===
if [ -z "$IP" ] || [ -z "$DURATION_MS" ]; then
  echo "Usage: $0 <IP_ADDRESS> <DURATION_MS>"
  exit 1
fi

# === Dauer in Sekunden (z. B. 250ms → 0.25) umrechnen ===
DURATION_SEC=$(awk "BEGIN {printf \"%.3f\", $DURATION_MS/1000}")

# === Prüfen, ob Kette existiert ===
if ! iptables -L "$CHAIN_NAME" -n &>/dev/null; then
  echo "Erstelle Kette '$CHAIN_NAME'..."
  iptables -N "$CHAIN_NAME"
  iptables -I INPUT -j "$CHAIN_NAME"
  iptables -I FORWARD -j "$CHAIN_NAME"
fi

# === Temporär blockieren ===
echo "Blockiere IP $IP für $DURATION_MS ms..."
iptables -A "$CHAIN_NAME" -s "$IP" -j DROP

# Optional: Logging vor dem Drop aktivieren (entkommentieren)
# iptables -I "$CHAIN_NAME" -s "$IP" -j LOG --log-prefix "IP BLOCKED: "

sleep "$DURATION_SEC"

echo "Entferne Regel für IP $IP..."
iptables -D "$CHAIN_NAME" -s "$IP" -j DROP

# Optional: Loggingregel ebenfalls entfernen (wenn aktiviert)
# iptables -D "$CHAIN_NAME" -s "$IP" -j LOG --log-prefix "IP BLOCKED: "

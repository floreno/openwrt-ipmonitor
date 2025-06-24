#!/bin/sh

if [ -z "$1" ]; then
    echo "Usage: $0 <client-ip>"
    exit 1
fi

CLIENT_IP="$1"
INTERFACE="br-lan"
TMPFILE="/tmp/tcpdump_${CLIENT_IP}.log"

# ANSI-Farben
RESET="\033[0m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"

# Temp-Datei löschen
rm -f "$TMPFILE"

# tcpdump starten (falls nicht bereits läuft)
tcpdump -i "$INTERFACE" -nn 'src '"$CLIENT_IP"' and not dst net 192.168.0.0/16' 2>/dev/null | \
awk '{print $5}' | cut -d. -f1-4 >> "$TMPFILE" &

TCPDUMP_PID=$!
trap "kill $TCPDUMP_PID; rm -f $TMPFILE; exit" INT TERM

while true; do
    clear
    echo "Live-Ziel-IPs für Client $CLIENT_IP"
    echo "Zeit: $(date)"
    echo "--------------------------------------------------------------------------------------------------------------"
    printf "%-4s %-15s %-30s %-25s %-30s %-3s\n" "Cnt" "IP" "Hostname" "Ort, Region" "Organisation" "L"
    echo "--------------------------------------------------------------------------------------------------------------"

    sort "$TMPFILE" | uniq -c | sort -nr | head -n 10 | while read COUNT IP; do
        # Hostname auflösen
        HOST=$(nslookup "$IP" 2>/dev/null \
               | awk -F'= ' '/name =/ {print $2}' \
               | sed 's/\.$//;s/[\r\n]//g')
        [ -z "$HOST" ] && HOST="-"

        # auf letzte 30 Zeichen kürzen mit „…“
        HOSTLEN=$(printf "%s" "$HOST" | wc -c)
        if [ "$HOSTLEN" -gt 30 ]; then
            HOST="…$(printf "%s" "$HOST" | tail -c 30)"
        fi

        # Geo-Daten von ipinfo.io JSON-API
        GEO=$(wget -qO- "https://ipinfo.io/$IP/json")
        CITY=$(echo "$GEO" | grep '"city"'    | cut -d\" -f4)
        REGION=$(echo "$GEO" | grep '"region"'| cut -d\" -f4)
        COUNTRY=$(echo "$GEO" | grep '"country"'| cut -d\" -f4)
        ORG=$(echo "$GEO" | grep '"org"'      | cut -d\" -f4)

        [ -z "$CITY" ]    && CITY="-"
        [ -z "$REGION" ]  && REGION="-"
        [ -z "$COUNTRY" ] && COUNTRY="??"
        [ -z "$ORG" ]     && ORG="-"

        # Organisation ggf. kürzen
        ORGLEN=$(printf "%s" "$ORG" | wc -c)
        if [ "$ORGLEN" -gt 30 ]; then
            ORG="…$(printf "%s" "$ORG" | tail -c 30)"
        fi

        # Ausgabe
        printf "%-4s ${YELLOW}%-15s${RESET} ${GREEN}%-30s${RESET} ${BLUE}%-25s${RESET} ${CYAN}%-30s${RESET} ${MAGENTA}%-3s${RESET}\n" \
            "$COUNT" "$IP" "$HOST" "$CITY, $REGION" "$ORG" "$COUNTRY"
    done

    echo "--------------------------------------------------------------------------------------------------------------"
    sleep 10
done

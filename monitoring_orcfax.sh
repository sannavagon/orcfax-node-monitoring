#!/bin/bash

# Determine if a specific hour, a full day, or the last hour is requested
if [ -z "$1" ]; then
    FECHA=$(date +"%Y-%m-%d")
    HORA=$(date -d '1 hour ago' +"%H")
    MODO="hora"
elif [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    FECHA=$1
    if [ -n "$2" ] && [[ $2 =~ ^[0-9]{2}$ ]]; then
        HORA=$2
        MODO="hora"
    else
        MODO="dia"
    fi
else
    echo "❌ Incorrect format. Use: ./monitoreo_orcfax.sh [YYYY-MM-DD] [HH]"
    exit 1
fi

# Define the time range for `journalctl`
if [ "$MODO" = "hora" ]; then
    SINCE="${FECHA} ${HORA}:00:00"
    UNTIL="${FECHA} ${HORA}:59:59"
    echo " Hourly summary (${HORA}:00 - ${HORA}:59 on ${FECHA}):"
else
    SINCE="${FECHA} 00:00:00"
    UNTIL="${FECHA} 23:59:59"
    echo " Full day summary (${FECHA}):"
fi
echo ""

# Get logs from `journalctl` according to the time range
LOGS=$(journalctl -u orcfax-collector.service --since "$SINCE" --until "$UNTIL" --no-pager 2>/dev/null)

# Count errors, excluding irrelevant messages
ERRORES=$(echo "$LOGS" | grep "ERROR ::" | grep -v "websocket response: OK" | grep -v "websocket wait_for resp timeout" | wc -l)
echo " Errors found: $ERRORES"
echo ""

# Show unique error types
if [ "$ERRORES" -gt 0 ]; then
    echo " Types of errors found:"
    echo "$LOGS" | grep "ERROR ::" | grep -v "websocket response: OK" | grep -v "websocket wait_for resp timeout" | awk -F"::" '{print $3}' | sort | uniq -c | sort -nr
    echo ""
else
    echo " No errors found."
    echo ""
fi

# Count connections to CEXs
echo " CEX connections per pair:"
printf "| %-7s | %-17s |\n" "Pair" "Total Requests"
echo "|---------|------------------|"

for PAR in "ADA/USD" "ADA/BTC" "BTC/USD"; do
    TOTAL_SOLICITUDES=$(echo "$LOGS" | grep "compiled URL for $PAR" | wc -l)
    printf "| %-7s | %-17s |\n" "$PAR" "$TOTAL_SOLICITUDES"
done
echo ""

# Show CEX responses per pair
mostrar_respuestas_cex() {
    PAR=$1
    echo "✅ $PAR:"
    echo "-----------------------------------------"
    echo "$LOGS" | grep "compiled URL for $PAR" | awk -F' ' '{print $NF}' | awk -F'/' '{print $3}' | sort | uniq -c | while read RESPUESTAS CEX; do
        TOTAL_SOLICITUDES=$(echo "$LOGS" | grep "compiled URL for $PAR" | grep "$CEX" | wc -l)
        SIN_RESPUESTA=$((TOTAL_SOLICITUDES - RESPUESTAS))
        printf "    %-4s %-40s Total: %-4s | No Response: %-4s\n" "$RESPUESTAS" "$CEX" "$TOTAL_SOLICITUDES" "$SIN_RESPUESTA"
    done
    echo "-----------------------------------------"
    echo ""
}

echo " CEX responses for each pair:"
for PAR in "ADA/USD" "ADA/BTC" "BTC/USD"; do
    mostrar_respuestas_cex "$PAR"
done

# Validator connections
VALIDADOR_OK=$(echo "$LOGS" | grep "websocket response: OK" | wc -l)
VALIDADOR_FAIL=$(echo "$LOGS" | grep "websocket wait_for resp timeout" | wc -l)
TOTAL_ENVIOS=$(echo "$LOGS" | grep "sending message" | wc -l)

if [ "$TOTAL_ENVIOS" -eq 0 ]; then
    PORCENTAJE_EXITO=0
else
    PORCENTAJE_EXITO=$((VALIDADOR_OK * 100 / TOTAL_ENVIOS))
fi

# Get count of OK responses per pair
echo " Validator connections:"
echo "✅ Successful: $VALIDADOR_OK"
echo "❌ Failed: $VALIDADOR_FAIL"
echo " Total messages sent: $TOTAL_ENVIOS"
echo " Success percentage: $PORCENTAJE_EXITO%"

echo ""
echo " OK responses per pair:"
echo "$LOGS" | grep "websocket response: OK (" | awk -F"OK \\(" '{print $2}' | awk -F"\\)" '{print $1}' | sort | uniq -c

echo ""

# Count OK responses from the validator in the same minute
MULTIPLES_PARES=$(echo "$LOGS" | grep "websocket response: OK" | awk '{print $1, $2, $3}' | uniq -c | awk '$1>1' | wc -l)
echo " Times the validator responded OK more than once in the same minute: $MULTIPLES_PARES"
echo ""

# Count service restarts
STARTED_COUNT=$(echo "$LOGS" | grep "Started orcfax-collector.service" | wc -l)
STOPPED_COUNT=$(echo "$LOGS" | grep "Deactivated successfully" | wc -l)

echo " Service started times: $STARTED_COUNT"
echo " Service stopped times: $STOPPED_COUNT"

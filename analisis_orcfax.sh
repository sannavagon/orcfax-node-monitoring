#!/bin/bash

# Determine if a specific hour, a full day, or the last hour is requested
if [ -z "$1" ]; then
    DATE=$(date +"%Y-%m-%d")
    HOUR=$(date -d '1 hour ago' +"%H")
    MODE="hour"
elif [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    DATE=$1
    if [ -n "$2" ] && [[ $2 =~ ^[0-9]{2}$ ]]; then
        HOUR=$2
        MODE="hour"
    else
        MODE="day"
    fi
else
    echo "❌ Incorrect format. Use: ./monitoring_orcfax.sh [YYYY-MM-DD] [HH]"
    exit 1
fi

# Define the time range for journalctl
if [ "$MODE" = "hour" ]; then
    SINCE="${DATE} ${HOUR}:00:00"
    UNTIL="${DATE} ${HOUR}:59:59"
    echo "Hourly summary (${HOUR}:00 - ${HOUR}:59 on ${DATE}):"
else
    SINCE="${DATE} 00:00:00"
    UNTIL="${DATE} 23:59:59"
    echo "Full day summary (${DATE}):"
fi
echo ""

# Get journalctl logs for the specified time range
LOGS=$(journalctl -u orcfax-collector.service --since "$SINCE" --until "$UNTIL" --no-pager 2>/dev/null)

# Initialize counters for total messages and types of errors
TOTAL_OK=0
TOTAL_TIMEOUT=0
TOTAL_MULTIPLE_OK=0
TOTAL_MULTIPLE_TIMEOUT=0
TOTAL_OK_AND_TIMEOUT=0 # New counter for OK and timeout in the same minute
TOTAL_BLANKS=0
TOTAL_MESSAGES=0

# Count timeout errors, excluding irrelevant messages
TIMEOUT_ERRORS=$(echo "$LOGS" | grep "ERROR ::" | grep "wait_for resp timeout" | wc -l)
echo "Timeout errors found: $TIMEOUT_ERRORS"
echo ""

# Display types of timeout errors
if [ "$TIMEOUT_ERRORS" -gt 0 ]; then
    echo "Types of timeout errors found:"
    echo "$LOGS" | grep "ERROR ::" | grep "wait_for resp timeout" | awk -F"::" '{print $3}' | sort | uniq -c | sort -nr
    echo ""
else
    echo "No timeout errors found."
    echo ""
fi

# Count other types of errors
WEBSOCKET_ERRORS=$(echo "$LOGS" | grep "ERROR ::" | grep "websocket response: OK" | wc -l)
OTHER_ERRORS=$(echo "$LOGS" | grep "ERROR ::" | grep -v "wait_for resp timeout" | grep -v "websocket response: OK" | wc -l)
echo "Other errors found: $((WEBSOCKET_ERRORS + OTHER_ERRORS))"
echo ""

# Display types of other errors
if [ "$WEBSOCKET_ERRORS" -gt 0 ] || [ "$OTHER_ERRORS" -gt 0 ]; then
    echo "Types of other errors found:"
    if [ "$WEBSOCKET_ERRORS" -gt 0 ]; then
        echo "$LOGS" | grep "ERROR ::" | grep "websocket response: OK" | awk -F"::" '{print $3}' | sort | uniq -c | sort -nr
    fi
    if [ "$OTHER_ERRORS" -gt 0 ]; then
        echo "$LOGS" | grep "ERROR ::" | grep -v "wait_for resp timeout" | grep -v "websocket response: OK" | awk -F"::" '{print $3}' | sort | uniq -c | sort -nr
    fi
    echo ""
else
    echo "No other errors found."
    echo ""
fi

# Count connections to CEXs per minute
echo "Connections to CEXs per pair per minute:"

for PAIR in "ADA/USD" "ADA/BTC" "BTC/USD"; do
    echo "Pair: $PAIR"
    echo "-----------------------------------------"

    # Extract timestamps and count requests per minute
    journalctl -u orcfax-collector.service --since "$SINCE" --until "$UNTIL" --no-pager 2>/dev/null |
        grep "compiled URL for $PAIR" |
        awk '{print substr($1, 1, 16)}' | # Extract EPOCH-MM-DD HH:MM
        sort | uniq -c | sort -nr

    echo "-----------------------------------------"
done

# Display responses from CEXs per pair
show_cex_responses() {
    PAIR=$1
    echo "✅ $PAIR:"
    echo "-----------------------------------------"
    echo "$LOGS" | grep "compiled URL for $PAIR" | awk -F' ' '{print $NF}' | awk -F'/' '{print $3}' | sort | uniq -c | while read RESPONSES CEX; do
        TOTAL_REQUESTS=$(echo "$LOGS" | grep "compiled URL for $PAIR" | grep "$CEX" | wc -l)
        NO_RESPONSE=$((TOTAL_REQUESTS - RESPONSES))
        printf "    %-4s %-40s Total: %-4s | No Response: %-4s\n" "$RESPONSES" "$CEX" "$TOTAL_REQUESTS" "$NO_RESPONSE"
    done
    echo "-----------------------------------------"
    echo ""
}

echo "Responses from CEXs per pair:"
for PAIR in "ADA/USD" "ADA/BTC" "BTC/USD"; do
    show_cex_responses "$PAIR"
done

# Validator connections
VALIDATOR_OK=$(echo "$LOGS" | grep "websocket response: OK" | wc -l)
VALIDATOR_FAIL=$(echo "$LOGS" | grep "wait_for resp timeout" | wc -l)
TOTAL_SENT=$((VALIDATOR_OK + VALIDATOR_FAIL))

if [ "$TOTAL_SENT" -eq 0 ]; then
    SUCCESS_RATE=0
else
    SUCCESS_RATE=$((VALIDATOR_OK * 100 / TOTAL_SENT))
fi

# Display validator connection details
echo "Validator connections:"
echo "✅ Successful: $VALIDATOR_OK"
echo "❌ Failed: $VALIDATOR_FAIL"
echo "Total messages sent: $TOTAL_SENT"
echo "Success rate: $SUCCESS_RATE%"

echo ""
echo "OK responses by pair:"
echo "$LOGS" | grep "websocket response: OK (" | awk -F"OK \\(" '{print $2}' | awk -F"\\)" '{print $1}' | sort | uniq -c

echo ""

# Count OK responses from the validator in the same minute for multiple pairs
echo "Pairs that overlapped in the same minute:"

journalctl -u orcfax-collector.service --since "$SINCE" --until "$UNTIL" --no-pager 2>/dev/null |
    grep "websocket response: OK" |
    awk '{print substr($1, 1, 16), $NF}' | # Extract EPOCH-MM-DD HH:MM and pair
    sort | uniq |
    awk '{pairs[$1] = pairs[$1] ? pairs[$1] "," $2 : $2} END {for (minute in pairs) {split(pairs[minute], arr, ","); if (length(arr) > 1) {print minute ": " pairs[minute]}}}' | sort

# Detailed visualization of the validation grid
echo "Validation grid by minute and pair (last hour):"
echo "Minute               ADA/USD   ADA/BTC   BTC/USD"

# Get the minutes of the last hour
MINUTES=$(seq 0 59)

# Get validation logs for the last hour
VALIDATIONS=$(journalctl -u orcfax-collector.service --since "$SINCE" --until "$UNTIL" --no-pager 2>/dev/null | grep "websocket response\|wait_for resp timeout")

# Create the grid and count totals from the logs
for MINUTE in $MINUTES; do
    TIMESTAMP="${DATE} ${HOUR}:$(printf "%02d" $MINUTE)"
    echo -n "$TIMESTAMP: " # Display the timestamp of the minute

    for PAIR in "ADA-USD" "ADA-BTC" "BTC-USD"; do
        VALIDATION_PAIR=$(echo "$VALIDATIONS" | grep "$TIMESTAMP" | grep "$PAIR")

        if [[ -n "$VALIDATION_PAIR" ]]; then
            SUCCESSFUL=$(echo "$VALIDATION_PAIR" | grep "OK (" | wc -l)
            FAILED=$(echo "$VALIDATION_PAIR" | grep "wait_for resp timeout" | wc -l)

            if [[ "$SUCCESSFUL" -gt 0 && "$FAILED" -gt 0 ]]; then
                echo -n "$(tput setaf 5)🟪$(tput sgr0)" # Purple for both OK and timeout
                TOTAL_OK_AND_TIMEOUT=$((TOTAL_OK_AND_TIMEOUT + 1))
                TOTAL_MESSAGES=$((TOTAL_MESSAGES + 2))
            elif [[ "$FAILED" -gt 1 ]]; then
                echo -n "$(tput setaf 4)🟦$(tput sgr0)" # Blue for more than one timeout
                TOTAL_MULTIPLE_TIMEOUT=$((TOTAL_MULTIPLE_TIMEOUT + 1))
                TOTAL_MESSAGES=$((TOTAL_MESSAGES + 2))
            elif [[ "$FAILED" -gt 0 ]]; then
                echo -n "$(tput setaf 1)🟥$(tput sgr0)" # Red for one timeout
                TOTAL_TIMEOUT=$((TOTAL_TIMEOUT + 1))
                TOTAL_MESSAGES=$((TOTAL_MESSAGES + 1))
            elif [[ "$SUCCESSFUL" -gt 1 ]]; then
                echo -n "$(tput setaf 3)🟧$(tput sgr0)" # Orange for more than one successful in the same minute
                TOTAL_MULTIPLE_OK=$((TOTAL_MULTIPLE_OK + 1))
                TOTAL_MESSAGES=$((TOTAL_MESSAGES + 2))
            elif [[ "$SUCCESSFUL" -gt 0 ]]; then
                echo -n "$(tput setaf 2)🟩$(tput sgr0)" # Green for one successful
                TOTAL_OK=$((TOTAL_OK + 1))
                TOTAL_MESSAGES=$((TOTAL_MESSAGES + 1))
            else
                echo -n "⬜" # White for no validations
                TOTAL_BLANKS=$((TOTAL_BLANKS + 1))
            fi
        else
            echo -n "⬜" # White for no validations
            TOTAL_BLANKS=$((TOTAL_BLANKS + 1))
        fi
        echo -n "   " # Space between columns
    done

    echo "" # New line for the next minute
done

# Legend
echo ""
echo "Legend:"
echo "🟩 Green: OK response from the validator"
echo "🟧 Orange: More than one successful communication in the same minute"
echo "🟥 Red: Timeout error"
echo "🟦 Blue: More than one timeout error in the same minute"
echo "🟪 Purple: Both OK and timeout in the same minute"
echo "⬜ White: No activity in the minute"

# Display total counts for validation types
echo ""
echo "Total OK responses (Green): $TOTAL_OK"
echo "Total multiple OK responses (Orange): $TOTAL_MULTIPLE_OK"
echo "Total timeout errors (Red): $TOTAL_TIMEOUT"
echo "Total multiple timeout errors (Blue): $TOTAL_MULTIPLE_TIMEOUT"
echo "Total OK and timeout responses (Purple): $TOTAL_OK_AND_TIMEOUT"
echo "Total no activity (White): $TOTAL_BLANKS"
echo "Total messages processed: $((TOTAL_OK + TOTAL_TIMEOUT + TOTAL_MULTIPLE_OK + TOTAL_MULTIPLE_TIMEOUT + TOTAL_OK_AND_TIMEOUT)) (should match Total messages sent)"

# Count service restarts
STARTED_COUNT=$(echo "$LOGS" | grep "Started orcfax-collector.service" | wc -l)
STOPPED_COUNT=$(echo "$LOGS" | grep "Deactivated successfully" | wc -l)

echo "Service started: $STARTED_COUNT times"
echo "Service stopped: $STOPPED_COUNT times"

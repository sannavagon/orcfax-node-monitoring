#!/bin/bash

# --- Range selection ---
if [ $# -eq 0 ]; then
   SINCE="1 hour ago"
   RANGE_LABEL=$(date -d "1 hour ago" '+%Y-%m-%d %H:00-%H:59')
   journalctl --since="$SINCE" -o cat > /tmp/orcfaxlog.txt
elif [ $# -eq 2 ]; then
   DAY="$1"
   HOUR="$2"
   SINCE="$DAY $HOUR:00:00"
   UNTIL="$DAY $HOUR:59:59"
   RANGE_LABEL="$DAY $HOUR:00-$HOUR:59"
   journalctl --since="$SINCE" --until="$UNTIL" -o cat > /tmp/orcfaxlog.txt
elif [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
   DAY="$1"
   SINCE="$DAY 00:00:00"
   UNTIL="$DAY 23:59:59"
   RANGE_LABEL="$DAY 00:00-23:59"
   journalctl --since="$SINCE" --until="$UNTIL" -o cat > /tmp/orcfaxlog.txt
elif [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}$ ]]; then
   DAY=$(echo "$1" | cut -d' ' -f1)
   HOUR=$(echo "$1" | cut -d' ' -f2)
   SINCE="$DAY $HOUR:00:00"
   UNTIL="$DAY $HOUR:59:59"
   RANGE_LABEL="$DAY $HOUR:00-$HOUR:59"
   journalctl --since="$SINCE" --until="$UNTIL" -o cat > /tmp/orcfaxlog.txt
else
   echo "Usage:"
   echo "     $0                # last hour"
   echo "     $0 YYYY-MM-DD     # full day"
   echo "     $0 YYYY-MM-DD HH  # one hour (two arguments)"
   echo "     $0 'YYYY-MM-DD HH' # one hour (one argument, in quotes)"
   exit 1
fi

echo "Log summary for: $RANGE_LABEL"
echo

awk '
BEGIN {
   cycle=0
   signed=0
   ok=0
   timeout=0
   err_validator=0
   err_python=0
   err_other=0
   example_timeout=""
   example_validator=""
   example_python=""
   example_other=""
   info_count=0
}
  /Starting orcfax-collector-once.service/ {
   if (cycle>0) {
     # Clasificación PRIORITARIA:
     if (timeout_in_cycle) {
       timeout++
       if (example_timeout=="") example_timeout=timeout_msg
     } else if (validatorerr_in_cycle) {
       err_validator++
       if (example_validator=="") example_validator=validator_msg
     } else if (pythonerr_in_cycle) {
       err_python++
       if (example_python=="") example_python=python_msg
     } else if (othererr_in_cycle) {
       err_other++
       if (example_other=="") example_other=other_msg
     } else if (signed_in_cycle) {
       ok++
     }
   }
   cycle++
   signed_in_cycle=0
   timeout_in_cycle=0
   validatorerr_in_cycle=0
   pythonerr_in_cycle=0
   othererr_in_cycle=0
   timeout_msg=""
   validator_msg=""
   python_msg=""
   other_msg=""
   next
}
{
   if ($0 ~ /sign_with_key\(\)/) signed_in_cycle=1
   if (tolower($0) ~ /timeout for feeds/) {
     timeout_in_cycle=1
     if (example_timeout=="") timeout_msg=$0
   }
   if ($0 ~ /unexpected response status code from
validator|send_data_to_validator/) {
     validatorerr_in_cycle=1
     if (example_validator=="") validator_msg=$0
   }
   if ($0 ~ /Error parsing|Error retrieving/) {
     pythonerr_in_cycle=1
     if (example_python=="") python_msg=$0
   }
   # Solo otros errores del collector:
   if (($0 ~ /error|ERROR|\[ERROR\]|exception/) && \
       !validatorerr_in_cycle && !pythonerr_in_cycle &&
!timeout_in_cycle && \
       ($0 ~ /\.py|collector/)) {
     othererr_in_cycle=1
     if (example_other=="") other_msg=$0
   }
   # Errores informativos de otros procesos (no collector)
   if (($0 ~ /error|ERROR|\[ERROR\]|exception/) && \
       !validatorerr_in_cycle && !pythonerr_in_cycle &&
!timeout_in_cycle && !othererr_in_cycle && \
       !($0 ~ /\.py|collector/)) {
     info_msg[info_count]=$0
     info_count++
   }
}
END {
   if (cycle>0) {
     if (timeout_in_cycle) {
       timeout++
       if (example_timeout=="") example_timeout=timeout_msg
     } else if (validatorerr_in_cycle) {
       err_validator++
       if (example_validator=="") example_validator=validator_msg
     } else if (pythonerr_in_cycle) {
       err_python++
       if (example_python=="") example_python=python_msg
     } else if (othererr_in_cycle) {
       err_other++
       if (example_other=="") example_other=other_msg
     } else if (signed_in_cycle) {
       ok++
     }
   }
   print "Summary:"
   print "     Total cycles:", cycle
   print "     Successful cycles (signed, no errors):", ok
   print "     Timeout cycles:", timeout
   print "     Validator error cycles:", err_validator
   print "     Python error cycles:", err_python
   print "     Other error cycles (collector only):", err_other
   print ""
   print "Error types by affected cycles:"
   if (timeout > 0) print "     Timeout:",timeout,"(Example: "
example_timeout ")"
   if (err_validator > 0) print " Validator:",err_validator,"(Example: "
example_validator ")"
   if (err_python > 0) print " Python:",err_python,"(Example: "
example_python ")"
   if (err_other > 0) print "     Other
(collector):",err_other,"(Example: " example_other ")"
   if (info_count > 0) {
     print ""
     print "Informative errors from other processes (ignored for node
health and restart):"
     for (k=0;k<info_count;k++) {
       print "     - " info_msg[k]
       if (k==4 && info_count>5) { print "     ... and more
("info_count" total)"; break }
     }
   }
}
' /tmp/orcfaxlog.txt

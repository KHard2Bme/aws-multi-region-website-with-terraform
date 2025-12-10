#!/bin/bash

# ============================================================
#  CloudFront Failover Automated Test Script
# ============================================================
# Continuously curls the CloudFront endpoint and identifies:
#   - Which AZ is serving content (primary region)
#   - Whether failover to secondary region occurs
#   - Whether 5xx errors appear (CloudFront alarm trigger)
#
# Output is printed live + saved to failover.log
# ============================================================

CF_DOMAIN="$1"
INTERVAL=2   # seconds between checks
LOG_FILE="failover.log"

if [ -z "$CF_DOMAIN" ]; then
  echo "Usage: ./failover-test.sh <cloudfront-domain>"
  exit 1
fi

echo "============================================================" | tee -a $LOG_FILE
echo " CloudFront Failover Test Started" | tee -a $LOG_FILE
echo " Target: https://$CF_DOMAIN" | tee -a $LOG_FILE
echo " Logging to: $LOG_FILE" | tee -a $LOG_FILE
echo "============================================================" | tee -a $LOG_FILE

while true; do
    RESPONSE=$(curl -s --max-time 3 https://$CF_DOMAIN)
    STATUS=$?

    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    if [ $STATUS -ne 0 ]; then
        echo -e "[$TIMESTAMP] ❌ ERROR: No response (timeout or connection issue)" | tee -a $LOG_FILE
        sleep $INTERVAL
        continue
    fi

    # Detect which backend served the request based on index.html content
    if echo "$RESPONSE" | grep -q "PRIMARY REGION – AZ 0"; then
        ORIGIN="Primary Region (AZ 1)"
        COLOR="\033[1;32m"   # green
    elif echo "$RESPONSE" | grep -q "PRIMARY REGION – AZ 1"; then
        ORIGIN="Primary Region (AZ 2)"
        COLOR="\033[1;32m"
    elif echo "$RESPONSE" | grep -q "SECONDARY REGION FAILOVER"; then
        ORIGIN="Secondary Region Failover"
        COLOR="\033[1;33m"   # yellow
    elif echo "$RESPONSE" | grep -q "<h1>"; then
        ORIGIN="Primary Region (AZ unknown)"
        COLOR="\033[1;32m"   # green fallback for any valid page
    else
        ORIGIN="Unexpected response / Possibly 5xx"
        COLOR="\033[1;31m"   # red
    fi

    # Show output
    echo -e "[$TIMESTAMP] Origin: ${COLOR}${ORIGIN}\033[0m" | tee -a $LOG_FILE

    sleep $INTERVAL
done


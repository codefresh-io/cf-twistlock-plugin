#!/bin/sh
set -e

msg() { echo -e "INF---> $1"; }
err() { echo -e "ERR---> $1" ; exit 1; }

printenv
JSON_PAYLOAD={\"tag\":{\"registry\":\"$TL_REGISTRY\",\"repo\":\"$TL_IMAGE_NAME\",\"tag\":\"$TL_IMAGE_TAG\"}}
echo $JSON_PAYLOAD

curl -X POST -k \
  -u $TL_CONSOLE_USERNAME:$TL_CONSOLE_PASSWORD \
  -H 'Content-Type: application/json' \
  -d $JSON_PAYLOAD https://$TL_CONSOLE_HOSTNAME:$TL_CONSOLE_PORT/api/v1/registry/scan

until [ "$SCAN_FINISH_STATUS" = "completed" ]; do 
  sleep 2
  scan_current_status=$(curl -X GET -k -s -u $TL_CONSOLE_USERNAME:$TL_CONSOLE_PASSWORD -G https://$TL_CONSOLE_HOSTNAME:$TL_CONSOLE_PORT/api/v1/registry -d search=$TL_IMAGE_NAME:$TL_IMAGE_TAG -d limit=1 | cut -c5-6)
  if [ "$scan_current_status" = id ]; then  
    SCAN_FINISH_STATUS="completed"
    echo "Scan completed"
  else
    SCAN_FINISH_STATUS="Running scan"
    echo $SCAN_FINISH_STATUS
  fi
done

REPORT_NAME=$(echo ''$TL_IMAGE_NAME:$TL_IMAGE_TAG | tr /: _)
curl -X GET -ks -u $TL_CONSOLE_USERNAME:$TL_CONSOLE_PASSWORD -G https://$TL_CONSOLE_HOSTNAME:$TL_CONSOLE_PORT/api/v1/registry -d search=$TL_IMAGE_NAME:$TL_IMAGE_TAG -d limit=1 -o TL_report_$REPORT_NAME.json
echo "Report Downloaded"

COMPLIANCE_ISSUES=$(cat TL_report_$REPORT_NAME.json | jq ".[0].info.complianceDistribution.$TL_COMPLIANCE_THRESHOLD")
CVEVULNERABILITY_ISSUES=$(cat TL_report_$REPORT_NAME.json | jq ".[0].info.cveVulnerabilityDistribution.$TL_VULNERABILITY_THRESHOLD")
if [ $COMPLIANCE_ISSUES -gt 0 ]; then 
  echo "COMPLIANCE_THRESHOLD EXEECED = $COMPLIANCE_ISSUES $TL_COMPLIANCE_THRESHOLD-severity issue(s) found"
  exit 1
else
  echo "COMPLIANCE CHECK=PASSED"
fi
if [ $CVEVULNERABILITY_ISSUES -gt 0 ]; then 
  echo "VULNERABILITY_THRESHOLD EXEECED = $CVEVULNERABILITY_ISSUES $VULNERABILITY_THRESHOLD-severity issue(s) found"
  exit 1
else 
  echo "CVEVULNERABILITY CHECK=PASSED"
fi


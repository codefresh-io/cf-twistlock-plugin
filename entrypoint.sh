#!/bin/sh
set -e

msg() { echo -e "INF---> $1"; }
err() { echo -e "ERR---> $1" ; exit 1; }

JSON_PAYLOAD={\"tag\":{\"registry\":\"$TL_REGISTRY\",\"repo\":\"$TL_IMAGE_NAME\",\"tag\":\"$TL_IMAGE_TAG\"}}
SETTINGS=$(echo $JSON_PAYLOAD | jq ".tag" )
msg "Settings used:\n$SETTINGS"

curl -X POST -k -s \
  -u $TL_CONSOLE_USERNAME:$TL_CONSOLE_PASSWORD \
  -H 'Content-Type: application/json' \
  -d $JSON_PAYLOAD https://$TL_CONSOLE_HOSTNAME:$TL_CONSOLE_PORT/api/v1/registry/scan

msg "Security Scan initiated"
TIMEOUT_SECS=$((1 * 60))
until [[ "$SCAN_FINISH_STATUS" = "completed" ]] || [[ $TIMEOUT_SECS -lt 0 ]]; do
  sleep 2
  TIMEOUT_SECS=$((TIMEOUT_SECS-2))
  scan_current_status=$(curl -X GET -k -s -u $TL_CONSOLE_USERNAME:$TL_CONSOLE_PASSWORD -G https://$TL_CONSOLE_HOSTNAME:$TL_CONSOLE_PORT/api/v1/registry -d search=$TL_IMAGE_NAME:$TL_IMAGE_TAG -d limit=1 | cut -c5-6)
  if [ "$scan_current_status" = id ]; then  
    SCAN_FINISH_STATUS="completed"
    msg "Scan completed"
  elif [ "$scan_current_status" = '' ]; then  
    SCAN_FINISH_STATUS="Running scan"
    msg "$SCAN_FINISH_STATUS"
  else
    err $scan_current_status
  fi
done

if [ $TIMEOUT_SECS -le 2 ]; then 
  err "Timeout while trying to scan the image, or image was not found in registry"
fi

REPORT_NAME=$(echo ''$TL_IMAGE_NAME:$TL_IMAGE_TAG | tr /: _)
curl -X GET -ks -u $TL_CONSOLE_USERNAME:$TL_CONSOLE_PASSWORD -G https://$TL_CONSOLE_HOSTNAME:$TL_CONSOLE_PORT/api/v1/registry -d search=$TL_IMAGE_NAME:$TL_IMAGE_TAG -d limit=1 -o TL_report_$REPORT_NAME.json
msg "Report Downloaded to $(pwd)/TL_report_$REPORT_NAME.json"

COMPLIANCE_RISK_SCORE=$(cat TL_report_$REPORT_NAME.json | jq ".[0].info.complianceRiskScore")
VULNERABILITY_RISK_SCORE=$(cat TL_report_$REPORT_NAME.json | jq ".[0].info.vulnerabilityRiskScore")
COMPLIANCE_VULNERABILITIES_CNT=$(cat TL_report_$REPORT_NAME.json | jq ".[0].info.complianceVulnerabilitiesCnt")
CVE_VULNERABILITIES_CNT=$(cat TL_report_$REPORT_NAME.json | jq ".[0].info.cveVulnerabilitiesCnt")


case $TL_COMPLIANCE_THRESHOLD in
     low)      
          TL_COMPLIANCE_THRESHOLD=1
          ;;
     medium)      
          TL_COMPLIANCE_THRESHOLD=10
          ;;
     high)
          TL_COMPLIANCE_THRESHOLD=100
          ;; 
     critical)
          TL_COMPLIANCE_THRESHOLD=1000
          ;;
     *)
          echo TL_COMPLIANCE_THRESHOLD must be low|medium|high|critical
          ;;
esac

case $TL_VULNERABILITY_THRESHOLD in
     low)      
          TL_VULNERABILITY_THRESHOLD=1
          ;;
     medium)      
          TL_VULNERABILITY_THRESHOLD=10
          ;;
     high)
          TL_VULNERABILITY_THRESHOLD=100
          ;; 
     critical)
          TL_VULNERABILITY_THRESHOLD=1000
          ;;
     *)
          echo TL_VULNERABILITY_THRESHOLD must be low|medium|high|critical
          ;;
esac

if [ $COMPLIANCE_RISK_SCORE -ge $TL_COMPLIANCE_THRESHOLD ]; then 
  err "COMPLIANCE_THRESHOLD ($TL_COMPLIANCE_THRESHOLD) EXEECED => $COMPLIANCE_VULNERABILITIES_CNT issue(s) found. COMPLIANCE_RISK_SCORE = $COMPLIANCE_RISK_SCORE (lower is better)"
else
  msg "COMPLIANCE CHECK => PASSED"
fi
if [ $VULNERABILITY_RISK_SCORE -ge $TL_VULNERABILITY_THRESHOLD ]; then 
  err "VULNERABILITY_THRESHOLD ($TL_VULNERABILITY_THRESHOLD) EXEECED => $CVE_VULNERABILITIES_CNT issue(s) found. VULNERABILITY_RISK_SCORE = $VULNERABILITY_RISK_SCORE (lower is better)"
else 
  msg "CVEVULNERABILITY CHECK => PASSED"
fi


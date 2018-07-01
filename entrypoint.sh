#!/bin/sh
set -e

msg() { echo -e "INF---> $1"; }
err() { echo -e "ERR---> $1" ; exit 1; }

echo "This is the entrypoint-script inside a Container!"
printenv
JSON_PAYLOAD={\"tag\":{\"registry\":\"docker.io\",\"repo\":\"$TL_REPO_NAME/$TL_IMAGE_NAME\",\"tag\":\"$TL_IMAGE_TAG\"}}
echo $JSON_PAYLOAD

curl -X POST -k \
  -u $TL_CONSOLE_USERNAME:$TL_CONSOLE_PASSWORD \
  -H 'Content-Type: application/json' \
  -d $JSON_PAYLOAD https://$TL_CONSOLE_HOSTNAME:$TL_CONSOLE_PORT/api/v1/registry/scan

echo "END"


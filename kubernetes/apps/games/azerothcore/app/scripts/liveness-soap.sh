#!/usr/bin/env bash
# worldserver liveness probe: an open TCP socket is not proof of life — a hung
# world loop (deadlock, runaway tick) keeps port 8085 accepting while the
# realm is effectively dead. SOAP command execution goes through the world
# update loop, so a well-formed `server info` response proves the loop is
# still turning.
#
# Timings are deliberately conservative (helmrelease: periodSeconds 60,
# failureThreshold 5, plus the 15s curl budget here): a lag spike from a mass
# bot login must never restart a healthy server. A liveness kill still runs
# the preStop countdown first; against a truly hung server that SOAP call
# fails fast and the plain SIGTERM path proceeds.
set -uo pipefail

resp="$(curl -s --max-time 15 \
  -u "${SOAP_USERNAME}:${SOAP_PASSWORD}" \
  -H "Content-Type: text/xml" \
  --data-binary @- \
  "http://127.0.0.1:7878/" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:AC">
  <SOAP-ENV:Body><ns1:executeCommand><command>server info</command></ns1:executeCommand></SOAP-ENV:Body>
</SOAP-ENV:Envelope>
EOF
)" || { echo "liveness: SOAP request failed (world loop hung or SOAP down)"; exit 1; }

# Same sentinel the preStop hook parses — present in every `server info`
# response on this fork (WP10-verified).
grep -q "Connected players" <<< "${resp}" || {
  echo "liveness: SOAP responded without 'Connected players' — unexpected payload"
  exit 1
}
exit 0

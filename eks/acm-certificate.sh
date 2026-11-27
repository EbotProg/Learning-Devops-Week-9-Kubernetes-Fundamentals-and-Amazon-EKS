#!/usr/bin/env bash
# Requests a free TLS certificate for w9.ebotprog.ink from ACM and validates it
# automatically through Route 53 (adds the CNAME ACM asks for, then waits).
set -euo pipefail
REGION=eu-north-1; ROOT=ebotprog.ink; HOST=w9.ebotprog.ink

ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$ROOT" \
  --query "HostedZones[?Name=='${ROOT}.'].Id | [0]" --output text | cut -d/ -f3)
[ "$ZONE_ID" != "None" ] && [ -n "$ZONE_ID" ] || { echo "No Route 53 hosted zone for $ROOT"; exit 1; }
echo "Hosted zone: $ZONE_ID"

echo "== Is Route 53 really in charge of $ROOT? (both lists must match)"
echo "Route 53 nameservers:"; aws route53 get-hosted-zone --id "$ZONE_ID" --query DelegationSet.NameServers --output text | tr '\t' '\n' | sort
echo "Public nameservers (from the internet):"; (dig +short NS "$ROOT" 2>/dev/null || nslookup -type=NS "$ROOT" 2>/dev/null | grep nameserver || echo "(no dig/nslookup: check in Route 53 console)") | sort

CERT_ARN=$(aws acm request-certificate --region $REGION --domain-name "$HOST" \
  --validation-method DNS --query CertificateArn --output text)
echo "Certificate: $CERT_ARN"
sleep 15
read -r RNAME RVALUE < <(aws acm describe-certificate --region $REGION --certificate-arn "$CERT_ARN" \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord.[Name,Value]' --output text)

aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "{
  \"Changes\": [{ \"Action\": \"UPSERT\", \"ResourceRecordSet\": {
    \"Name\": \"$RNAME\", \"Type\": \"CNAME\", \"TTL\": 300,
    \"ResourceRecords\": [{ \"Value\": \"$RVALUE\" }] } }] }" >/dev/null
echo "Validation record added. Waiting for ACM to issue the certificate (2–10 min)..."
aws acm wait certificate-validated --region $REGION --certificate-arn "$CERT_ARN"
aws acm describe-certificate --region $REGION --certificate-arn "$CERT_ARN" --query 'Certificate.[DomainName,Status]' --output text
echo; echo "Put this in values-prod.yaml → ingress.certificateArn:"; echo "$CERT_ARN"

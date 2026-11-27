#!/usr/bin/env bash
# Points w9.ebotprog.ink at the ALB the Load Balancer Controller created (Route 53 alias record).
set -euo pipefail
REGION=eu-north-1; ROOT=ebotprog.ink; HOST=w9.ebotprog.ink
ALB_DNS=$(kubectl get ingress crud -n crud -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
[ -n "$ALB_DNS" ] || { echo "Ingress has no ADDRESS yet; wait and retry"; exit 1; }
ALB_ZONE=$(aws elbv2 describe-load-balancers --region $REGION \
  --query "LoadBalancers[?DNSName=='${ALB_DNS}'].CanonicalHostedZoneId | [0]" --output text)
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$ROOT" \
  --query "HostedZones[?Name=='${ROOT}.'].Id | [0]" --output text | cut -d/ -f3)
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "{
  \"Changes\": [{ \"Action\": \"UPSERT\", \"ResourceRecordSet\": {
    \"Name\": \"$HOST\", \"Type\": \"A\",
    \"AliasTarget\": { \"HostedZoneId\": \"$ALB_ZONE\", \"DNSName\": \"dualstack.$ALB_DNS\", \"EvaluateTargetHealth\": false } } }] }" >/dev/null
echo "$HOST → $ALB_DNS (alias). DNS can take 1–5 minutes."

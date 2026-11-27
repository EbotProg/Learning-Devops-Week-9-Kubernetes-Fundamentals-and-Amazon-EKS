#!/usr/bin/env bash
# Stores the backend secrets in AWS Secrets Manager as ONE JSON secret: crud/backend.
# Values are typed in (hidden), never written to a file or your shell history.
set -euo pipefail
REGION=eu-north-1; NAME=crud/backend
read -rsp "Atlas DATABASE_URI (mongodb+srv://...): " DBURI; echo
read -rsp "Parse MASTER_KEY: " MKEY; echo
MAINT=$(openssl rand -hex 24)        # maintenance key: random, nobody needs to know it
JSON=$(jq -n --arg a "$DBURI" --arg b "$MKEY" --arg c "$MAINT" \
  '{DATABASE_URI:$a, MASTER_KEY:$b, MAINTENANCE_KEY:$c}')
if aws secretsmanager describe-secret --region $REGION --secret-id $NAME >/dev/null 2>&1; then
  aws secretsmanager put-secret-value --region $REGION --secret-id $NAME --secret-string "$JSON" >/dev/null
  echo "Updated $NAME"
else
  aws secretsmanager create-secret --region $REGION --name $NAME --secret-string "$JSON" >/dev/null
  echo "Created $NAME"
fi
unset DBURI MKEY MAINT JSON
aws secretsmanager describe-secret --region $REGION --secret-id $NAME --query '{Name:Name,ARN:ARN}'

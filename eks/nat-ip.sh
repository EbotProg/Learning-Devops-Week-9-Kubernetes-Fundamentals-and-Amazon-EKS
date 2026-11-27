#!/usr/bin/env bash
# Prints the cluster's NAT gateway public IP → add it to MongoDB Atlas → Network Access.
REGION=eu-north-1
VPC_ID=$(aws eks describe-cluster --name w9 --region $REGION --query cluster.resourcesVpcConfig.vpcId --output text)
aws ec2 describe-nat-gateways --region $REGION --filter Name=vpc-id,Values=$VPC_ID Name=state,Values=available \
  --query "NatGateways[].NatGatewayAddresses[].PublicIp" --output text

#!/usr/bin/env bash
# Installs the cluster "platform" add-ons with Helm (run in CloudShell after the cluster exists):
#   - AWS Load Balancer Controller (turns our Ingress into an ALB)
#   - External Secrets Operator (copies Secrets Manager → Kubernetes Secret)
set -euo pipefail
REGION=eu-north-1; CLUSTER=w9
VPC_ID=$(aws eks describe-cluster --name $CLUSTER --region $REGION --query cluster.resourcesVpcConfig.vpcId --output text)

helm repo add eks https://aws.github.io/eks-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

echo "== AWS Load Balancer Controller (uses the IRSA ServiceAccount from cluster.yaml)"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=$CLUSTER --set region=$REGION --set vpcId=$VPC_ID \
  --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --wait

echo "== External Secrets Operator (uses the IRSA ServiceAccount from cluster.yaml)"
helm upgrade --install external-secrets external-secrets/external-secrets -n external-secrets \
  --set serviceAccount.create=false --set serviceAccount.name=external-secrets --wait

kubectl apply -f cluster-secret-store.yaml
echo; kubectl get deploy -n kube-system aws-load-balancer-controller
kubectl get pods -n external-secrets
kubectl get clustersecretstore

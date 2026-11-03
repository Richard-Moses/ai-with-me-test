#!/bin/sh
# Deploys the microservice to Kubernetes with the given image and waits for the rollout.
# Needs KUBECONFIG set (see init-kubeconfig.sh). Used by both Jenkinsfiles.
#
# Usage:   scripts/deploy-app.sh <image>      e.g. mosesr/oeson-microservice:1.0.7
#   APP_NAME         Deployment / image name     (default oeson-microservice)
#   NAMESPACE        Kubernetes namespace        (default microservices)
#   K8S_DIR          folder with the manifests   (default k8s)
#   ROLLOUT_TIMEOUT  how long to wait for pods   (default 240s)
#
# Note: edits the image line of $K8S_DIR/deployment.yaml in place (fine for a CI workspace copy).
set -e

IMAGE="$1"
APP_NAME="${APP_NAME:-oeson-microservice}"
NAMESPACE="${NAMESPACE:-microservices}"
K8S_DIR="${K8S_DIR:-k8s}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-240s}"
DEPLOYMENT="$K8S_DIR/deployment.yaml"

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <image>" >&2
  exit 1
fi

# Fail loudly instead of silently deploying the old image if the manifest changes shape
if ! grep -q "image: .*${APP_NAME}:" "$DEPLOYMENT" 2>/dev/null; then
  echo "No '${APP_NAME}' image line found in $DEPLOYMENT" >&2
  exit 1
fi

sed -i "s|image: .*${APP_NAME}:.*|image: ${IMAGE}|" "$DEPLOYMENT"
echo "Deploying $IMAGE to namespace $NAMESPACE"

# Namespace first, because "apply -f k8s/" applies files alphabetically
kubectl apply -f "$K8S_DIR/namespace.yaml"
kubectl apply -f "$K8S_DIR/"

kubectl rollout status "deployment/${APP_NAME}" -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"
kubectl get pods -n "$NAMESPACE"

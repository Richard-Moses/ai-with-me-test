#!/bin/sh
# Quick health check of the cluster, the app and the monitoring stack.
# Needs KUBECONFIG set (see init-kubeconfig.sh). Optional: pass a node IP to also test the app over HTTP.
#   scripts/check-cluster.sh [node-ip]
NODE_IP="$1"
FAIL=0

echo "== Nodes =="
kubectl get nodes -o wide || FAIL=1

echo
echo "== App (namespace: microservices) =="
kubectl get pods -n microservices -o wide || FAIL=1
kubectl rollout status deployment/oeson-microservice -n microservices --timeout=60s || FAIL=1

echo
echo "== Monitoring (namespace: monitoring) =="
kubectl get pods -n monitoring || FAIL=1

if [ -n "$NODE_IP" ]; then
  echo
  echo "== HTTP checks on $NODE_IP =="
  for url in "http://$NODE_IP:30080/health/live" "http://$NODE_IP:30080/health/ready" "http://$NODE_IP:30300/api/health" "http://$NODE_IP:30090/-/ready"; do
    code=$(curl -s -o /dev/null -m 10 -w "%{http_code}" "$url" || true)
    echo "$code  $url"
    [ "$code" = "200" ] || FAIL=1
  done
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "All checks passed"; else echo "Some checks failed"; fi
exit "$FAIL"

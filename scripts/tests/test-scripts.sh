#!/bin/sh
# Tests for the helper scripts in scripts/ used by the CD pipeline.
# External tools (terraform, ssh, kubectl, curl) are replaced with stubs on PATH,
# so no real infrastructure is touched.
#
#   sh scripts/tests/test-scripts.sh
#
# Exits non-zero if any test fails.

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
ORIG_PATH="$PATH"

# ---------- helpers ----------

fail() { echo "    FAIL: $1"; CUR_OK=1; }

assert_eq() { # expected actual message
  [ "$1" = "$2" ] || fail "$3 (expected '$1', got '$2')"
}

assert_contains() { # file text message
  grep -qF -- "$2" "$1" 2>/dev/null || fail "$3 (missing '$2' in $(basename "$1"))"
}

assert_not_contains() { # file text message
  ! grep -qF -- "$2" "$1" 2>/dev/null || fail "$3 (unexpected '$2' in $(basename "$1"))"
}

# Fresh temp dir + stub binaries for every test.
setup() {
  T="$(mktemp -d)"
  BIN="$T/bin"
  LOG="$T/calls.log"
  mkdir -p "$BIN"
  : > "$LOG"
  export LOG

  # terraform -chdir=DIR output -raw NAME  -> fake IP per output name
  cat > "$BIN/terraform" <<'EOF'
#!/bin/sh
echo "terraform $*" >> "$LOG"
[ -n "$TF_FAIL" ] && exit 1
case "$4" in
  jenkins_public_ip)      printf '1.1.1.1' ;;
  jenkins_private_ip)     printf '10.0.0.1' ;;
  k8s_node_1_public_ip)   printf '2.2.2.2' ;;
  k8s_node_1_private_ip)  printf '10.0.0.2' ;;
  k8s_node_2_public_ip)   printf '3.3.3.3' ;;
  k8s_node_2_private_ip)  printf '10.0.0.3' ;;
  *) echo "unknown output $4" >&2; exit 1 ;;
esac
EOF

  # ssh ... "sudo cat /etc/kubernetes/admin.conf" -> fake kubeconfig
  cat > "$BIN/ssh" <<'EOF'
#!/bin/sh
echo "ssh $*" >> "$LOG"
[ -n "$SSH_FAIL" ] && exit 255
cat <<CONF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: abc
    server: https://172.31.5.10:6443
  name: kubernetes
CONF
EOF

  # kubectl: fails when its arguments contain $KUBECTL_FAIL_ON
  cat > "$BIN/kubectl" <<'EOF'
#!/bin/sh
echo "kubectl $*" >> "$LOG"
case "$*" in
  *"${KUBECTL_FAIL_ON:-<never>}"*) echo "kubectl error" >&2; exit 1 ;;
esac
echo "ok"
EOF

  # curl -w "%{http_code}": prints 503 for URLs containing $CURL_FAIL_ON, else 200
  cat > "$BIN/curl" <<'EOF'
#!/bin/sh
for last; do :; done
echo "curl $last" >> "$LOG"
case "$last" in
  *"${CURL_FAIL_ON:-<never>}"*) printf '503' ;;
  *) printf '200' ;;
esac
EOF

  chmod +x "$BIN"/*
  PATH="$BIN:$ORIG_PATH"
  unset TF_FAIL SSH_FAIL KUBECTL_FAIL_ON CURL_FAIL_ON SSH_KEY KUBECONFIG_OUT USE_PRIVATE_IPS
}

teardown() { PATH="$ORIG_PATH"; rm -rf "$T"; }

run_test() {
  CUR_OK=0
  setup
  "$1"
  teardown
  if [ "$CUR_OK" -eq 0 ]; then PASS=$((PASS + 1)); echo "ok   $1"
  else FAIL=$((FAIL + 1)); echo "FAIL $1"; fi
}

# ---------- write-inventory.sh ----------

test_inventory_uses_private_ips_by_default() {
  TF_DIR="$T/tf" INVENTORY_OUT="$T/inventory.ini" sh "$SCRIPTS/write-inventory.sh" > "$T/out" 2>&1
  assert_eq 0 $? "exit code"
  assert_contains "$T/inventory.ini" "jenkins-host ansible_host=10.0.0.1 public_ip=1.1.1.1" "jenkins line"
  assert_contains "$T/inventory.ini" "k8s-node-1 ansible_host=10.0.0.2 public_ip=2.2.2.2" "master line"
  assert_contains "$T/inventory.ini" "k8s-node-2 ansible_host=10.0.0.3 public_ip=3.3.3.3" "worker line"
  assert_contains "$T/inventory.ini" "ansible_user=ubuntu" "ansible user"
  assert_contains "$LOG" "terraform -chdir=$T/tf output -raw jenkins_public_ip" "uses TF_DIR"
}

test_inventory_uses_public_ips_when_disabled() {
  USE_PRIVATE_IPS=false TF_DIR="$T/tf" INVENTORY_OUT="$T/inventory.ini" \
    sh "$SCRIPTS/write-inventory.sh" > "$T/out" 2>&1
  assert_eq 0 $? "exit code"
  assert_contains "$T/inventory.ini" "jenkins-host ansible_host=1.1.1.1 public_ip=1.1.1.1" "jenkins line"
  assert_contains "$T/inventory.ini" "k8s-node-1 ansible_host=2.2.2.2 public_ip=2.2.2.2" "master line"
  assert_contains "$T/inventory.ini" "k8s-node-2 ansible_host=3.3.3.3 public_ip=3.3.3.3" "worker line"
}

test_inventory_fails_when_terraform_fails() {
  TF_FAIL=1 TF_DIR="$T/tf" INVENTORY_OUT="$T/inventory.ini" \
    sh "$SCRIPTS/write-inventory.sh" > "$T/out" 2>&1
  [ $? -ne 0 ] || fail "expected non-zero exit"
  [ ! -e "$T/inventory.ini" ] || fail "inventory should not be written"
}

# ---------- init-kubeconfig.sh ----------

test_kubeconfig_requires_address() {
  sh "$SCRIPTS/init-kubeconfig.sh" > "$T/out" 2> "$T/err"
  assert_eq 1 $? "exit code"
  assert_contains "$T/err" "Usage:" "usage on stderr"
  assert_not_contains "$LOG" "ssh" "ssh not called"
}

test_kubeconfig_downloads_and_rewrites_server() {
  KUBECONFIG_OUT="$T/kubeconfig" sh "$SCRIPTS/init-kubeconfig.sh" 54.1.2.3 "$T/key.pem" > "$T/out" 2>&1
  assert_eq 0 $? "exit code"
  assert_contains "$T/kubeconfig" "server: https://54.1.2.3:6443" "server rewritten"
  assert_not_contains "$T/kubeconfig" "172.31.5.10" "private address removed"
  assert_contains "$T/kubeconfig" "certificate-authority-data: abc" "rest of config kept"
  assert_contains "$LOG" "-i $T/key.pem" "uses given key"
  assert_contains "$LOG" "ubuntu@54.1.2.3" "connects to given address"
  assert_contains "$T/out" "Wrote $T/kubeconfig" "reports output"
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) ;; # NTFS does not keep Unix permissions
    *) assert_eq "-rw-------" "$(ls -l "$T/kubeconfig" | cut -c1-10)" "file mode 600" ;;
  esac
}

test_kubeconfig_key_from_env() {
  SSH_KEY="$T/env-key" KUBECONFIG_OUT="$T/kubeconfig" sh "$SCRIPTS/init-kubeconfig.sh" 10.0.0.2 > "$T/out" 2>&1
  assert_eq 0 $? "exit code"
  assert_contains "$LOG" "-i $T/env-key" "uses SSH_KEY"
  assert_contains "$T/kubeconfig" "server: https://10.0.0.2:6443" "server rewritten"
}

test_kubeconfig_fails_when_ssh_fails() {
  SSH_FAIL=1 KUBECONFIG_OUT="$T/kubeconfig" sh "$SCRIPTS/init-kubeconfig.sh" 54.1.2.3 "$T/key.pem" > "$T/out" 2>&1
  [ $? -ne 0 ] || fail "expected non-zero exit"
  assert_not_contains "$T/out" "Wrote" "should not report success"
}

# ---------- check-cluster.sh ----------

test_check_passes_without_node_ip() {
  sh "$SCRIPTS/check-cluster.sh" > "$T/out" 2>&1
  assert_eq 0 $? "exit code"
  assert_contains "$T/out" "All checks passed" "summary"
  assert_contains "$LOG" "kubectl rollout status deployment/oeson-microservice -n microservices" "checks rollout"
  assert_contains "$LOG" "kubectl get pods -n monitoring" "checks monitoring"
  assert_not_contains "$LOG" "curl" "no HTTP checks without IP"
}

test_check_fails_but_continues_when_rollout_fails() {
  KUBECTL_FAIL_ON="rollout" sh "$SCRIPTS/check-cluster.sh" > "$T/out" 2>&1
  assert_eq 1 $? "exit code"
  assert_contains "$T/out" "Some checks failed" "summary"
  assert_contains "$LOG" "kubectl get pods -n monitoring" "keeps checking after a failure"
}

test_check_http_endpoints_pass() {
  sh "$SCRIPTS/check-cluster.sh" 5.6.7.8 > "$T/out" 2>&1
  assert_eq 0 $? "exit code"
  for url in http://5.6.7.8:30080/health/live http://5.6.7.8:30080/health/ready \
             http://5.6.7.8:30300/api/health http://5.6.7.8:30090/-/ready; do
    assert_contains "$LOG" "curl $url" "calls $url"
  done
  assert_contains "$T/out" "All checks passed" "summary"
}

test_check_http_endpoint_failure() {
  CURL_FAIL_ON=":30300" sh "$SCRIPTS/check-cluster.sh" 5.6.7.8 > "$T/out" 2>&1
  assert_eq 1 $? "exit code"
  assert_contains "$T/out" "503  http://5.6.7.8:30300/api/health" "reports failing code"
  assert_contains "$T/out" "Some checks failed" "summary"
}

# ---------- deploy-app.sh ----------
# Runs against a copy of the real k8s/ manifests, so a change to deployment.yaml
# that breaks the image replacement is caught here.

copy_manifests() { cp -r "$SCRIPTS/../k8s" "$T/k8s"; }

test_deploy_requires_image() {
  copy_manifests
  K8S_DIR="$T/k8s" sh "$SCRIPTS/deploy-app.sh" > "$T/out" 2> "$T/err"
  assert_eq 1 $? "exit code"
  assert_contains "$T/err" "Usage:" "usage on stderr"
  assert_not_contains "$LOG" "kubectl" "kubectl not called"
}

test_deploy_sets_image_and_applies_in_order() {
  copy_manifests
  K8S_DIR="$T/k8s" sh "$SCRIPTS/deploy-app.sh" mosesr/oeson-microservice:1.0.7 > "$T/out" 2>&1
  assert_eq 0 $? "exit code"
  assert_contains "$T/k8s/deployment.yaml" "image: mosesr/oeson-microservice:1.0.7" "image updated"
  assert_not_contains "$T/k8s/deployment.yaml" "oeson-microservice:1.0.0" "old image gone"
  assert_eq "kubectl apply -f $T/k8s/namespace.yaml" "$(sed -n 1p "$LOG")" "namespace applied first"
  assert_eq "kubectl apply -f $T/k8s/" "$(sed -n 2p "$LOG")" "then the whole folder"
  assert_eq "kubectl rollout status deployment/oeson-microservice -n microservices --timeout=240s" \
    "$(sed -n 3p "$LOG")" "waits for rollout with default timeout"
  assert_eq "kubectl get pods -n microservices" "$(sed -n 4p "$LOG")" "lists pods"
}

test_deploy_honours_env_overrides() {
  copy_manifests
  NAMESPACE=staging ROLLOUT_TIMEOUT=180s K8S_DIR="$T/k8s" \
    sh "$SCRIPTS/deploy-app.sh" mosesr/oeson-microservice:2.0.0 > "$T/out" 2>&1
  assert_eq 0 $? "exit code"
  assert_contains "$LOG" "kubectl rollout status deployment/oeson-microservice -n staging --timeout=180s" "rollout flags"
  assert_contains "$LOG" "kubectl get pods -n staging" "pods namespace"
}

test_deploy_fails_when_image_line_missing() {
  copy_manifests
  sed -i "s|image: .*|image: someone/else:1.0|" "$T/k8s/deployment.yaml"
  K8S_DIR="$T/k8s" sh "$SCRIPTS/deploy-app.sh" mosesr/oeson-microservice:1.0.7 > "$T/out" 2> "$T/err"
  assert_eq 1 $? "exit code"
  assert_contains "$T/err" "No 'oeson-microservice' image line" "explains the problem"
  assert_not_contains "$LOG" "kubectl" "nothing applied"
}

test_deploy_stops_when_apply_fails() {
  copy_manifests
  KUBECTL_FAIL_ON="namespace.yaml" K8S_DIR="$T/k8s" \
    sh "$SCRIPTS/deploy-app.sh" mosesr/oeson-microservice:1.0.7 > "$T/out" 2>&1
  [ $? -ne 0 ] || fail "expected non-zero exit"
  assert_not_contains "$LOG" "rollout" "no rollout after failed apply"
}

test_deploy_fails_when_rollout_fails() {
  copy_manifests
  KUBECTL_FAIL_ON="rollout" K8S_DIR="$T/k8s" \
    sh "$SCRIPTS/deploy-app.sh" mosesr/oeson-microservice:1.0.7 > "$T/out" 2>&1
  [ $? -ne 0 ] || fail "expected non-zero exit"
}

# ---------- run ----------

for t in \
  test_inventory_uses_private_ips_by_default \
  test_inventory_uses_public_ips_when_disabled \
  test_inventory_fails_when_terraform_fails \
  test_kubeconfig_requires_address \
  test_kubeconfig_downloads_and_rewrites_server \
  test_kubeconfig_key_from_env \
  test_kubeconfig_fails_when_ssh_fails \
  test_check_passes_without_node_ip \
  test_check_fails_but_continues_when_rollout_fails \
  test_check_http_endpoints_pass \
  test_check_http_endpoint_failure \
  test_deploy_requires_image \
  test_deploy_sets_image_and_applies_in_order \
  test_deploy_honours_env_overrides \
  test_deploy_fails_when_image_line_missing \
  test_deploy_stops_when_apply_fails \
  test_deploy_fails_when_rollout_fails
do
  run_test "$t"
done

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

#!/bin/sh
# Writes ansible/inventory.ini from the Terraform outputs. Run from the repo root after "terraform apply".
#   USE_PRIVATE_IPS=true   Ansible connects over private IPs (use when running on the Jenkins server)
#   USE_PRIVATE_IPS=false  Ansible connects over public IPs (use when running from your own PC)
set -e

TF_DIR="${TF_DIR:-infra/terraform}"
OUT="${INVENTORY_OUT:-ansible/inventory.ini}"

out() { terraform -chdir="$TF_DIR" output -raw "$1"; }

J_PUB=$(out jenkins_public_ip)
J_PRIV=$(out jenkins_private_ip)
N1_PUB=$(out k8s_node_1_public_ip)
N1_PRIV=$(out k8s_node_1_private_ip)
N2_PUB=$(out k8s_node_2_public_ip)
N2_PRIV=$(out k8s_node_2_private_ip)

if [ "${USE_PRIVATE_IPS:-true}" = "true" ]; then
  J_HOST=$J_PRIV; N1_HOST=$N1_PRIV; N2_HOST=$N2_PRIV
else
  J_HOST=$J_PUB; N1_HOST=$N1_PUB; N2_HOST=$N2_PUB
fi

cat > "$OUT" <<EOF
[jenkins]
jenkins-host ansible_host=$J_HOST public_ip=$J_PUB

[k8s_master]
k8s-node-1 ansible_host=$N1_HOST public_ip=$N1_PUB

[k8s_workers]
k8s-node-2 ansible_host=$N2_HOST public_ip=$N2_PUB

[k8s_cluster:children]
k8s_master
k8s_workers

[all:vars]
ansible_user=ubuntu
ansible_python_interpreter=/usr/bin/python3
EOF

echo "Wrote $OUT"
cat "$OUT"

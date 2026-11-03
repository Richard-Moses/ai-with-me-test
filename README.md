# Built with Claude & Me

Oeson Capstone: end-to-end CI/CD and infrastructure for a microservice on Kubernetes (AWS).

Built step by step, one task at a time.

| Task | What | Status |
|---|---|---|
| 1 | Dockerize the microservice (non-root, multi-stage) | done |
| 2 | Kubernetes manifests | done |
| 3 | Terraform (AWS VPC + EC2) | done |
| 4 | Jenkins pipeline | done |
| 5 | Monitoring (Prometheus + Grafana, plain manifests, no Helm) | done |
| 6 | End-to-end pipeline | done |

## Run the app locally

```bash
cd app
npm install
npm test
npm start        # http://localhost:8080  (/, /health/live, /health/ready, /metrics)
```

## Build and run the container

Run from the repo root:

```bash
docker build -f docker/Dockerfile -t mosesr/oeson-microservice:1.0.0 .
docker run --rm -p 8080:8080 mosesr/oeson-microservice:1.0.0
```

## Provision AWS (Task 3)

Files in `infra/terraform/`: `main.tf` (VPC, subnets, security group, key pair), `plan.tf` (the 3 EC2 servers), `variables.tf`, `outputs.tf`, `providers.tf`, `backend.tf` (local state).

```bash
ssh-keygen -t ed25519 -f ~/.ssh/oeson_key          # once; creates the key pair files
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars        # then edit allowed_ssh_cidr to YOUR_IP/32
terraform init
terraform plan
terraform apply
terraform output
```

Costs real money while running. Remove everything with `terraform destroy`.

## Jenkins pipeline (Task 4)

`Jenkinsfile` (repo root): Checkout, Test, Build Docker Image, Push to DockerHub, Deploy to Kubernetes.

Set up in Jenkins (Manage Jenkins > Credentials > Global):

| ID | Kind | Value |
|---|---|---|
| `dockerhub-credentials` | Username with password | Docker Hub login (`mosesr` + password or access token) |
| `kubeconfig` | Secret file | kubeconfig for the cluster |

Then create a Pipeline job pointing at your Git repo, with "Pipeline script from SCM" and script path `Jenkinsfile`.

Auto-trigger: the pipeline polls Git every ~2 minutes (works while Jenkins is only open to your IP). For instant triggers, add a GitHub webhook to `http://<jenkins-ip>:8080/github-webhook/`. GitHub must be able to reach that port.

Notes:
- `k8s/secret.yaml` is a placeholder. Set the real value in the cluster with `kubectl create secret generic ... --dry-run=client -o yaml | kubectl apply -f -`.
- Docker and kubectl must be installed on the Jenkins host (Task 6 Ansible does this).

## Monitoring (Task 5, no Helm)

Plain Kubernetes manifests in `monitoring/`. Run from the repo root with `kubectl` pointed at the cluster, after the app is deployed:

```bash
kubectl apply -f monitoring/namespace.yaml
kubectl apply -f monitoring/prometheus/rbac.yaml
kubectl apply -f monitoring/prometheus/
kubectl apply -f monitoring/grafana/
kubectl get pods -n monitoring
```

- Prometheus: `http://<any-node-ip>:30090`, deployment and service named `monitoring-prometheus`.
- Grafana: `http://<any-node-ip>:30300` (container port 3000), login `admin` / `admin`, named `monitoring-grafana`. Change the password after first login.
- Prometheus finds the app through the pod annotations in `k8s/deployment.yaml` (`prometheus.io/scrape: "true"`, port 8080, path `/metrics`). ServiceMonitors need the Prometheus operator, which needs Helm, so they are not used.
- The "Oeson Microservice" dashboard is provisioned automatically: CPU per pod, memory per pod, HTTP request rate, pods scraped.
- Remember the security group opens NodePorts 30000-32767 to the internet; Grafana's admin/admin is public until you change it.

## End-to-end pipeline (Task 6)

`cd-pipeline/Jenkinsfile` runs: Terraform plan, approval, Terraform apply, write the Ansible inventory, Ansible (Docker, Kubernetes), get the kubeconfig, deploy the app with kubectl, set up monitoring, verify. It takes parameters (action `plan`/`apply`/`destroy`, your IP, image tag).

Ansible playbooks (`ansible/playbooks/`): `install-docker.yml` (Jenkins server only), `install-jenkins.yml` (also kubectl, Terraform, Ansible, swap), `install-k8s.yml` (containerd + kubeadm, 1 control plane + 1 worker), `configure-pipeline.yml` (Jenkins plugins), `install-monitoring.yml`, `setup-app.yml`. No Helm anywhere.

### First-time order (chicken and egg: Jenkins is itself created by Terraform)

Run these once from your own machine (Linux, macOS or WSL), then use Jenkins for everything after.

```bash
# 1. Servers
cd infra/terraform && terraform init && terraform apply && cd ../..
USE_PRIVATE_IPS=false sh scripts/write-inventory.sh        # fills ansible/inventory.ini with public IPs

# 2. Install Docker and Jenkins
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook --private-key ~/.ssh/oeson_key playbooks/install-docker.yml
ansible-playbook --private-key ~/.ssh/oeson_key playbooks/install-jenkins.yml   # prints the Jenkins admin password

# 3. Open http://<jenkins-ip>:8080, unlock, create your admin user, then:
ansible-playbook --private-key ~/.ssh/oeson_key playbooks/configure-pipeline.yml -e jenkins_admin_password='YOUR_PASSWORD'
```

Then in Jenkins add these credentials: `dockerhub-credentials`, `aws-credentials` (AWS key ID as username, secret key as password) and `oeson-ssh-key` (user `ubuntu` + your private key). Create the jobs (manually, or paste `cd-pipeline/job-seed.groovy` into a Job DSL build step), and run `oeson-infrastructure` with `TERRAFORM_ACTION=apply`, `USE_PRIVATE_IPS` ticked, `INSTALL_JENKINS` unticked. Run `oeson-microservice` to build and push an image first (or deploy `latest`).

### Cautions
- Never tick `INSTALL_JENKINS` in a build running on the Jenkins server: it restarts Jenkins.
- t2.micro servers are below Kubernetes' recommended size. The playbook skips the size checks; expect slowness or out-of-memory restarts. Use t3.small (`instance_type` variable) if that happens.
- Terraform state lives in the Jenkins job workspace. Do not wipe it, or Terraform forgets the servers.
- `terraform destroy` (or the `destroy` action) when finished, to stop AWS charges.
# ai-with-me-test

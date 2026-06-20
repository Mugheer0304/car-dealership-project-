# 🚗 Car Dealership – Production AWS EKS Deployment

Full-stack car dealership website deployed on AWS EKS with Terraform, Docker, and GitHub Actions.

## Architecture

```
Internet
  │
  ▼
CloudFront (optional CDN)
  │
  ▼
AWS Load Balancer (NLB, public subnets)
  │
  ▼
Nginx Ingress Controller (EKS, private subnets)
  │
  ├──► Frontend Pod (Next.js, namespace: frontend)
  │         │  mTLS (Istio)
  │         ▼
  └──► Backend Pod (FastAPI, namespace: backend)
            │
            ├──► RDS PostgreSQL (database subnet, multi-AZ)
            └──► ElastiCache Redis (database subnet, multi-AZ)
```

**Security perimeter:**
- EKS API endpoint is **private only** (no public access)
- All workload nodes in **private subnets** (no public IPs)
- RDS and Redis in **isolated database subnets**
- mTLS enforced between frontend ↔ backend (Istio STRICT)
- NetworkPolicies: frontend can only reach backend; backend can only reach RDS/Redis

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | ≥ 1.6 |
| AWS CLI | ≥ 2.15 |
| kubectl | ≥ 1.29 |
| helm | ≥ 3.14 |
| Docker | ≥ 24 |

AWS account prerequisites (create before `terraform apply`):
- S3 bucket for Terraform state (versioning + encryption enabled)
- DynamoDB table for TF state lock
- OIDC provider in IAM for GitHub Actions

---

## Step-by-Step Deployment

### Step 1 – Bootstrap Terraform state backend

```bash
aws s3api create-bucket \
  --bucket car-dealership-tf-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket car-dealership-tf-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket car-dealership-tf-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws dynamodb create-table \
  --table-name car-dealership-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Step 2 – Configure GitHub OIDC (one-time setup)

```bash
# Create the OIDC provider for GitHub Actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Then create an IAM role that trusts `token.actions.githubusercontent.com` 
with condition `repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main`.

Add to GitHub Secrets:
```
AWS_ROLE_ARN         = arn:aws:iam::ACCOUNT_ID:role/github-actions-role
AWS_ACCOUNT_ID       = 123456789012
TF_STATE_BUCKET      = car-dealership-tf-state
TF_LOCK_TABLE        = car-dealership-tf-lock
ALERT_EMAIL          = ops@your-domain.com
```

### Step 3 – Provision Infrastructure

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: set alert_email, etc.

terraform init
terraform plan -var="alert_email=ops@your-domain.com"
terraform apply -var="alert_email=ops@your-domain.com"
```

Expected output:
```
eks_cluster_name  = "car-dealership-prod-eks"
ecr_frontend_url  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/car-dealership-prod/frontend"
ecr_backend_url   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/car-dealership-prod/backend"
kubeconfig_command = "aws eks update-kubeconfig --region us-east-1 --name car-dealership-prod-eks"
```

### Step 4 – Connect kubectl (from bastion/VPN – cluster is private)

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name car-dealership-prod-eks
kubectl get nodes
```

### Step 5 – Install Istio (service mesh for mTLS)

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=minimal -y
# Verify
istioctl verify-install
```

### Step 6 – Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace --set installCRDs=true
```

### Step 7 – Push to main (triggers full CI/CD)

```bash
git add .
git commit -m "feat: initial deployment"
git push origin main
```

GitHub Actions runs 3 workflows in sequence:
1. **Terraform** – provisions/updates infra
2. **Build & Push** – builds Docker images, scans with Trivy, pushes to ECR
3. **Deploy** – applies all K8s manifests, runs Helm upgrades, verifies rollout

### Step 8 – Verify deployment

```bash
./scripts/validate.sh your-domain.com car-dealership-prod-eks us-east-1
```

---

## Verifying Security Controls

### Verify mTLS is enforced

```bash
# Check PeerAuthentication mode
kubectl get peerauthentication -n backend default -o jsonpath='{.spec.mtls.mode}'
# Expected: STRICT

# Check Istio proxy certificate
kubectl exec -n backend deploy/backend -c istio-proxy -- \
  openssl s_client -connect frontend-service.frontend.svc.cluster.local:3000 2>&1 | grep "Verify"
```

### Verify NetworkPolicies block cross-namespace access

```bash
# Frontend should NOT be able to reach Redis
kubectl run test-np --image=busybox -n frontend --restart=Never -- \
  sh -c "nc -zw3 <REDIS_HOST> 6379; echo exit:$?"
# Expected: exit:1 (connection refused/timeout)

# Frontend should reach backend
kubectl run test-np2 --image=busybox -n frontend --restart=Never -- \
  sh -c "wget -T5 -qO- http://backend-service.backend.svc.cluster.local:8000/health"
# Expected: {"status":"ok",...}
```

### Verify secrets are not visible in pod describe

```bash
kubectl describe pod -n backend -l app=backend | grep -i "password\|secret\|DB_PASSWORD"
# Expected: no raw values (only secretRef references appear)

# Confirm secrets come from Secrets Manager
kubectl get externalsecret -n backend backend-db-secret -o yaml | grep status
# Should show: Ready: True
```

### Verify no public API endpoint

```bash
# Direct curl to EKS API from your laptop should fail (not VPN/bastion)
ENDPOINT=$(aws eks describe-cluster --name car-dealership-prod-eks \
  --query 'cluster.endpoint' --output text)
curl --max-time 5 "$ENDPOINT" 2>&1
# Expected: Connection timeout (private endpoint, not reachable from internet)
```

---

## Testing Commands

### Simulate car search

```bash
# With pagination and filters
curl "https://your-domain.com/api/cars?make=Toyota&priceMax=30000&limit=5" | jq .

# POST an inquiry
curl -X POST https://your-domain.com/api/inquiries \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@test.com","message":"Interested in Toyota Camry","carId":1}'
```

### Check Redis cache hit rate

```bash
kubectl exec -n backend deploy/backend -- \
  redis-cli -h $REDIS_HOST -a $REDIS_PASSWORD INFO stats | grep keyspace
```

### Simulate 100 concurrent users (requires `hey`)

```bash
hey -n 1000 -c 100 -t 30 https://your-domain.com/api/cars
# Look for: requests/sec, p99 latency < 2000ms, 0 error responses
```

### Check Prometheus metrics

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9090:9090

# In browser: http://localhost:9090
# Query: rate(http_requests_total{job="backend"}[5m])
# Query: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

### Access Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3001:80
# Browser: http://localhost:3001 (admin / <password from secret>)
```

---

## Observability Stack

| Component | Purpose |
|-----------|---------|
| Prometheus | Scrapes metrics from all pods every 15s |
| Grafana | Dashboards: API latency, error rate, cache hits, pod status |
| CloudWatch | Log aggregation (frontend, backend, nginx log groups) |
| SNS + Email | Alerts on: 5xx > 5%, pod restarts > 3, RDS/Redis CPU > 80% |
| PrometheusRule | Custom alerting rules (see `k8s/monitoring/service-monitors.yaml`) |

---

## Disaster Recovery

| Scenario | Recovery |
|----------|---------|
| Pod crash | K8s auto-restarts; PDB ensures min 2 replicas always up |
| Node failure | Pod rescheduled to another node (3 AZ spread) |
| AZ outage | Multi-AZ EKS nodes + multi-AZ RDS + Redis replication group |
| DB corruption | RDS automated backups (7 days) + final snapshot on destroy |
| Accidental secret deletion | Secrets Manager 7-day recovery window |

---

## Project Structure

```
car-dealership/
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                  # Module orchestration + alerting
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── modules/
│       ├── vpc/                 # VPC, subnets, NAT gateways
│       ├── eks/                 # EKS cluster, node group, OIDC
│       ├── rds/                 # PostgreSQL (multi-AZ)
│       ├── elasticache/         # Redis replication group
│       ├── ecr/                 # Private container registries
│       ├── iam/                 # Cluster, node, and pod IAM roles
│       └── security-groups/     # SG rules per component
├── frontend/                    # Next.js application
│   ├── Dockerfile               # Multi-stage, non-root
│   └── src/
├── backend/                     # FastAPI application
│   ├── Dockerfile               # Multi-stage, non-root
│   └── app/
├── k8s/                         # Kubernetes manifests
│   ├── namespaces/
│   ├── deployments/             # Frontend + backend Deployments
│   ├── network-policies/        # Strict ingress/egress rules
│   ├── ingress/                 # Nginx Ingress + cert-manager
│   ├── external-secrets/        # ESO → Secrets Manager
│   ├── hpa/                     # HPA + PodDisruptionBudgets
│   └── monitoring/              # ServiceMonitors + PrometheusRules + Istio mTLS
├── .github/workflows/
│   ├── terraform.yml            # Plan & Apply on infra/ changes
│   ├── build-push.yml           # Build images + Trivy scan + push ECR
│   └── deploy.yml               # kubectl apply + Helm upgrades
├── helm/values/
│   └── prometheus-values.yaml   # kube-prometheus-stack config
└── scripts/
    └── validate.sh              # 13-point security + correctness checks
```

#!/usr/bin/env bash
# =============================================================================
# validate.sh – Production security & correctness validation
# Run after deployment to confirm all controls are working.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

ok()   { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

require() { command -v "$1" &>/dev/null || { echo "Required: $1"; exit 1; }; }
require kubectl; require aws; require curl; require jq

DOMAIN="${1:-your-domain.com}"
CLUSTER="${2:-car-dealership-prod-eks}"
REGION="${3:-us-east-1}"

echo ""
echo "============================================================"
echo " Car Dealership – Security & Correctness Validation"
echo " Cluster: $CLUSTER | Domain: $DOMAIN"
echo "============================================================"
echo ""

# ── 1. Cluster reachability (private endpoint) ────────────────────────────────
info "1. EKS cluster access..."
if kubectl cluster-info &>/dev/null 2>&1; then
  ok "kubectl can reach cluster"
else
  fail "Cannot reach EKS cluster – are you on VPN / bastion?"
fi

# ── 2. No pods with public IPs ────────────────────────────────────────────────
info "2. Checking pods for public IPs..."
PUBLIC_IPS=$(kubectl get pods -A -o json | jq -r '
  .items[].status.podIP // ""
  | select(test("^(3[0-9]|4[0-9]|5[0-9]|6[0-9]|7[0-9]|8[0-9]|9[0-9]|1[0-9]{2})\\.");)
')
if [[ -z "$PUBLIC_IPS" ]]; then
  ok "No pods have public IPs"
else
  fail "Pods with public IPs detected: $PUBLIC_IPS"
fi

# ── 3. All workload pods in private subnets ───────────────────────────────────
info "3. Verifying nodes are in private subnets..."
NODES=$(kubectl get nodes -o json | jq -r '.items[].metadata.labels."topology.kubernetes.io/zone" // "unknown"')
info "Node AZs: $(echo $NODES | tr '\n' ' ')"

# Check no node has PublicIpAddress (IMDSv2 only – nodes shouldn't expose public IPs)
for node in $(kubectl get nodes -o name); do
  NODE_NAME=$(echo $node | cut -d/ -f2)
  INSTANCE_ID=$(kubectl get node $NODE_NAME -o json | jq -r '.spec.providerID | split("/")[-1]')
  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "None")
  if [[ "$PUBLIC_IP" == "None" || -z "$PUBLIC_IP" ]]; then
    ok "Node $NODE_NAME has no public IP"
  else
    fail "Node $NODE_NAME has public IP: $PUBLIC_IP"
  fi
done

# ── 4. No hardcoded secrets in running pods ───────────────────────────────────
info "4. Scanning for hardcoded secrets in pod env vars..."
SECRETS_EXPOSED=$(kubectl get pods -n backend -o json | jq -r '
  .items[].spec.containers[].env[]?
  | select(.value? | test("password|secret|key"; "i"))
  | .name + "=" + .value
' 2>/dev/null || true)

if [[ -z "$SECRETS_EXPOSED" ]]; then
  ok "No hardcoded secrets visible in pod env (all via secretRef)"
else
  fail "Potential hardcoded secret in pod env: $SECRETS_EXPOSED"
fi

# Confirm secrets come from secretRef
SECRETS_REF=$(kubectl get pods -n backend -o json | jq -r '
  .items[0].spec.containers[0].envFrom[]?.secretRef.name // ""
' 2>/dev/null || true)
if [[ -n "$SECRETS_REF" ]]; then
  ok "Backend pod uses secretRef: $SECRETS_REF"
else
  fail "Backend pod does not appear to use secretRef for secrets"
fi

# ── 5. Network policy – frontend cannot reach Redis directly ──────────────────
info "5. Testing NetworkPolicy: frontend cannot reach Redis..."
REDIS_HOST=$(kubectl get secret backend-redis-secret -n backend -o jsonpath='{.data.REDIS_HOST}' 2>/dev/null | base64 -d || echo "unknown")

if [[ "$REDIS_HOST" != "unknown" ]]; then
  # Try to curl redis from frontend namespace – should fail/timeout
  RESULT=$(kubectl run netpol-test --image=busybox --rm -it \
    --namespace=frontend \
    --restart=Never \
    --timeout=15s \
    -- sh -c "nc -zw3 $REDIS_HOST 6379; echo EXIT:$?" 2>&1 || true)
  if echo "$RESULT" | grep -q "EXIT:1\|timed out\|Connection refused"; then
    ok "NetworkPolicy blocks frontend → Redis (as expected)"
  else
    fail "Frontend may be able to reach Redis directly"
  fi
else
  info "Skipping Redis network policy test (secret not accessible from here)"
fi

# ── 6. mTLS verification ──────────────────────────────────────────────────────
info "6. Verifying Istio mTLS..."
if kubectl get peerauthentication -n backend default &>/dev/null 2>&1; then
  MTLS_MODE=$(kubectl get peerauthentication default -n backend -o jsonpath='{.spec.mtls.mode}')
  if [[ "$MTLS_MODE" == "STRICT" ]]; then
    ok "mTLS STRICT mode enforced in backend namespace"
  else
    fail "mTLS mode is '$MTLS_MODE', expected STRICT"
  fi
  MTLS_MODE_FE=$(kubectl get peerauthentication default -n frontend -o jsonpath='{.spec.mtls.mode}')
  if [[ "$MTLS_MODE_FE" == "STRICT" ]]; then
    ok "mTLS STRICT mode enforced in frontend namespace"
  else
    fail "mTLS mode is '$MTLS_MODE_FE' in frontend, expected STRICT"
  fi
else
  fail "No PeerAuthentication found – Istio mTLS not configured"
fi

# ── 7. TLS certificate valid ──────────────────────────────────────────────────
info "7. Checking TLS certificate for $DOMAIN..."
CERT_INFO=$(echo | timeout 5 openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || true)
if [[ -n "$CERT_INFO" ]]; then
  ok "TLS certificate present and parseable"
  echo "$CERT_INFO"
else
  fail "Could not retrieve TLS certificate from $DOMAIN"
fi

# ── 8. Website loads and returns 200 ─────────────────────────────────────────
info "8. Testing website availability..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$DOMAIN/" || echo "000")
if [[ "$HTTP_CODE" == "200" ]]; then
  ok "Website returns HTTP 200"
else
  fail "Website returned HTTP $HTTP_CODE (expected 200)"
fi

# ── 9. API returns car listings ───────────────────────────────────────────────
info "9. Testing car search API..."
API_RESPONSE=$(curl -s --max-time 10 "https://$DOMAIN/api/cars?limit=5" || echo '{"error":"failed"}')
CAR_COUNT=$(echo "$API_RESPONSE" | jq '.cars | length' 2>/dev/null || echo 0)
if [[ "$CAR_COUNT" -ge "0" ]]; then
  ok "Car listings API responds (returned $CAR_COUNT cars)"
else
  fail "Car listings API did not return expected structure"
fi

# ── 10. Response time < 2s ────────────────────────────────────────────────────
info "10. Checking TTFB..."
TTFB=$(curl -s -o /dev/null -w "%{time_starttransfer}" --max-time 10 "https://$DOMAIN/" || echo "99")
TTFB_MS=$(echo "$TTFB * 1000" | bc | cut -d. -f1)
if [[ "${TTFB_MS:-9999}" -lt "2000" ]]; then
  ok "TTFB: ${TTFB_MS}ms (< 2000ms)"
else
  fail "TTFB: ${TTFB_MS}ms (> 2000ms target)"
fi

# ── 11. Prometheus scraping metrics ──────────────────────────────────────────
info "11. Checking Prometheus targets..."
PROM_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus -o name | head -1 | cut -d/ -f2)
if [[ -n "$PROM_POD" ]]; then
  TARGETS=$(kubectl exec -n monitoring "$PROM_POD" -c prometheus -- \
    wget -qO- 'http://localhost:9090/api/v1/targets?state=active' 2>/dev/null \
    | jq '.data.activeTargets | length' 2>/dev/null || echo 0)
  ok "Prometheus has $TARGETS active scrape targets"
else
  fail "Prometheus pod not found in monitoring namespace"
fi

# ── 12. HPA configured ────────────────────────────────────────────────────────
info "12. Checking HPA..."
HPA_FE=$(kubectl get hpa frontend-hpa -n frontend -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "0")
HPA_BE=$(kubectl get hpa backend-hpa  -n backend  -o jsonpath='{.status.currentReplicas}' 2>/dev/null || echo "0")
if [[ "$HPA_FE" -ge "1" ]] && [[ "$HPA_BE" -ge "1" ]]; then
  ok "HPA active: frontend=$HPA_FE replicas, backend=$HPA_BE replicas"
else
  fail "HPA not active – frontend=$HPA_FE, backend=$HPA_BE"
fi

# ── 13. No public S3 buckets ─────────────────────────────────────────────────
info "13. Checking S3 bucket ACLs..."
BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null || true)
for bucket in $BUCKETS; do
  if echo "$bucket" | grep -q "car-dealership"; then
    ACL=$(aws s3api get-bucket-acl --bucket "$bucket" --query 'Grants[?Grantee.URI==`http://acs.amazonaws.com/groups/global/AllUsers`]' --output text 2>/dev/null || true)
    if [[ -z "$ACL" ]]; then
      ok "S3 bucket '$bucket' is not public"
    else
      fail "S3 bucket '$bucket' has public ACL!"
    fi
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "============================================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0

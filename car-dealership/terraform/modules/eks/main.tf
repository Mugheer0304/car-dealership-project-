variable "name_prefix"         { type = string }
variable "cluster_version"     { type = string }
variable "vpc_id"              { type = string }
variable "private_subnet_ids"  { type = list(string) }
variable "node_security_group" { type = string }
variable "cluster_sg_id"       { type = string }
variable "node_instance_type"  { type = string }
variable "node_min_size"       { type = number }
variable "node_max_size"       { type = number }
variable "node_desired_size"   { type = number }
variable "node_role_arn"       { type = string }
variable "cluster_role_arn"    { type = string }

locals { cluster_name = "${var.name_prefix}-eks" }

# ── EKS Control Plane ─────────────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false   # No public API endpoint
    security_group_ids      = [var.cluster_sg_id]
  }

  # Enable control-plane logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  tags = { Name = local.cluster_name }
}

# ── KMS for etcd secret encryption ───────────────────────────────────────────
resource "aws_kms_key" "eks" {
  description             = "EKS secret encryption key"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster_name}"
  target_key_id = aws_kms_key.eks.key_id
}

# ── Managed Node Group ────────────────────────────────────────────────────────
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = [var.node_instance_type]
  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config { max_unavailable = 1 }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version_number
  }

  labels = { role = "workload" }

  # Allow rolling updates without downtime
  lifecycle { ignore_changes = [scaling_config[0].desired_size] }
}

resource "aws_launch_template" "node" {
  name_prefix   = "${local.cluster_name}-node-lt-"
  instance_type = var.node_instance_type

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.cluster_name}-node" }
  }
}

# ── OIDC Provider (for IRSA) ──────────────────────────────────────────────────
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ── EKS Add-ons ───────────────────────────────────────────────────────────────
resource "aws_eks_addon" "coredns" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on        = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name      = aws_eks_cluster.main.name
  addon_name        = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on        = [aws_eks_node_group.main]
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "cluster_name"     { value = aws_eks_cluster.main.name }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "oidc_provider_arn"{ value = aws_iam_openid_connect_provider.eks.arn }
output "oidc_issuer_url"  { value = aws_eks_cluster.main.identity[0].oidc[0].issuer }

variable "name_prefix" { type = string }
variable "vpc_id"      { type = string }
variable "vpc_cidr"    { type = string }

# ── EKS Cluster SG ───────────────────────────────────────────────────────────
resource "aws_security_group" "eks_cluster" {
  name        = "${var.name_prefix}-eks-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Nodes to cluster API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-eks-cluster-sg" }
}

# ── EKS Node SG ──────────────────────────────────────────────────────────────
resource "aws_security_group" "eks_node" {
  name        = "${var.name_prefix}-eks-node-sg"
  description = "EKS node security group"
  vpc_id      = var.vpc_id

  # Node-to-node communication (Kubernetes networking)
  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Cluster API to nodes (for webhooks, kubelet)
  ingress {
    description     = "Cluster to nodes"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-eks-node-sg" }
}

# ── RDS SG (only accepts from EKS nodes) ─────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "PostgreSQL - only from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-rds-sg" }
}

# ── Redis SG (only accepts from EKS nodes) ────────────────────────────────────
resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Redis - only from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-redis-sg" }
}

output "eks_cluster_sg_id" { value = aws_security_group.eks_cluster.id }
output "eks_node_sg_id"    { value = aws_security_group.eks_node.id }
output "rds_sg_id"         { value = aws_security_group.rds.id }
output "redis_sg_id"       { value = aws_security_group.redis.id }

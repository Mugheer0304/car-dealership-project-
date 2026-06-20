locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# ── VPC ─────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
}

# ── Security Groups ──────────────────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security-groups"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr
}

# ── ECR ─────────────────────────────────────────────────────────────────────
module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  repositories = ["frontend", "backend"]
}

# ── IAM ─────────────────────────────────────────────────────────────────────
module "iam" {
  source = "./modules/iam"

  name_prefix      = local.name_prefix
  aws_region       = var.aws_region
  aws_account_id   = data.aws_caller_identity.current.account_id
  eks_cluster_name = "${local.name_prefix}-eks"
  ecr_repo_arns    = module.ecr.repository_arns
}

# ── EKS ─────────────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  name_prefix          = local.name_prefix
  cluster_version      = var.cluster_version
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  node_security_group  = module.security_groups.eks_node_sg_id
  cluster_sg_id        = module.security_groups.eks_cluster_sg_id
  node_instance_type   = var.node_instance_type
  node_min_size        = var.node_min_size
  node_max_size        = var.node_max_size
  node_desired_size    = var.node_desired_size
  node_role_arn        = module.iam.node_role_arn
  cluster_role_arn     = module.iam.cluster_role_arn
}

# ── RDS PostgreSQL ───────────────────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  name_prefix              = local.name_prefix
  db_instance_class        = var.db_instance_class
  db_name                  = var.db_name
  db_username              = var.db_username
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  database_subnet_ids      = module.vpc.database_subnet_ids
  rds_security_group_id    = module.security_groups.rds_sg_id
}

# ── ElastiCache Redis ────────────────────────────────────────────────────────
module "elasticache" {
  source = "./modules/elasticache"

  name_prefix           = local.name_prefix
  redis_node_type       = var.redis_node_type
  redis_num_cache_nodes = var.redis_num_cache_nodes
  database_subnet_ids   = module.vpc.database_subnet_ids
  redis_security_group  = module.security_groups.redis_sg_id
}

# ── CloudWatch Log Groups ────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/car-dealership/frontend"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/car-dealership/backend"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/car-dealership/nginx"
  retention_in_days = 30
}

# ── SNS Alerting ─────────────────────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name              = "${local.name_prefix}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── CloudWatch Alarms ────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU > 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  alarm_name          = "${local.name_prefix}-redis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis CPU > 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = module.elasticache.cluster_id
  }
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "/${local.name_prefix}/db/password"
  description             = "RDS master password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = module.rds.db_endpoint
    port     = 5432
    dbname   = var.db_name
  })
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

data "aws_caller_identity" "current" {}

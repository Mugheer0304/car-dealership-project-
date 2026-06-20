variable "name_prefix"           { type = string }
variable "redis_node_type"       { type = string }
variable "redis_num_cache_nodes" { type = number }
variable "database_subnet_ids"   { type = list(string) }
variable "redis_security_group"  { type = string }

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.name_prefix}-redis-subnet-group"
  subnet_ids = var.database_subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "Car dealership Redis cache"

  engine               = "redis"
  engine_version       = "7.2"
  node_type            = var.redis_node_type
  num_cache_clusters   = var.redis_num_cache_nodes
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.redis_security_group]

  automatic_failover_enabled = true
  multi_az_enabled           = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_retention_limit = 3
  snapshot_window          = "04:00-05:00"

  tags = { Name = "${var.name_prefix}-redis" }
}

output "primary_endpoint" { value = aws_elasticache_replication_group.redis.primary_endpoint_address }
output "cluster_id"       { value = aws_elasticache_replication_group.redis.id }

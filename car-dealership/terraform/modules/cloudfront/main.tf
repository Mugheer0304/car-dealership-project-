variable "name_prefix"       { type = string }
variable "alb_dns_name"      { type = string }
variable "domain_name"       { type = string }
variable "certificate_arn"   { type = string }  # ACM cert in us-east-1

resource "aws_cloudfront_distribution" "main" {
  comment             = "${var.name_prefix} CDN"
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  default_root_object = ""
  aliases             = [var.domain_name, "www.${var.domain_name}"]
  price_class         = "PriceClass_100"   # US + Europe only

  # ── Origin → NLB (nginx ingress) ─────────────────────────────────────────
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ── Static assets — long cache ─────────────────────────────────────────────
  ordered_cache_behavior {
    path_pattern           = "/_next/static/*"
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies      { forward = "none" }
    }

    min_ttl     = 86400
    default_ttl = 2592000   # 30 days
    max_ttl     = 31536000  # 1 year
  }

  # ── Public images folder ──────────────────────────────────────────────────
  ordered_cache_behavior {
    path_pattern           = "/images/*"
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies      { forward = "none" }
    }

    min_ttl     = 3600
    default_ttl = 86400
    max_ttl     = 604800
  }

  # ── Default — forward everything (SSR pages, API) ─────────────────────────
  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization", "Accept", "Accept-Language"]
      cookies      { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # WAF (optional — associate an existing WAF ACL)
  # web_acl_id = var.waf_acl_arn

  logging_config {
    bucket          = aws_s3_bucket.cf_logs.bucket_domain_name
    include_cookies = false
    prefix          = "cf-logs/"
  }

  tags = { Name = "${var.name_prefix}-cdn" }
}

# ── S3 bucket for CloudFront access logs (private) ────────────────────────────
resource "aws_s3_bucket" "cf_logs" {
  bucket        = "${var.name_prefix}-cf-logs"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "cf_logs" {
  bucket                  = aws_s3_bucket.cf_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration { days = 90 }
  }
}

output "cloudfront_domain" { value = aws_cloudfront_distribution.main.domain_name }
output "distribution_id"   { value = aws_cloudfront_distribution.main.id }

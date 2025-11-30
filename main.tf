locals {
  primary_bucket_name  = length(var.primary_bucket_name) > 0 ? var.primary_bucket_name : "${var.project_name}-primary-${random_id.rand.hex}"
  secondary_bucket_name = length(var.secondary_bucket_name) > 0 ? var.secondary_bucket_name : "${var.project_name}-secondary-${random_id.rand.hex}"
}

resource "random_id" "rand" {
  byte_length = 4
}


# S3 Buckets (Primary / Secondary)
###############################
resource "aws_s3_bucket" "primary" {
  bucket = local.primary_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "primary_public_block" {
  bucket = aws_s3_bucket.primary.id

  block_public_acls   = true
  block_public_policy = false
  ignore_public_acls  = true
  restrict_public_buckets = false
}

# Public bucket policy for primary (S3 static website access)
resource "aws_s3_bucket_policy" "primary_policy" {
  bucket = aws_s3_bucket.primary.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.primary.arn}/*"
    }]
  })
}

# Secondary (in alias provider)
resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = local.secondary_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "secondary_versioning" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "secondary_public_block" {
  provider = aws.secondary
  bucket = aws_s3_bucket.secondary.id

  block_public_acls   = true
  block_public_policy = false
  ignore_public_acls  = true
  restrict_public_buckets = false
}



# S3 Website Configuration (replaces deprecated website block)
###############################
resource "aws_s3_bucket_website_configuration" "primary_site" {
  bucket = aws_s3_bucket.primary.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_website_configuration" "secondary_site" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Construct website endpoints (S3 static website endpoint pattern)
# Format: <bucket>.s3-website-<region>.amazonaws.com
locals {
  primary_website_endpoint   = "${aws_s3_bucket.primary.bucket}.s3-website-${var.primary_region}.amazonaws.com"
  secondary_website_endpoint = "${aws_s3_bucket.secondary.bucket}.s3-website-${var.secondary_region}.amazonaws.com"
}


# IAM Role & Policy for Replication
###############################
resource "aws_iam_role" "replication_role" {
  name = "${var.project_name}-replication-role-${random_id.rand.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication_policy" {
  role = aws_iam_role.replication_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
          "s3:GetObjectVersion"
        ]
        Resource = ["${aws_s3_bucket.primary.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = ["${aws_s3_bucket.secondary.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [aws_s3_bucket.primary.arn]
      }
    ]
  })
}


# S3 Replication configuration (primary -> secondary)
###############################
resource "aws_s3_bucket_replication_configuration" "replication" {
  bucket = aws_s3_bucket.primary.id
  role   = aws_iam_role.replication_role.arn

  depends_on = [
    aws_s3_bucket_versioning.primary_versioning,
    aws_s3_bucket_versioning.secondary_versioning
  ]

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {
      # empty filter => entire bucket
    }

    destination {
      bucket        = aws_s3_bucket.secondary.arn
      storage_class = "STANDARD"
      
    }

     delete_marker_replication {
      status = "Disabled"  # or "Enabled" if you want delete markers replicated
    }
  }
}


# CloudFront Distribution with Origin Group failover
# Using S3 static website endpoints as custom origins (http)
###############################
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "Multi-region static website CDN for ${var.project_name}"

  origin {
    domain_name = local.primary_website_endpoint
    origin_id   = "primary-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = local.secondary_website_endpoint
    origin_id   = "secondary-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Origin Group (primary -> secondary)
  origin_group {
    origin_id = "origin-group-1"

    failover_criteria {
      status_codes = [403,404, 500, 502, 503, 504]
    }

    member {
      origin_id = "primary-origin"
    }

    member {
      origin_id = "secondary-origin"
    }
  }

  default_cache_behavior {
    target_origin_id       = "origin-group-1"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 60
    max_ttl     = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  price_class = "PriceClass_All"
  tags = {
    Name = "${var.project_name}-cdn"
  }
}


# SNS Topic + subscription
###############################
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${random_id.rand.hex}"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}


# CloudWatch Alarms (example: CloudFront 4xx 5xx error rate)
###############################
resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx_5xx" {
  alarm_name          = "${var.project_name}-cloudfront-4xx-5xx-${random_id.rand.hex}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4xx5xxErrorRate"
  namespace           = "AWS/CloudFront"
  statistic           = "Average"
  period              = 300
  threshold           = 0.01
  alarm_description   = "CloudFront 4xx5xxErrorRate > 0.01"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = aws_cloudfront_distribution.cdn.id
    Region         = "Global"
  }
}


# CloudWatch Dashboard - rendered from template
###############################
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = templatefile("${path.module}/dashboard.json.tpl", {
    distribution_id = aws_cloudfront_distribution.cdn.id
    primary_bucket  = aws_s3_bucket.primary.bucket
    secondary_bucket = aws_s3_bucket.secondary.bucket
  })
}




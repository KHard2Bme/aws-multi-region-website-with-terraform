locals {
  distribution_comment = "Multi-Region static site CDN"
  random_suffix = random_id.rep_suffix.hex
}

resource "random_id" "rep_suffix" {
  byte_length = 3
}


# S3 Buckets (website endpoints)
# ----------------------------------------
resource "aws_s3_bucket" "site_primary" {
  provider = aws.primary
  bucket   = var.site_bucket_name_primary
  acl      = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  versioning {
    enabled = true
  }

  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "primary_public_block" {
  provider = aws.primary
  bucket = aws_s3_bucket.site_primary.id

  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket" "site_secondary" {
  provider = aws.secondary
  bucket   = var.site_bucket_name_secondary
  acl      = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  versioning {
    enabled = true
  }

  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "secondary_public_block" {
  provider = aws.secondary
  bucket = aws_s3_bucket.site_secondary.id

  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}


# IAM role and policy for S3 replication (primary -> secondary)
# ----------------------------------------
resource "aws_iam_role" "s3_replication_role" {
  name = "s3-replication-role-${local.random_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_replication_policy" {
  name = "s3-replication-policy-${local.random_suffix}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.site_primary.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectLegalHold",
          "s3:GetObjectRetention",
          "s3:GetObjectVersionTagging"
        ]
        Resource = [
          "${aws_s3_bucket.site_primary.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = [
          "${aws_s3_bucket.site_secondary.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_replication" {
  role       = aws_iam_role.s3_replication_role.name
  policy_arn = aws_iam_policy.s3_replication_policy.arn
}


# S3 Replication configuration (primary -> secondary)
# ----------------------------------------
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.primary
  bucket   = aws_s3_bucket.site_primary.id
  role     = aws_iam_role.s3_replication_role.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket        = aws_s3_bucket.site_secondary.arn
      storage_class = "STANDARD"
    }
  }
}


# ACM certificate (in us-east-1) - optional: used only if domain provided
# If you do not own a domain, use default CloudFront cert (see below)
# ----------------------------------------
resource "aws_acm_certificate" "cert" {
  provider = aws.us_east_1
  count    = var.use_custom_domain ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

# If using domain validation via Route53
resource "aws_route53_record" "cert_validation" {
  count   = var.use_custom_domain && length(aws_acm_certificate.cert) > 0 ? length(aws_acm_certificate.cert[0].domain_validation_options) : 0
  zone_id = var.hosted_zone_id
  name    = aws_acm_certificate.cert[0].domain_validation_options[count.index].resource_record_name
  type    = aws_acm_certificate.cert[0].domain_validation_options[count.index].resource_record_type
  ttl     = 60
  records = [aws_acm_certificate.cert[0].domain_validation_options[count.index].resource_record_value]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  provider = aws.us_east_1
  count    = var.use_custom_domain ? 1 : 0

  certificate_arn = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = var.use_custom_domain ? [for r in aws_route53_record.cert_validation : r.fqdn] : []
}


# CloudFront distribution
# - uses S3 website endpoints as custom origins (HTTP)
# - origin_group created for failover
# ----------------------------------------
resource "aws_cloudfront_distribution" "cdn" {
  depends_on = [
    aws_s3_bucket.site_primary,
    aws_s3_bucket.site_secondary
  ]

  enabled = true
  comment = local.distribution_comment

  origin {
    domain_name = aws_s3_bucket.site_primary.website_endpoint
    origin_id   = "S3Primary"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = aws_s3_bucket.site_secondary.website_endpoint
    origin_id   = "S3Secondary"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin_group {
    origin_id = "Primary-Secondary-Group"

    members {
      origin_id = "S3Primary"
    }
    members {
      origin_id = "S3Secondary"
    }

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "Primary-Secondary-Group"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Use custom domain certificate if provided, otherwise default CloudFront cert (no custom domain)
  viewer_certificate {
    dynamic "acm" {
      for_each = var.use_custom_domain && length(aws_acm_certificate.cert) > 0 ? [1] : []
      content {
        acm_certificate_arn = aws_acm_certificate.cert[0].arn
        ssl_support_method  = "sni-only"
      }
    }

    # if not using custom domain, use default CloudFront cert (commented - Terraform requires specifying default cert via cloudfront)
    # note: leaving viewer_certificate block empty would error; using a conditional:
    # To let Terraform use the default CloudFront certificate for the distribution (no custom domain),
    # define the block with cloudfront_default_certificate = true
    cloudfront_default_certificate = var.use_custom_domain ? false : true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_All"

  tags = {
    Name = "multi-region-static-site-cdn"
  }
}


# SNS Topic and Subscriptions
# ----------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "SiteFailoverAlerts-${local.random_suffix}"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.contact_email
}

resource "aws_sns_topic_subscription" "sms_sub" {
  count     = var.contact_sms == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "sms"
  endpoint  = var.contact_sms
}


# CloudWatch Alarms that publish to SNS
# ----------------------------------------
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_alarm" {
  alarm_name          = "CloudFront-5xx-Alarm-${local.random_suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  statistic           = "Average"
  period              = 300
  threshold           = 0.01
  alarm_description   = "CloudFront 5xx error rate exceeded threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = aws_cloudfront_distribution.cdn.id
    Region         = "Global"
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_primary_5xx_alarm" {
  alarm_name          = "S3Primary-5xx-Alarm-${local.random_suffix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrors"
  namespace           = "AWS/S3"
  statistic           = "Sum"
  period              = 300
  threshold           = 1
  alarm_description   = "S3 primary bucket reported 5xx errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    BucketName  = aws_s3_bucket.site_primary.id
    StorageType = "AllStorageTypes"
  }
}


# CloudWatch Dashboard JSON (simple)
# ----------------------------------------
data "template_file" "dashboard" {
  template = <<EOF
{
  "widgets":[
    {
      "type":"metric",
      "x":0,"y":0,"width":24,"height":6,
      "properties":{
        "metrics":[
          [ "AWS/CloudFront","5xxErrorRate","DistributionId","${aws_cloudfront_distribution.cdn.id}","Region","Global"]
        ],
        "period":300,
        "title":"CloudFront 5xx Error Rate",
        "view":"timeSeries"
      }
    },
    {
      "type":"metric",
      "x":0,"y":6,"width":12,"height":6,
      "properties":{
        "metrics":[
          [ "AWS/CloudFront","Requests","DistributionId","${aws_cloudfront_distribution.cdn.id}","Region","Global"]
        ],
        "period":300,
        "title":"CloudFront Request Volume",
        "view":"timeSeries"
      }
    },
    {
      "type":"metric",
      "x":12,"y":6,"width":12,"height":6,
      "properties":{
        "metrics":[
          ["AWS/S3","4xxErrors","BucketName","${aws_s3_bucket.site_primary.id}","StorageType","AllStorageTypes"],
          ["AWS/S3","5xxErrors","BucketName","${aws_s3_bucket.site_primary.id}","StorageType","AllStorageTypes"]
        ],
        "period":300,
        "title":"S3 Primary Errors (4xx/5xx)",
        "view":"timeSeries"
      }
    }
  ]
}
EOF
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "StaticSite-HA-Dashboard-${local.random_suffix}"
  dashboard_body = data.template_file.dashboard.rendered
}




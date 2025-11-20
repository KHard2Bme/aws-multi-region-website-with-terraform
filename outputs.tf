output "cloudfront_domain" {
  description = "CloudFront distribution domain name (use this URL to access the site)"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "s3_primary_bucket" {
  description = "Primary S3 bucket name"
  value       = aws_s3_bucket.site_primary.id
}

output "s3_secondary_bucket" {
  description = "Secondary S3 bucket name"
  value       = aws_s3_bucket.site_secondary.id
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.dashboard.dashboard_name
}

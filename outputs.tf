output "cloudfront_domain" {
  description = "CloudFront distribution domain to use as website URL"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "primary_bucket_name" {
  value = aws_s3_bucket.primary.bucket
}

output "secondary_bucket_name" {
  value = aws_s3_bucket.secondary.bucket
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}


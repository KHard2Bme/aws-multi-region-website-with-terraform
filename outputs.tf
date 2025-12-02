output "primary_az_endpoints" {
  value = [for i in aws_instance.primary : i.public_dns]
}

output "secondary_region_endpoint" {
  value = aws_instance.secondary.public_dns
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.site.domain_name
}



output "primary_alb_dns" {
  value = aws_lb.primary_lb.dns_name
}

output "secondary_alb_dns" {
  value = aws_lb.secondary_lb.dns_name
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.site.domain_name
}




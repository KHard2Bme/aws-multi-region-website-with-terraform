variable "primary_region" {
  type    = string
  default = "us-east-1"
}

variable "secondary_region" {
  type    = string
  default = "us-west-2"
}

variable "site_bucket_name_primary" {
  type        = string
  description = "Unique name for the primary S3 website bucket"
  default     = "ha-static-site-primary-example-12345"
}

variable "site_bucket_name_secondary" {
  type        = string
  description = "Unique name for the secondary S3 website bucket"
  default     = "ha-static-site-secondary-example-12345"
}

variable "use_custom_domain" {
  type    = bool
  default = false
  description = "If true, provide domain_name and hosted_zone_id to automatically validate ACM via Route53."
}

variable "domain_name" {
  type        = string
  default     = ""
  description = "Your domain name (if you own one and want to use it). Leave empty if not using a custom domain."
}

variable "hosted_zone_id" {
  type        = string
  default     = ""
  description = "Route53 hosted zone ID for domain validation. Required only if use_custom_domain = true."
}

variable "contact_email" {
  type        = string
  description = "Email address to subscribe to SNS alerts"
  default     = "your.email@example.com"
}

variable "contact_sms" {
  type        = string
  description = "Optional: phone number (E.164) for SMS alerts, e.g. +15551234567. Leave empty to skip SMS."
  default     = ""
}

variable "primary_region" {
  type    = string
  default = "us-east-1"
  description = "Primary AWS region (website origin)"
}

variable "secondary_region" {
  type    = string
  default = "us-west-2"
  description = "Secondary AWS region (replica origin)"
}

variable "project_name" {
  type    = string
  default = "multi-region-static-site"
}

variable "notification_email" {
  type        = string
  description = "Email address to subscribe to SNS alerts (must confirm subscription)"
}

variable "primary_bucket_name" {
  type        = string
  description = "Optional explicit primary bucket name. Leave empty to auto-generate."
  default     = ""
}

variable "secondary_bucket_name" {
  type        = string
  description = "Optional explicit secondary bucket name. Leave empty to auto-generate."
  default     = ""
}


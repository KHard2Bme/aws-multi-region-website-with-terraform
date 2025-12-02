variable "primary_region" {
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  type        = string
  default     = null
}

variable "sns_email" {
  type        = string
}

variable "az_count" {
  type        = number
  default     = 2
}



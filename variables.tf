variable "primary_region" {
  type    = string
  default = "us-east-1"
}

variable "secondary_region" {
  type    = string
  default = "us-west-2"
}

variable "primary_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "secondary_vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "primary_azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "secondary_azs" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b"]
}

variable "primary_public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "secondary_public_subnets" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "ami_id" {
  type = string
}

variable "ami_id2" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "Email address for SNS CloudWatch alerts"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type    = string
  default = "LUIT_Linux1_Keys"
}



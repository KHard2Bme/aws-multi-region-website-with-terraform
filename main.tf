# Networking (Primary Region)
##############################
resource "aws_vpc" "primary" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "primary_az" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

data "aws_availability_zones" "available" {}

# Security Group
####################
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Allow inbound HTTP from the internet"
  vpc_id      = aws_vpc.primary.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instances in each AZ (Primary Region)
###########################################
resource "aws_instance" "primary" {
  count         = var.az_count
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.primary_az[count.index].id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "PRIMARY REGION – AZ ${count.index}" > /usr/share/nginx/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF

  tags = {
    Name = "primary-az-${count.index}"
  }
}

data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
}

# EC2 Instance (Secondary Region)
##############################
resource "aws_vpc" "secondary" {
  provider   = aws.secondary
  cidr_block = "10.1.0.0/16"
}

resource "aws_subnet" "secondary" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "secondary_web" {
  provider    = aws.secondary
  vpc_id      = aws_vpc.secondary.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "secondary" {
  provider                = aws.secondary
  ami                     = data.aws_ami.al2023.id
  instance_type           = var.instance_type
  subnet_id               = aws_subnet.secondary.id
  vpc_security_group_ids  = [aws_security_group.secondary_web.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    echo "SECONDARY REGION FAILOVER" > /usr/share/nginx/html/index.html
    systemctl enable nginx
    systemctl start nginx
  EOF
}

# Cloudfront Distribution with Origin Group
##############################################
resource "aws_cloudfront_distribution" "site" {
  origin_group {
    origin_id = "primary-group"
    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }
    members {
      origin_id = "primary-origin"
    }
    members {
      origin_id = "secondary-origin"
    }
  }

  origin {
    domain_name = aws_instance.primary[0].public_dns
    origin_id   = "primary-origin"
  }

  origin {
    domain_name = aws_instance.secondary.public_dns
    origin_id   = "secondary-origin"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = "primary-group"
    viewer_protocol_policy = "allow-all"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# SNS + Alarm + Dashboard
##################################
resource "aws_sns_topic" "alerts" {
  name = "cloudfront-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.sns_email
}

resource "aws_cloudwatch_metric_alarm" "cf_5xx" {
  alarm_name          = "CloudFront-5xx-Errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 10
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  statistic           = "Sum"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "cf_dashboard" {
  dashboard_name = "CloudFront-Regional-Failover"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0, "y": 0, "width": 24, "height": 6,
      "properties": {
        "metrics": [
          [ "AWS/CloudFront", "5xxErrorRate", "DistributionId", "${aws_cloudfront_distribution.site.id}" ]
        ],
        "period": 300,
        "stat": "Sum",
        "title": "CloudFront 5xx Errors"
      }
    }
  ]
}
EOF
}




#####################################
# Primary VPC (multi-AZ)
#####################################

module "primary_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "primary-vpc"
  cidr = var.primary_vpc_cidr

  azs            = var.primary_azs
  public_subnets = var.primary_public_subnets

 map_public_ip_on_launch = true 
}

#####################################
# Secondary VPC (single region failover)
#####################################

module "secondary_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  providers = {
    aws = aws.secondary
  }

  name = "secondary-vpc"
  cidr = var.secondary_vpc_cidr

  azs            = var.secondary_azs
  public_subnets = var.secondary_public_subnets

  map_public_ip_on_launch = true
}

#####################################
# Security Group for ALBs + EC2
#####################################

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP traffic"
  vpc_id      = module.primary_vpc.vpc_id

  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    description = "Allow SSH (restricted)"
    from_port   = 22
    to_port     = 22
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

resource "aws_security_group" "web_sg_secondary" {
  name        = "web-sg-secondary"
  description = "Allow HTTP traffic"
  vpc_id      = module.secondary_vpc.vpc_id
  provider    = aws.secondary

  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Allow SSH (restricted)"
    from_port   = 22
    to_port     = 22
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

#####################################
# EC2 Instances (Primary Region)
#####################################

resource "aws_instance" "primary" {
  count                  = 2
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = module.primary_vpc.public_subnets[count.index]
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = filebase64("${path.module}/user_data_primary.sh")

  associate_public_ip_address = true

  tags = {
    Name = "primary-${count.index}"
  }
}


#####################################
# EC2 Instances (Secondary Region)
#####################################

resource "aws_instance" "secondary" {
  count                  = 1
  ami                    = var.ami_id2
  instance_type          = var.instance_type
  subnet_id              = module.secondary_vpc.public_subnets[0]
  key_name               = var.key_name
  provider               = aws.secondary
  vpc_security_group_ids = [aws_security_group.web_sg_secondary.id]

  user_data = filebase64("${path.module}/user_data_secondary.sh")

  associate_public_ip_address = true

  tags = {
    Name = "secondary-0"
  }
}


#####################################
# Primary ALB
#####################################

resource "aws_lb" "primary_lb" {
  name               = "primary-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = module.primary_vpc.public_subnets
}

resource "aws_lb_target_group" "primary_tg" {
  name     = "primary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.primary_vpc.vpc_id

  health_check {
    path = "/"
    port = "80"
  }
}

resource "aws_lb_target_group_attachment" "primary_attachments" {
  count            = length(aws_instance.primary)
  target_group_arn = aws_lb_target_group.primary_tg.arn
  target_id        = aws_instance.primary[count.index].id
  port             = 80
}

resource "aws_lb_listener" "primary_listener" {
  load_balancer_arn = aws_lb.primary_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary_tg.arn
  }
}

#####################################
# Secondary ALB (Failover Region)
#####################################

resource "aws_lb" "secondary_lb" {
  provider           = aws.secondary
  name               = "secondary-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg_secondary.id]
  subnets            = module.secondary_vpc.public_subnets
}

resource "aws_lb_target_group" "secondary_tg" {
  provider = aws.secondary

  name     = "secondary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.secondary_vpc.vpc_id

  health_check {
    path = "/"
    port = "80"
  }
}

resource "aws_lb_target_group_attachment" "secondary_attach" {
  provider = aws.secondary

  target_group_arn = aws_lb_target_group.secondary_tg.arn
  target_id        = aws_instance.secondary[0].id
  port             = 80
}

resource "aws_lb_listener" "secondary_listener" {
  provider = aws.secondary

  load_balancer_arn = aws_lb.secondary_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.secondary_tg.arn
  }
}

#####################################
# CloudFront Distribution
#####################################

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_lb.primary_lb.dns_name
    origin_id   = "primary-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = aws_lb.secondary_lb.dns_name
    origin_id   = "secondary-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin_group {
    origin_id = "group-1"

    member {
      origin_id = "primary-origin"
    }

    member {
      origin_id = "secondary-origin"
    }

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }
  }

  default_cache_behavior {
    target_origin_id       = "group-1"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}




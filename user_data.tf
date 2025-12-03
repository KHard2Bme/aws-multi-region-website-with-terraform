variable "primary_user_data" {
  type    = string
  default = <<-EOF
              #!/bin/bash
              yum install -y nginx
              echo "<h1>PRIMARY REGION - Instance \${INSTANCE_ID}</h1>" > /usr/share/nginx/html/index.html
              systemctl enable nginx
              systemctl start nginx
              EOF
}

variable "secondary_user_data" {
  type    = string
  default = <<-EOF
              #!/bin/bash
              yum install -y nginx
              echo "<h1>SECONDARY REGION - Failover Instance</h1>" > /usr/share/nginx/html/index.html
              systemctl enable nginx
              systemctl start nginx
              EOF
}

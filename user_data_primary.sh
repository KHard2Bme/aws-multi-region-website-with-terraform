#!/bin/bash

# Update packages
dnf update -y

# Install NGINX (Amazon Linux 2023 uses dnf)
dnf install -y nginx

# Enable and start NGINX
systemctl enable nginx
systemctl start nginx

# Create webpage
echo "<h1>PRIMARY REGION - Served from us-east-1</h1>" > /usr/share/nginx/html/index.html



#!/bin/bash

# Update packages
dnf update -y

# Install NGINX
dnf install -y nginx

# Enable and start NGINX
systemctl enable nginx
systemctl start nginx

# Create webpage
echo "<h1>SECONDARY REGION - Served from us-west-2</h1>" > /usr/share/nginx/html/index.html



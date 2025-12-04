#!/bin/bash
yum clean metadata
yum update -y
yum install -y nginx

systemctl enable nginx
systemctl start nginx

echo "<h1>PRIMARY REGION</h1>" > /usr/share/nginx/html/index.html


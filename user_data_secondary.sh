#!/bin/bash
yum update -y
yum install -y nginx

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

echo "<h1>SECONDARY REGION - Failover Instance $INSTANCE_ID - AZ $AZ</h1>" > /usr/share/nginx/html/index.html

systemctl enable nginx
systemctl start nginx

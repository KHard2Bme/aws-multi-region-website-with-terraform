#!/bin/bash
# update packages
yum update -y
# install NGINX
yum install -y nginx
# enable and start NGINX
systemctl enable nginx
systemctl start nginx
# create a simple index.html page
echo "<h1>PRIMARY REGION! served from us-east-1. </h1>" > /usr/share/nginx/html/index.html


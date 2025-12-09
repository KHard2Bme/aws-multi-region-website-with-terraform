#!/bin/bash
yum update -y
# install NGINX
yum install -y nginx
# enable and start NGINX
systemctl enable nginx
systemctl start nginx
# create a simple index.html page
echo "<h1>SECONDARY REGION! served from us-west-2. </h1>" > /usr/share/nginx/html/index.html


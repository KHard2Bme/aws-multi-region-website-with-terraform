# 🚀 Multi-AZ & Multi-Region Failover Testing with AWS CloudFront, EC2, SNS & CloudWatch

### Fully Automated with Terraform

This project deploys a complete **high-availability failover testing
environment** on AWS using Terraform.\
It allows you to **simulate Availability Zone failure** *and* **full
regional failure**, and verify:

-   CloudFront origin group failover\
-   Multi-AZ redundancy inside one region\
-   Cross-region failover\
-   CloudWatch 5xx error alarms\
-   SNS email notifications\
-   Dashboard visualization

This project is ideal for **disaster recovery testing**, **resiliency
demos**, **training labs**, and **CloudFront failover validation**.

------------------------------------------------------------------------

## ✨ Features

### 🏢 **Primary Region (Multi-AZ Redundant)**

-   Custom VPC\
-   2 public subnets (each in different AZs)\
-   2 EC2 web servers (NGINX)\
-   Each instance serves a different HTML message for identification\
-   Used as the **primary origin group member**

### 🌎 **Secondary Region (Regional Failover)**

-   Separate VPC\
-   1 public subnet\
-   1 EC2 web server (NGINX)\
-   Used when entire primary region fails

### 🌐 **CloudFront Distribution**

-   Origin group with failover criteria\
-   Primary region → Secondary region\
-   Failover triggers on: 500, 502, 503, 504\
-   Public CDN endpoint output after deployment

### 🔔 **Monitoring & Alerts**

-   SNS email notifications\
-   CloudWatch alarm for 5xx errors\
-   CloudWatch dashboard with charts\
-   Designed to spike when AZ or region fails

------------------------------------------------------------------------

# 📁 Repository Structure

    /
    ├── failover-test.sh
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    └── README.md

------------------------------------------------------------------------

# 🧰 Prerequisites

Before deploying, ensure you have:

-   AWS account\
-   IAM user with admin access\
-   Terraform v1.2+\
-   AWS CLI configured\
-   SSH key pair (optional)

------------------------------------------------------------------------

# ⚙️ Terraform Deployment

### 1. Clone the Repository

``` bash
git clone https://github.com/<your-repo>/cloudfront-multi-region-failover.git
cd cloudfront-multi-region-failover
```

### 2. Configure Variables

Update `variables.tf` with:

    primary_region    = "us-east-1"
    secondary_region  = "us-west-2"
    sns_email         = "your-email@example.com"

Confirm the SNS email subscription after running `terraform apply`.

### 3. Initialize Terraform

``` bash
terraform init
```

### 4. Plan Deployment

``` bash
terraform plan
```

### 5. Apply Deployment

``` bash
terraform apply
```

------------------------------------------------------------------------

# 🏁 Outputs

You will receive:

-   CloudFront domain\
-   Public DNS of EC2 instances\
-   Secondary region failover endpoint

------------------------------------------------------------------------

# 🔥 Failover Testing Guide

## **🟦 Scenario 1 --- AZ Failure**

Stop ONE EC2 instance in the primary region.

Expected: - CloudFront still serves traffic\
- No regional failover\
- Minimal 5xx

------------------------------------------------------------------------

## **🟥 Scenario 2 --- Regional Failure**

Stop ALL EC2 instances in the primary region.

Expected: - CloudFront fails over to secondary region\
- SNS alert triggered\
- 5xx spike on dashboard

------------------------------------------------------------------------

# 📄 Automated Failover Test Script

See `failover-test.sh` in the repo for real-time monitoring.

------------------------------------------------------------------------

# 📊 Dashboard

Find it under:

    CloudFront-Regional-Failover

Shows 5xx trends during failovers.

------------------------------------------------------------------------

# 🧹 Cleanup

``` bash
terraform destroy
```

------------------------------------------------------------------------

# 📐 Architecture Diagram

    CloudFront → Origin Group
        ├── Primary Region (Multi-AZ)
        │     ├── EC2 AZ1
        │     └── EC2 AZ2
        └── Secondary Region (Failover)
              └── EC2

------------------------------------------------------------------------

# 🏆 Summary

This project provides:

✔ Multi-AZ redundancy\
✔ Multi-region failover\
✔ CloudFront origin routing\
✔ Alarms + notifications\
✔ Automated failover testing

Perfect for resiliency demos, DR validation, and training labs.

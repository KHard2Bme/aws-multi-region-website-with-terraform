# Multi-Region AWS Failover Infrastructure (Terraform)

This project deploys a **high‑availability, multi‑region failover
architecture** on AWS using **Terraform**.\
The primary region (`us-east-1`) serves all traffic normally, while a
secondary failover region (`us-west-2`) becomes active when the primary
fails.\
Failover is enabled through **CloudFront Origin Groups**, **ALBs**,
**EC2 instances**, and **CloudWatch alarms with SNS notifications**.

------------------------------------------------------------------------

## 🚀 Architecture Overview

### **Primary Region (us-east-1)**

-   VPC with public subnets (multi‑AZ)
-   Application Load Balancer (ALB)
-   EC2 Auto-hosted NGINX servers
-   CloudWatch alarms for ALB health
-   CloudFront primary origin

### **Secondary Region (us-west-2)**

-   VPC with public subnets (multi‑AZ)
-   ALB
-   EC2 failover instance
-   Region-specific CloudWatch alarms
-   CloudFront failover origin

### **Global Services**

  -----------------------------------------------------------------------
  Component                             Purpose
  ------------------------------------- ---------------------------------
  **CloudFront**                        Distributes traffic globally;
                                        handles failover via Origin
                                        Groups

  **CloudWatch Dashboard**              Visualizes ALB health, CloudFront
                                        errors, request metrics

  **SNS Notifications**                 Sends email alerts on alarm
                                        triggers
  -----------------------------------------------------------------------

### **Terraform Features Used**

-   Multiple providers (`aws` + `aws.secondary`)
-   Modular VPC deployments
-   Cross-region CloudWatch alarms
-   CloudFront failover-based origin group
-   Auto-generated CloudWatch Dashboard
-   SNS email alerts
-   ALB target group health monitoring

------------------------------------------------------------------------

## 📁 Repository Structure

    ├── main.tf                 # Main AWS architecture
    ├── providers.tf            # Multi-region provider configuration
    ├── variables.tf            # Input variables
    ├── outputs.tf              # Terraform outputs
    ├── cloudwatch.tf           # Alarms, dashboard, and SNS
    ├── failover-test.sh        # Shell script for real failover testing
    └── README.md               # Project documentation

------------------------------------------------------------------------

## 🧩 Key Components Breakdown

### **1. VPC Deployments**

Primary VPC and Secondary VPC created using `terraform-aws-modules/vpc`.

### **2. EC2 Instances**

-   Primary region: 2 EC2 servers across 2 AZs\
-   Secondary region: 1 EC2 server for failover\
-   All instances run a simple NGINX page identifying their region

### **3. Application Load Balancers**

Each region has its own ALB with: - Security groups - Target groups -
Listener rules - Health checks for failover eligibility

### **4. CloudFront Global Distribution**

Configured with: - Two origins (Primary/Secondary ALBs) - Origin Group
for automatic failover - HTTPS enforcement - Global caching rules

### **5. CloudWatch Alarms**

-   CloudFront 5xx Error Rate
-   Primary ALB unhealthy hosts
-   Secondary ALB unhealthy hosts (region-specific provider)

All alarms notify via SNS email.

### **6. CloudWatch Dashboard**

Displays: - CloudFront metrics - ALB host health per region - Request
counts - Single-value health indicators

### **7. SNS Alerts**

One SNS topic (`multi-region-failover-alerts`) with an email
subscription.

### **8. Failover Test Script**

`failover-test.sh` simulates failures to validate: - ALB health checks -
CloudFront failover behavior - Secondary region promotion

------------------------------------------------------------------------

## 🛠️ Deploying This Project

### **1. Initialize Terraform**

``` sh
terraform init
```

### **2. Review the plan**

``` sh
terraform plan
```

### **3. Apply changes**

``` sh
terraform apply
```

### **4. Confirm SNS Email Subscription**

Check your inbox and confirm the subscription email.

------------------------------------------------------------------------

## 🧪 Testing Failover

Run:

``` sh
bash failover-test.sh
```

The script: - Sends test HTTP requests through CloudFront - Monitors
failover behavior - Helps validate CloudFront → ALB → EC2 path

------------------------------------------------------------------------

## 📬 Outputs

After apply, Terraform provides: - ALB DNS names - CloudFront domain -
Useful URLs for testing

------------------------------------------------------------------------

## 👤 Author

Created as part of a fully automated multi-region AWS failover system
using Terraform and CloudWatch.

------------------------------------------------------------------------

## 📄 License

MIT License

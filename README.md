# Multi-Region AWS Infrastructure with CloudFront Failover

This repository contains Terraform code that deploys a highly available
multi-region architecture using AWS services. The solution includes:

-   Multi-region EC2 instances (primary + secondary)
-   Application Load Balancers (ALB) in each region
-   CloudFront with Origin Groups for automatic failover
-   CloudWatch alarms for primary/secondary health
-   SNS notifications for failover and recovery
-   A global CloudWatch dashboard
-   Fully parameterized infrastructure via `variables.tf`

------------------------------------------------------------------------

## 🚀 Features

### **1. Highly Available Architecture**

-   Primary region (`us-east-1`) hosts two EC2 instances behind an ALB.
-   Secondary region (`us-west-2`) hosts a backup EC2 instance and ALB.
-   CloudFront Origin Group provides regional failover.

### **2. Automated Failover**

When the primary origin becomes unhealthy: - CloudFront automatically
switches to the secondary region. - Alerts are triggered via SNS. -
Recovery notifications are sent when the primary becomes healthy again.

### **3. Monitoring & Observability**

CloudWatch monitoring includes: - ALB HealthyHostCount alarms (primary &
secondary) - EC2 CPU & Status checks - CloudFront performance metrics -
A unified CloudWatch dashboard

### **4. Complete Terraform Automation**

-   Fully modular and parameterized.
-   Supports quick region changes.
-   Uses separate providers for multi-region deployments.

------------------------------------------------------------------------

## 🗂 Repository Structure

    ├── cloudwatch.tf
    ├── failover-test.sh
    ├── failover.log
    ├── main.tf
    ├── outputs.tf
    ├── providers.tf
    ├── README.md  
    ├── user_data_primary.sh
    ├── user_data_secondary.sh
    ├── variables.tf

------------------------------------------------------------------------

## ⚙️ Requirements

-   Terraform ≥ 1.0
-   AWS CLI configured with proper IAM permissions
-   A verified email address for SNS alerts

------------------------------------------------------------------------

## 🔧 Deployment Instructions

### **1. Initialize Terraform**

    terraform init

### **2. Review the execution plan**

    terraform plan

### **3. Deploy the infrastructure**

    terraform apply

### **4. Destroy the environment (optional)**

    terraform destroy

------------------------------------------------------------------------

## 🧪 Failover Testing Guide

A full failover runbook is included:

### **AZ-Level Failover**

-   Stop one EC2 instance in primary region.
-   ALB HealthyHostCount should drop but traffic stays served.
-   No CloudFront failover should occur.

### **Region-Level Failover**

-   Stop *both* instances in the primary region.
-   ALB HealthyHostCount → 0 triggers SNS alarm.
-   CloudFront switches to secondary origin.
-   Restore primary instances and validate recovery.

A downloadable checklist is available in the repository.

------------------------------------------------------------------------

## 📈 CloudWatch Dashboard

The included dashboard shows:

-   Primary/Secondary ALB health
-   EC2 metrics per region
-   CloudFront 5xx errors
-   Real-time load distribution

------------------------------------------------------------------------

## 📬 SNS Alerting

You will receive email notifications for: - Primary ALB health failure -
Recovery of ALB/EC2 instances - Secondary region issues (if any)

Be sure to confirm the subscription from AWS SNS before testing.

------------------------------------------------------------------------

## 🤝 Contributions

Pull requests and feature suggestions are welcome.\
Feel free to submit improvements for automation, monitoring, or failover
logic.

------------------------------------------------------------------------

## 📄 License

This project is licensed under the MIT License.


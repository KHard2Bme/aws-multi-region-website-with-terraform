# Multi-Region Highly Available Static Website on AWS (Terraform)

[![Terraform](https://img.shields.io/badge/Terraform-IaC-5C4EE5.svg)](https://www.terraform.io/)\
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange.svg)](https://aws.amazon.com/)\
[![CloudFront](https://img.shields.io/badge/CloudFront-Multi--Region%20Failover-blueviolet.svg)](https://aws.amazon.com/cloudfront/)\
[![S3](https://img.shields.io/badge/S3-Static%20Hosting-green.svg)](https://aws.amazon.com/s3/)\
[![License](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)

A fully automated **Intermediate-Level AWS Project** built using
**Terraform**, featuring a multi-region static website using CloudFront
Origin Groups, S3 replication, CloudWatch monitoring, and SNS email
alerts --- **without requiring a custom domain**.

------------------------------------------------------------------------

## ⭐ Features

-   🌎 **Primary Region:** us-east-1\
-   🗺️ **Secondary Region:** us-west-2\
-   📦 S3 static website hosting (primary + secondary)\
-   🔁 Cross-Region Replication (CRR)\
-   🌐 CloudFront with **Origin Group Failover**\
-   📬 SNS email notifications\
-   📊 CloudWatch Dashboard (ready-to-import JSON)\
-   🩺 Optional CloudWatch **Synthetics Canaries**\
-   🚀 100% Infrastructure-as-Code (Terraform)\
-   ❌ No Route 53 or domain name required

------------------------------------------------------------------------

## 📁 Repository Structure

    /providers.tf
    /variables.tf
    /main.tf
    /outputs.tf
    /README.md

------------------------------------------------------------------------

## 📝 Prerequisites

-   AWS account\
-   AWS CLI installed + configured\
-   Terraform v1.5+\
-   Verified email for SNS subscription

------------------------------------------------------------------------

## 🚀 Deployment

1.  Initialize Terraform\

```{=html}
<!-- -->
```
    terraform init

2.  Review the changes\

```{=html}
<!-- -->
```
    terraform plan

3.  Deploy\

```{=html}
<!-- -->
```
    terraform apply

4.  After deployment, Terraform outputs your CloudFront URL:

```{=html}
<!-- -->
```
    d123exampleabcd.cloudfront.net

------------------------------------------------------------------------

## 🔔 Notifications

SNS sends an email alert when: - CloudFront 5xx errors increase\
- S3 replication issues occur (optional alarm)\
- Synthetic canary health checks fail

------------------------------------------------------------------------

## 🧩 Notes

-   CloudFront Origin Groups **are automatically created** in
    Terraform.\
-   No CLI JSON is required unless you want advanced customization.\
-   index.html and error.html must be uploaded to S3 manually unless
    automated.

------------------------------------------------------------------------

## 📜 License

MIT License © 2025

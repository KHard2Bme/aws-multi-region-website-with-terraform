##################################################
# SNS topics: primary (existing) + secondary (new)
##################################################

resource "aws_sns_topic" "alerts" {
  name = "multi-region-failover-alerts"
  # created in default provider (primary region)
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS topic in the secondary region (so alarms in us-west-2 can reference it)
resource "aws_sns_topic" "alerts_secondary" {
  provider = aws.secondary
  name     = "multi-region-failover-alerts-secondary"
}

resource "aws_sns_topic_subscription" "email_alert_secondary" {
  provider  = aws.secondary
  topic_arn = aws_sns_topic.alerts_secondary.arn
  protocol  = "email"
  endpoint  = var.alert_email
}


#############################################
# CloudWatch Metric Alarms
# - Primary alarms created in default provider (primary region)
# - Secondary alarm explicitly created using the aws.secondary provider
#############################################

# 1) CloudFront 5xx Error Rate alarm (Primary provider / primary region)
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  alarm_name          = "CloudFront-5xx-ErrorRate"
  alarm_description   = "Triggers when CloudFront 5xx error rate exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 60
  statistic           = "Average"
  threshold           = 1           # 1% 5xxErrorRate threshold (adjust as needed)
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  depends_on = [aws_cloudfront_distribution.site]
}

# 2) Primary ALB unhealthy host alarm (Primary provider / primary region)
resource "aws_cloudwatch_metric_alarm" "primary_alb_unhealthy" {
  alarm_name          = "Primary-ALB-Unhealthy-Hosts"
  alarm_description   = "Triggers when any primary ALB target becomes unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.primary_lb.arn_suffix
  }

  depends_on = [aws_lb.primary_lb, aws_lb_target_group.primary_tg]
}

# 3) Secondary ALB unhealthy host alarm (must be created in secondary region)
resource "aws_cloudwatch_metric_alarm" "secondary_alb_unhealthy" {
  provider            = aws.secondary
  alarm_name          = "Secondary-ALB-Unhealthy-Hosts"
  alarm_description   = "Triggers when any secondary ALB target becomes unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  # use the SNS topic in the secondary region
  alarm_actions       = [aws_sns_topic.alerts_secondary.arn]

  dimensions = {
    LoadBalancer = aws_lb.secondary_lb.arn_suffix
  }

  depends_on = [aws_lb.secondary_lb, aws_lb_target_group.secondary_tg]
}


#############################################
# CloudWatch Dashboard (created in primary region / default provider)
# Each widget MUST include "region" and "annotations" (empty object)
#############################################

resource "aws_cloudwatch_dashboard" "failover_dashboard" {
  dashboard_name = "Multi-Region-Failover-Dashboard"

  dashboard_body = jsonencode({
    widgets = [

      # CloudFront widget (global)
      {
        type = "metric"
        width = 24
        height = 6
        properties = {
          title = "CloudFront - Requests & 5xxErrorRate"
          region = var.primary_region
          annotations = {}
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
          ]
          view = "timeSeries"
          stacked = false
          period = 60
        }
      },

      # Primary ALB - Healthy vs Unhealthy
      {
        type = "metric"
        width = 24
        height = 6
        properties = {
          title = "Primary ALB - Healthy/Unhealthy Hosts"
          region = var.primary_region
          annotations = {}
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.primary_lb.arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.primary_lb.arn_suffix]
          ]
          view = "timeSeries"
          stacked = false
          period = 60
        }
      },

      # Secondary ALB - Healthy vs Unhealthy (explicit secondary region)
      {
        type = "metric"
        width = 24
        height = 6
        properties = {
          title = "Secondary ALB - Healthy/Unhealthy Hosts"
          region = var.secondary_region
          annotations = {}
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.secondary_lb.arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.secondary_lb.arn_suffix]
          ]
          view = "timeSeries"
          stacked = false
          period = 60
        }
      },

      # Single value: CloudFront 5xx error rate for quick glance
      {
        type = "metric"
        width = 6
        height = 6
        properties = {
          title = "CloudFront 5xx Error Rate (avg)"
          region = var.primary_region
          annotations = {}
          metrics = [
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
          ]
          view = "singleValue"
          period = 60
        }
      },

      # Primary ALB Request Count (traffic indicator)
      {
        type = "metric"
        width = 18
        height = 6
        properties = {
          title = "Primary ALB - Request Count"
          region = var.primary_region
          annotations = {}
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.primary_lb.arn_suffix]
          ]
          view = "timeSeries"
          period = 60
        }
      },

      # Secondary ALB Request Count (traffic indicator)
      {
        type = "metric"
        width = 18
        height = 6
        properties = {
          title = "Secondary ALB - Request Count"
          region = var.secondary_region
          annotations = {}
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.secondary_lb.arn_suffix]
          ]
          view = "timeSeries"
          period = 60
        }
      }
    ]
  })
}

#############################
# Notes:
# - Confirm SNS subscription via email after apply.
# - Ensure var.alert_email exists (variables.tf) and is set in terraform.tfvars.
# - The secondary alarm is created using provider = aws.secondary so it lands in the correct region.
# - If you still see region mismatch errors, run `terraform state show aws_lb.secondary_lb` to confirm the LB's ARN includes the expected region.
#############################



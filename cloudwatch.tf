###############################################
# SNS Topic + Email Subscription
###############################################

resource "aws_sns_topic" "alerts" {
  name = "multi-region-failover-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email   # ADD to variables.tf
}


###############################################
# CloudWatch Alarms
###############################################

# 1. CloudFront 5xx Errors Alarm
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  alarm_name          = "CloudFront-5xx-Errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 60
  statistic           = "Average"
  threshold           = 1  # 1% error rate triggers failover
  treat_missing_data  = "missing"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  alarm_description = "Triggers when CloudFront 5xx error rate exceeds 1%"
  alarm_actions     = [aws_sns_topic.alerts.arn]
}

# 2. Primary ALB Unhealthy Hosts Alarm
resource "aws_cloudwatch_metric_alarm" "primary_alb_unhealthy" {
  alarm_name          = "Primary-ALB-Unhealthy-Hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0  # If ANY hosts become unhealthy
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = aws_lb.primary_lb.arn_suffix
    TargetGroup  = aws_lb_target_group.primary_tg.arn_suffix
  }

  alarm_description = "Triggers when primary ALB targets are unhealthy"
  alarm_actions     = [aws_sns_topic.alerts.arn]
}

# 3. Secondary ALB Unhealthy Hosts Alarm (optional but recommended)
resource "aws_cloudwatch_metric_alarm" "secondary_alb_unhealthy" {
  provider = aws.secondary   

  alarm_name          = "Secondary-ALB-Unhealthy-Hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = aws_lb.secondary_lb.arn_suffix
    TargetGroup  = aws_lb_target_group.secondary_tg.arn_suffix
  }

  alarm_actions     = [aws_sns_topic.alerts.arn]
  alarm_description = "Triggers when secondary ALB targets are unhealthy"
}



###############################################
# CloudWatch Dashboard
###############################################

resource "aws_cloudwatch_dashboard" "failover_dashboard" {
  dashboard_name = "Multi-Region-Failover-Dashboard"

  dashboard_body = jsonencode({
    widgets = [

      # CloudFront Widget
      {
        "type": "metric",
        "width": 24,
        "height": 6,
        "properties": {
          "title": "CloudFront Requests & 5xx Errors",
          "region": "us-east-1",
          "annotations": {},
          "metrics": [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"],
            ["AWS/CloudFront", "5xxErrorRate", "DistributionId", aws_cloudfront_distribution.site.id, "Region", "Global"]
          ],
          "view": "timeSeries",
          "stacked": false,
          "period": 60
        }
      },

      # Primary ALB Widget
      {
        "type": "metric",
        "width": 24,
        "height": 6,
        "properties": {
          "title": "Primary ALB - Healthy vs Unhealthy Hosts",
          "region": "us-east-1",
          "annotations": {},
          "metrics": [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.primary_lb.arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.primary_lb.arn_suffix]
          ],
          "view": "timeSeries",
          "stacked": false,
          "period": 60
        }
      },

      # Secondary ALB Widget
      {
        "type": "metric",
        "width": 24,
        "height": 6,
        "properties": {
          "title": "Secondary ALB - Healthy vs Unhealthy Hosts",
          "region": "$(var.secondary_region)",
          "annotations": {},
          "metrics": [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.secondary_lb.arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.secondary_lb.arn_suffix]
          ],
          "view": "timeSeries",
          "stacked": false,
          "period": 60
        }
      }
    ]
  })
}


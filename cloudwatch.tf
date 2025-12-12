##########################################
# SNS Topics (Primary & Secondary)
##########################################

resource "aws_sns_topic" "alerts" {
  name = "primary-alerts-topic"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Secondary region SNS
resource "aws_sns_topic" "alerts_secondary" {
  provider = aws.secondary
  name     = "secondary-alerts-topic"
}

resource "aws_sns_topic_subscription" "alerts_email_secondary" {
  provider  = aws.secondary
  topic_arn = aws_sns_topic.alerts_secondary.arn
  protocol  = "email"
  endpoint  = var.alert_email
}


##########################################
# CloudFront 5xx Error Rate Alarm (UNCHANGED)
##########################################

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  alarm_name          = "CloudFront-5xx-ErrorRate"
  alarm_description   = "Triggers when CloudFront 5xx error rate exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "missing"

  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
    Region         = "Global"
  }

  depends_on = [aws_cloudfront_distribution.site]
}


##########################################
# PRIMARY ALB – Healthy Host Count Alarm
##########################################

resource "aws_cloudwatch_metric_alarm" "primary_alb_healthy" {
  alarm_name          = "Primary-ALB-HealthyHostCount"
  alarm_description   = "Triggers when healthy primary ALB targets drop below expected count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"

  # EXPECTED = 2 EC2 instances
  threshold = 2

  # If an instance is stopped or removed, ALB reports missing → treat as breach
  treat_missing_data = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.primary_lb.arn_suffix
    TargetGroup  = aws_lb_target_group.primary_tg.arn_suffix
  }

  depends_on = [aws_lb.primary_lb, aws_lb_target_group.primary_tg]
}


##########################################
# SECONDARY ALB – Healthy Host Count Alarm
##########################################

resource "aws_cloudwatch_metric_alarm" "secondary_alb_healthy" {
  provider            = aws.secondary
  alarm_name          = "Secondary-ALB-HealthyHostCount"
  alarm_description   = "Triggers when healthy secondary ALB targets drop below expected count"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"

  # Expected = 1 instance (secondary region)
  threshold = 1

  treat_missing_data = "breaching"

  alarm_actions = [aws_sns_topic.alerts_secondary.arn]
  ok_actions    = [aws_sns_topic.alerts_secondary.arn]

  dimensions = {
    LoadBalancer = aws_lb.secondary_lb.arn_suffix
    TargetGroup  = aws_lb_target_group.secondary_tg.arn_suffix
  }

  depends_on = [aws_lb.secondary_lb, aws_lb_target_group.secondary_tg]
}

##########################################
# CloudWatch Dashboard with Regional Separation 
##########################################

resource "aws_cloudwatch_dashboard" "main_dashboard" {
  dashboard_name = "Global-Infrastructure-Dashboard"

  dashboard_body = jsonencode({
    widgets = [

      # --- PRIMARY REGION HEADER ---
      {
        type = "text"
        x    = 0
        y    = 0
        width  = 12
        height = 1
        properties = {
          markdown = "# Primary Region (${var.primary_region})"
        }
      },

      # PRIMARY ALB HealthyHostCount
      {
        type = "metric"
        x    = 0
        y    = 1
        width  = 6
        height = 6
        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "HealthyHostCount",
              "LoadBalancer", aws_lb.primary_lb.arn_suffix,
              "TargetGroup", aws_lb_target_group.primary_tg.arn_suffix
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.primary_region
          title   = "Primary ALB Healthy Hosts"
          period  = 60
        }
      },

      # PRIMARY EC2 CPU Utilization
      {
        type = "metric"
        x    = 6
        y    = 1
        width  = 6
        height = 6
        properties = {
          metrics = [
            for i in aws_instance.primary : [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId", i.id
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.primary_region
          title   = "Primary EC2 CPU Utilization"
          period  = 60
        }
      },

      # PRIMARY EC2 Status Check
      {
        type = "metric"
        x    = 0
        y    = 7
        width  = 6
        height = 6
        properties = {
          metrics = [
            for i in aws_instance.primary : [
              "AWS/EC2",
              "StatusCheckFailed",
              "InstanceId", i.id
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.primary_region
          title   = "Primary EC2 Status Check"
          period  = 60
        }
      },

      # --- SECONDARY REGION HEADER ---
      {
        type = "text"
        x    = 0
        y    = 13
        width  = 12
        height = 1
        properties = {
          markdown = "# Secondary Region (${var.secondary_region})"
        }
      },

      # SECONDARY ALB HealthyHostCount
      {
        type = "metric"
        x    = 0
        y    = 14
        width  = 6
        height = 6
        properties = {
          metrics = [
            [
              "AWS/ApplicationELB",
              "HealthyHostCount",
              "LoadBalancer", aws_lb.secondary_lb.arn_suffix,
              "TargetGroup", aws_lb_target_group.secondary_tg.arn_suffix
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.secondary_region
          title   = "Secondary ALB Healthy Hosts"
          period  = 60
        }
      },

      # SECONDARY EC2 CPU Utilization
      {
        type = "metric"
        x    = 6
        y    = 14
        width  = 6
        height = 6
        properties = {
          metrics = [
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId", aws_instance.secondary[0].id
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.secondary_region
          title   = "Secondary EC2 CPU Utilization"
          period  = 60
        }
      },

      # SECONDARY EC2 Status Check
      {
        type = "metric"
        x    = 0
        y    = 20
        width  = 6
        height = 6
        properties = {
          metrics = [
            [
              "AWS/EC2",
              "StatusCheckFailed",
              "InstanceId", aws_instance.secondary[0].id
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.secondary_region
          title   = "Secondary EC2 Status Check"
          period  = 60
        }
      },

      # --- CloudFront 5xx Errors (Global) ---
      {
        type = "metric"
        x    = 6
        y    = 20
        width  = 6
        height = 6
        properties = {
          metrics = [
            [
              "AWS/CloudFront",
              "5xxErrorRate",
              "DistributionId", aws_cloudfront_distribution.site.id,
              "Region", "Global"
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "CloudFront 5xx Errors"
          period  = 60
        }
      }

    ]
  })
}





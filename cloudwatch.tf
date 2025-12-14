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
  threshold           = 2
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.primary_lb.arn_suffix
    TargetGroup  = aws_lb_target_group.primary_tg.arn_suffix
  }

  depends_on = [aws_lb.primary_lb, aws_lb_target_group.primary_tg]
}

##########################################
# PRIMARY EC2 StatusCheck Alarm 
##########################################

resource "aws_cloudwatch_metric_alarm" "primary_ec2_status" {
  count = length(aws_instance.primary)

  alarm_name          = "Primary-EC2-StatusCheckFailed-${aws_instance.primary[count.index].id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Triggers if the primary instance fails system or instance checks."

  dimensions = {
    InstanceId = aws_instance.primary[count.index].id
  }

  treat_missing_data = "notBreaching"
  actions_enabled    = true

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
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
  threshold           = 1
  treat_missing_data  = "breaching"

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
      }

    ]
  })
}






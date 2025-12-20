# Failover Test Checklist — AZ-Level and Region-Level

1. Preparation Checklist
• Confirm CloudFormation/Terraform deployments are completed successfully.
• Verify CloudWatch alarms are active and in OK state.
• Verify SNS notifications are subscribed and confirmed.
• Record ALB DNS names, CloudFront distribution ID, and EC2 instance IDs.
• Ensure health checks are configured correctly for ALBs and CloudFront.
• Open CloudWatch dashboards in a separate window to observe metrics.

2. AZ-Level Failover Test (Within Primary Region)
• Identify which Availability Zones the primary EC2 instances are running in.
• Stop the EC2 instance in **AZ-A** (one of two).
• Verify ALB HealthyHostCount decreases from 2 → 1.
• Confirm CloudWatch alarm for primary ALB HealthyHostCount does NOT go into alarm.
• Check that traffic through CloudFront continues serving from the remaining healthy EC2 instance.
• Reload CloudFront website and confirm uninterrupted service.
• Start the instance again and verify HealthyHostCount returns to 2.
• Confirm CloudWatch OK email notification (recovery) is received.

3. Full Primary Region Failover Test
• Stop BOTH EC2 instances in the primary region.
• Verify ALB HealthyHostCount drops to 0.
• Verify ALB health check marks the primary ALB as unhealthy.
• CloudFront Origin Group should fail over to secondary region automatically.
• Reload CloudFront website and confirm traffic is served by the secondary origin.
• Confirm CloudWatch Alarm: Primary-ALB-HealthyHostCount enters ALARM state.
• Verify SNS notification email is received.
• Check CloudWatch dashboard — Primary ALB shows 0 healthy hosts.
• Start EC2 instances in the primary region.
• Verify ALB HealthyHostCount rises from 0 → 2.
• CloudFront should return to using primary origin after health recovery.
• Verify OK-recovery SNS notification is received.

4. Validation & Cleanup
• Ensure CloudWatch alarms return to OK state.
• Verify CloudFront is routing to primary origin again.
• Confirm secondary region traffic drops back to zero.
• Document timestamps of failover and recovery.
• Confirm all instances are running normally after the test.



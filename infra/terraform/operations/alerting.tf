###############################################################################
# SNS Topics - 알람 라우팅
###############################################################################

resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
  tags = module.tags.tags
}

resource "aws_sns_topic" "critical_alerts" {
  name = "${local.name}-critical-alerts"
  tags = module.tags.tags
}

# Email 구독
resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "critical_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Slack 연동 (Lambda)
resource "aws_sns_topic_subscription" "slack" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier[0].arn
}

###############################################################################
# Slack Notifier Lambda
###############################################################################

data "archive_file" "slack_notifier" {
  count       = var.slack_webhook_url != "" ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/lambda/slack_notifier.zip"

  source {
    content  = <<-PYTHON
import json
import urllib.request
import os

def handler(event, context):
    webhook_url = os.environ['SLACK_WEBHOOK_URL']

    for record in event['Records']:
        message = json.loads(record['Sns']['Message'])
        subject = record['Sns']['Subject']

        slack_message = {
            "blocks": [
                {
                    "type": "header",
                    "text": {"type": "plain_text", "text": f"🚨 {subject}"}
                },
                {
                    "type": "section",
                    "text": {"type": "mrkdwn", "text": f"```{json.dumps(message, indent=2)}```"}
                }
            ]
        }

        req = urllib.request.Request(
            webhook_url,
            data=json.dumps(slack_message).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req)

    return {'statusCode': 200}
    PYTHON
    filename = "index.py"
  }
}

resource "aws_lambda_function" "slack_notifier" {
  count         = var.slack_webhook_url != "" ? 1 : 0
  function_name = "${local.name}-slack-notifier"
  role          = aws_iam_role.lambda_slack[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 10

  filename         = data.archive_file.slack_notifier[0].output_path
  source_code_hash = data.archive_file.slack_notifier[0].output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = module.tags.tags
}

resource "aws_lambda_permission" "sns_invoke" {
  count         = var.slack_webhook_url != "" ? 1 : 0
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.critical_alerts.arn
}

resource "aws_iam_role" "lambda_slack" {
  count = var.slack_webhook_url != "" ? 1 : 0
  name  = "${local.name}-lambda-slack-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = module.tags.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = var.slack_webhook_url != "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_slack[0].name
}

###############################################################################
# CloudWatch Cross-Account Dashboard
###############################################################################

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "EKS Cluster CPU (Service Account)"
          region  = var.region
          metrics = [
            ["AWS/EKS", "cluster_failed_node_count", "ClusterName", "cdp-service-eks"]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "RDS Connections (Service Account)"
          region  = var.region
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "cdp-service-postgres"]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "RDS CPU Utilization"
          region  = var.region
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "cdp-service-postgres"]
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count (Landing Zone)"
          region  = var.region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "cdp-landing-alb"]
          ]
          period = 300
          stat   = "Sum"
        }
      }
    ]
  })
}

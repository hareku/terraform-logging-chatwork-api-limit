# IAM Role for Lambda
resource "aws_iam_role" "this" {
  name = "RoleForLambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "terraform_lambda_iam_policy_basic_execution" {
  role       = "${aws_iam_role.this.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
data "archive_file" "this" {
  type        = "zip"
  source_dir  = "lambda_function"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "this" {
  filename         = "${data.archive_file.this.output_path}"
  function_name    = "logging_chatwork_api_rate_limit"
  role             = "${aws_iam_role.this.arn}"
  handler          = "index.handler"
  source_code_hash = "${data.archive_file.this.output_base64sha256}"
  runtime          = "nodejs8.10"
  timeout          = 300

  environment {
    variables = {
      ChatWorkToken = "${var.chatwork_token}"
    }
  }
}

# CloudWatch Event
resource "aws_cloudwatch_event_rule" "this" {
  name                = "schedule-check-chatwork-api-limit"
  description         = "Schedule the remaining number of the ChatWork API"
  schedule_expression = "rate(10 minutes)"
}

resource "aws_cloudwatch_event_target" "this" {
  rule = "${aws_cloudwatch_event_rule.this.name}"
  arn  = "${aws_lambda_function.this.arn}"
}

resource "aws_lambda_permission" "this" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.this.function_name}"
  principal     = "events.amazonaws.com"
  statement_id  = "AllowExecutionFromCloudWatch"
  source_arn    = "${aws_cloudwatch_event_rule.this.arn}"
}

# CloudWatch Log
resource "aws_cloudwatch_log_group" "this" {
  name = "ChatWorkAPI"
}

resource "aws_cloudwatch_log_stream" "this" {
  name           = "APIRemaining"
  log_group_name = "${aws_cloudwatch_log_group.this.name}"
}

resource "aws_cloudwatch_log_metric_filter" "this" {
  name           = "ChatWorkAPIRemaining"
  pattern        = "[remaining]"
  log_group_name = "${aws_cloudwatch_log_group.this.name}"

  metric_transformation {
    name      = "APIRemaining"
    namespace = "ChatWork"
    value     = "$remaining"
  }
}

resource "aws_cloudwatch_metric_alarm" "living_related_50x_critical" {
  alarm_name          = "chatwork-api-remaining"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "APIRemaining"
  namespace           = "ChatWork"
  period              = "900"
  statistic           = "Minimum"
  threshold           = "15"
  alarm_description   = "This metric monitor API remaining"
}

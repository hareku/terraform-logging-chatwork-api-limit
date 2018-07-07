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

resource "aws_iam_role_policy" "this" {
  name = "AllowDynamoDBUpdateChatWorkApiRateLimitTable"
  role = "${aws_iam_role.this.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Action": "dynamodb:*",
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:*:*:table/ChatWorkApiRateLimit"
    }
  ]
}
EOF
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
  description         = "Schedule the limit number of the ChatWork API"
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

# DynamoDB
resource "aws_dynamodb_table" "this" {
  name           = "ChatWorkApiRateLimit"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "ResetAt"

  attribute {
    name = "ResetAt"
    type = "S"
  }
}

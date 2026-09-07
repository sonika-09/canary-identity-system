# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "canary_detector_lambda_role"

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
}

# Basic Logging policy for Lambda
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Timeline query permissions (CloudWatch Logs Insights)
resource "aws_iam_role_policy" "lambda_timeline_permissions" {
  name = "canary-lambda-timeline-query"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:StopQuery",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# Zip the src directory automatically
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/lambda_payload.zip"
}

# Lambda Function
resource "aws_lambda_function" "canary_detector" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "canary-identity-analyzer"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      CANARY_IDENTITY_PREFIXES = ""
      CANARY_IDENTITIES        = "${aws_iam_user.canary_user.name},${aws_iam_role.canary_role.name}"
      TIMELINE_BACKEND         = "cloudwatch"
      CLOUDTRAIL_LOG_GROUP     = aws_cloudwatch_log_group.cloudtrail.name
      TIMELINE_LOOKBACK_HOURS  = "24"
      TIMELINE_QUERY_TIMEOUT   = "45"
      DEPLOY_ENVIRONMENT       = "dev"
      SLACK_WEBHOOK_URL        = var.slack_webhook_url
      ALERT_DRY_RUN            = "false"
    }
  }
}

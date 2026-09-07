output "canary_access_key_id" {
  value       = aws_iam_access_key.canary_key.id
  description = "The Access Key ID for planting"
}

output "canary_secret_access_key" {
  value       = aws_iam_access_key.canary_key.secret
  sensitive   = true
  description = "The Secret Access Key for planting"
}

output "canary_user_arn" {
  value       = aws_iam_user.canary_user.arn
  description = "The ARN of the decoy IAM user"
}

output "canary_role_arn" {
  value       = aws_iam_role.canary_role.arn
  description = "The ARN of the decoy IAM role"
}

output "canary_role_access_key_id" {
  value       = aws_iam_access_key.canary_role_key.id
  description = "The Access Key ID for the canary role"
}

output "canary_role_secret_access_key" {
  value       = aws_iam_access_key.canary_role_key.secret
  sensitive   = true
  description = "The Secret Access Key for the canary role"
}

output "cloudtrail_log_group" {
  value       = aws_cloudwatch_log_group.cloudtrail.name
  description = "The CloudWatch Log Group for CloudTrail"
}

output "lambda_function_name" {
  value       = aws_lambda_function.canary_detector.function_name
  description = "The Lambda function name"
}

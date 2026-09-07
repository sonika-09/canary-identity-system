# Decoy IAM User
resource "aws_iam_user" "canary_user" {
  name = var.canary_username
  tags = {
    Type        = "CanaryIdentity"
    Environment = "Deception"
  }
}

# Access Key Pair (This will be planted on target systems)
resource "aws_iam_access_key" "canary_key" {
  user = aws_iam_user.canary_user.name
}

# Safety Policy: Explicit Deny All to prevent real unauthorized access
resource "aws_iam_user_policy" "canary_deny_all" {
  name = "CanaryExplicitDenyAll"
  user = aws_iam_user.canary_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
    }]
  })
}

# Decoy IAM Role (for assumed-role canary sessions)
resource "aws_iam_role" "canary_role" {
  name = "${var.canary_username}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
  tags = {
    Type        = "CanaryIdentity"
    Environment = "Deception"
  }
}

# Role explicit deny boundary
resource "aws_iam_role_policy" "canary_role_deny_all" {
  name = "CanaryExplicitDenyAll"
  role = aws_iam_role.canary_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
    }]
  })
}

# Canary role access key (for planting)
resource "aws_iam_access_key" "canary_role_key" {
  user = aws_iam_role.canary_role.name
}

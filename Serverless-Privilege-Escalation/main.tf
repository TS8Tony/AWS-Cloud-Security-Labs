provider "aws" {
  region = "us-east-1"
}

# 1. High-Privilege Target Role (The Execution Role)
resource "aws_iam_role" "lambda_admin_role" {
  name = "LambdaAdminExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# [FIXED ELEMENT]: This block attaches full admin privileges to your target Lambda role
resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.lambda_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 2. Low-Privilege Attacker Identity Policy
resource "aws_iam_policy" "attacker_policy" {
  name = "DeveloperLimitedAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowLambdaCreation"
        Effect   = "Allow"
        Action   = [
          "lambda:CreateFunction",
          "lambda:InvokeFunction",
          "lambda:DeleteFunction"
        ]
        Resource = "*"
      },
      {
        Sid      = "OverlyBroadPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*" 
      }
    ]
  })
}

# 3. Provision the Low-Privilege User
resource "aws_iam_user" "attacker" {
  name = "compromised-developer"
}

resource "aws_iam_user_policy_attachment" "attacker_attach" {
  user       = aws_iam_user.attacker.name
  policy_arn = aws_iam_policy.attacker_policy.arn
}
